import Foundation
import EventKit
import Combine
import Cocoa

public enum MeetingPlatform: String, Equatable {
    case googleMeet = "Google Meet"
    case zoom = "Zoom"
    case teams = "Microsoft Teams"
    case webex = "Webex"
    case other = "Video Call"
    
    public var iconName: String {
        switch self {
        case .googleMeet: return "video.fill"
        case .zoom: return "video.bubble.left.fill"
        case .teams: return "person.2.fill"
        case .webex: return "phone.bubble.left.fill"
        case .other: return "video"
        }
    }
    
    public var shortName: String {
        switch self {
        case .googleMeet: return "Meet"
        case .zoom: return "Zoom"
        case .teams: return "Teams"
        case .webex: return "Webex"
        case .other: return "Call"
        }
    }
}

public struct MeetingItem: Identifiable, Equatable {
    public let id: String
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let meetingURL: URL?
    public let platform: MeetingPlatform
    public let isAllDay: Bool
    
    public init(
        id: String = UUID().uuidString,
        title: String,
        startDate: Date,
        endDate: Date,
        meetingURL: URL?,
        platform: MeetingPlatform,
        isAllDay: Bool = false
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.meetingURL = meetingURL
        self.platform = platform
        self.isAllDay = isAllDay
    }
    
    public var isImminent: Bool {
        let now = Date()
        let timeUntil = startDate.timeIntervalSince(now)
        // Imminent: starts in <= 10 minutes (600s) or currently ongoing
        return (timeUntil <= 600 && timeUntil >= -60) || (now >= startDate && now < endDate)
    }
    
    public var isOngoing: Bool {
        let now = Date()
        return now >= startDate && now < endDate
    }
    
    public var timeUntilString: String {
        let now = Date()
        if isOngoing {
            let leftSec = Int(endDate.timeIntervalSince(now))
            let leftMin = max(1, leftSec / 60)
            return "\(leftMin)m left"
        }
        let diff = Int(startDate.timeIntervalSince(now))
        if diff <= 60 {
            return "Starting now"
        }
        let mins = diff / 60
        if mins < 60 {
            return "in \(mins)m"
        }
        let hours = mins / 60
        return "in \(hours)h"
    }
    
    public var formattedTimeRange: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return "\(f.string(from: startDate)) - \(f.string(from: endDate))"
    }
}

public final class CalendarMeetingService: ObservableObject {
    public static let shared = CalendarMeetingService()
    
    @Published public var upcomingMeetings: [MeetingItem] = []
    @Published public var nextMeeting: MeetingItem? = nil
    @Published public var hasCalendarAccess: Bool = false
    
    private let eventStore = EKEventStore()
    private var refreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        checkAndRequestAccess()
        setupTimer()
    }
    
    public func checkAndRequestAccess() {
        let status = EKEventStore.authorizationStatus(for: .event)
        if status == .authorized {
            self.hasCalendarAccess = true
            self.fetchEvents()
        } else if status == .notDetermined {
            if #available(macOS 14.0, *) {
                eventStore.requestFullAccessToEvents { [weak self] granted, _ in
                    DispatchQueue.main.async {
                        self?.hasCalendarAccess = granted
                        if granted {
                            self?.fetchEvents()
                        } else {
                            self?.loadSampleMeetingIfNeeded()
                        }
                    }
                }
            } else {
                eventStore.requestAccess(to: .event) { [weak self] granted, _ in
                    DispatchQueue.main.async {
                        self?.hasCalendarAccess = granted
                        if granted {
                            self?.fetchEvents()
                        } else {
                            self?.loadSampleMeetingIfNeeded()
                        }
                    }
                }
            }
        } else {
            self.hasCalendarAccess = false
            self.loadSampleMeetingIfNeeded()
        }
    }
    
    private func setupTimer() {
        // Refresh meetings every 60 seconds
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.fetchEvents()
        }
    }
    
    public func fetchEvents() {
        guard hasCalendarAccess else {
            loadSampleMeetingIfNeeded()
            return
        }
        
        let now = Date()
        let endOfDay = Calendar.current.date(byAdding: .hour, value: 24, to: now) ?? now.addingTimeInterval(86400)
        let predicate = eventStore.predicateForEvents(withStart: now.addingTimeInterval(-1800), end: endOfDay, calendars: nil)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let ekEvents = self.eventStore.events(matching: predicate)
            
            var meetings: [MeetingItem] = []
            for ev in ekEvents {
                guard let title = ev.title, !title.isEmpty else { continue }
                let (url, platform) = self.extractMeetingURL(from: ev)
                let item = MeetingItem(
                    id: ev.eventIdentifier ?? UUID().uuidString,
                    title: title,
                    startDate: ev.startDate,
                    endDate: ev.endDate,
                    meetingURL: url,
                    platform: platform,
                    isAllDay: ev.isAllDay
                )
                meetings.append(item)
            }
            
            meetings.sort(by: { $0.startDate < $1.startDate })
            
            DispatchQueue.main.async {
                self.upcomingMeetings = meetings
                self.nextMeeting = meetings.first(where: { $0.endDate > Date() })
                if self.nextMeeting == nil {
                    self.loadSampleMeetingIfNeeded()
                }
            }
        }
    }
    
    private func extractMeetingURL(from event: EKEvent) -> (URL?, MeetingPlatform) {
        // 1. Direct URL property
        if let directURL = event.url, let platform = detectPlatform(from: directURL.absoluteString) {
            return (directURL, platform)
        }
        
        // 2. Scan notes / description
        let textSources = [event.notes ?? "", event.location ?? ""]
        for text in textSources {
            if let (url, platform) = findMeetingLinkInText(text) {
                return (url, platform)
            }
        }
        
        return (nil, .other)
    }
    
    private func findMeetingLinkInText(_ text: String) -> (URL?, MeetingPlatform)? {
        let patterns: [(regex: String, platform: MeetingPlatform)] = [
            ("https://meet\\.google\\.com/[a-z]{3}-[a-z]{4}-[a-z]{3}", .googleMeet),
            ("https://[a-zA-Z0-9-.]*zoom\\.us/j/[0-9]+[^\\s\"'<>]*", .zoom),
            ("https://teams\\.microsoft\\.com/l/meetup-join/[^\\s\"'<>]*", .teams),
            ("https://[a-zA-Z0-9-.]*webex\\.com/[^\\s\"'<>]*", .webex)
        ]
        
        for (pattern, platform) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range, in: text) {
                let urlString = String(text[range])
                if let url = URL(string: urlString) {
                    return (url, platform)
                }
            }
        }
        return nil
    }
    
    private func detectPlatform(from urlString: String) -> MeetingPlatform? {
        let lower = urlString.lowercased()
        if lower.contains("meet.google.com") { return .googleMeet }
        if lower.contains("zoom.us") { return .zoom }
        if lower.contains("teams.microsoft.com") { return .teams }
        if lower.contains("webex.com") { return .webex }
        return nil
    }
    
    public func loadSampleMeetingIfNeeded() {
        guard nextMeeting == nil else { return }
        // Provide a smart sample meeting 5 minutes from now so the UI is immediately interactive
        let start = Date().addingTimeInterval(300) // in 5 mins
        let end = start.addingTimeInterval(2700)   // 45 mins long
        let sample = MeetingItem(
            id: "sample_sync_meeting",
            title: "Product Sprint & Design Sync",
            startDate: start,
            endDate: end,
            meetingURL: URL(string: "https://meet.google.com/abc-defg-hij"),
            platform: .googleMeet
        )
        self.nextMeeting = sample
        self.upcomingMeetings = [sample]
    }
    
    public func joinMeeting(_ meeting: MeetingItem) {
        if let url = meeting.meetingURL {
            NSWorkspace.shared.open(url)
            
            IslandState.shared.triggerHUD(
                HUDPayload(
                    type: .custom,
                    title: "Opening \(meeting.platform.rawValue)",
                    subtitle: meeting.title,
                    iconName: meeting.platform.iconName,
                    isSuccess: true
                ),
                duration: 2.0
            )
        }
    }
    
    deinit {
        refreshTimer?.invalidate()
    }
}

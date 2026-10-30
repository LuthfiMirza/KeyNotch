import SwiftUI
import Combine

public enum IslandTab: String, CaseIterable, Identifiable {
    case controls = "Controls"
    case music = "Music"
    case notes = "Reminders"
    case devices = "Devices"
    case shelf = "Shelf"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .controls: return "slider.horizontal.3"
        case .music: return "music.note"
        case .notes: return "checklist"
        case .devices: return "bolt.horizontal.fill"
        case .shelf: return "tray.and.arrow.down.fill"
        }
    }
}

public enum HUDType {
    case volume
    case brightness
    case capsLock
    case battery
    case bluetooth
    case custom
    case whatsapp
    case incomingCall
}

public struct ActiveCallState: Equatable {
    public let callerName: String
    public let callSource: String // e.g. "from iPhone", "WhatsApp Audio", "FaceTime"
    public let startDate: Date
    public let isVideo: Bool
    public var isMuted: Bool
    public let avatarImagePath: String?
    
    public init(
        callerName: String,
        callSource: String = "WhatsApp Audio",
        startDate: Date = Date(),
        isVideo: Bool = false,
        isMuted: Bool = false,
        avatarImagePath: String? = nil
    ) {
        self.callerName = callerName
        self.callSource = callSource
        self.startDate = startDate
        self.isVideo = isVideo
        self.isMuted = isMuted
        self.avatarImagePath = avatarImagePath
    }
}

public struct HUDPayload: Identifiable, Equatable {
    public let id: UUID = UUID()
    public let type: HUDType
    public let title: String
    public let subtitle: String?
    public let iconName: String
    public let value: Float? // 0.0 ... 1.0 (for progress ring or volume slider)
    public let rightDetail: String?
    public let customBadgeIcon: String?
    public let isSuccess: Bool
    public let avatarImagePath: String?
    public let timestampText: String?
    
    public init(
        type: HUDType,
        title: String,
        subtitle: String? = nil,
        iconName: String,
        value: Float? = nil,
        rightDetail: String? = nil,
        customBadgeIcon: String? = nil,
        isSuccess: Bool = true,
        avatarImagePath: String? = nil,
        timestampText: String? = nil
    ) {
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.iconName = iconName
        self.value = value
        self.rightDetail = rightDetail
        self.customBadgeIcon = customBadgeIcon
        self.isSuccess = isSuccess
        self.avatarImagePath = avatarImagePath
        self.timestampText = timestampText
    }
    
    public static func == (lhs: HUDPayload, rhs: HUDPayload) -> Bool {
        lhs.id == rhs.id
    }
}

public final class IslandState: ObservableObject {
    public static let shared = IslandState()
    
    // Core Display States
    @Published public var isExpanded: Bool = false
    @Published public var isHoverPeekMode: Bool {
        didSet {
            UserDefaults.standard.set(isHoverPeekMode, forKey: "isHoverPeekMode")
        }
    }
    @Published public var isPeeking: Bool = false
    @Published public var isHidden: Bool = false
    @Published public var selectedTab: IslandTab = .controls
    @Published public var activeHUD: HUDPayload? = nil
    @Published public var activeCall: ActiveCallState? = nil
    @Published public var isReplyingWhatsApp: Bool = false
    
    // Notch Dimensions & Hardware Awareness
    @Published public var hasPhysicalNotch: Bool = false
    @Published public var notchWidth: CGFloat = 210
    @Published public var notchHeight: CGFloat = 36
    
    // Full Screen Auto-Hide
    @Published public var autoHideOnFullScreen: Bool {
        didSet {
            UserDefaults.standard.set(autoHideOnFullScreen, forKey: "autoHideOnFullScreen")
        }
    }
    @Published public var isFullScreenAppActive: Bool = false
    
    public var shouldHideForFullScreen: Bool {
        autoHideOnFullScreen && isFullScreenAppActive && !isPeeking && !isExpanded && activeHUD == nil
    }
    
    private var hudDismissTimer: AnyCancellable?
    
    private init() {
        self.isHoverPeekMode = UserDefaults.standard.bool(forKey: "isHoverPeekMode")
        if UserDefaults.standard.object(forKey: "autoHideOnFullScreen") == nil {
            self.autoHideOnFullScreen = true
        } else {
            self.autoHideOnFullScreen = UserDefaults.standard.bool(forKey: "autoHideOnFullScreen")
        }
        updateScreenMetrics()
    }
    
    public func toggleAutoHideFullScreen() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
            autoHideOnFullScreen.toggle()
        }
    }
    
    public func updateScreenMetrics() {
        guard let screen = NSScreen.main else { return }
        
        var hasNotch = false
        var height: CGFloat = 36
        var width: CGFloat = 210
        
        if #available(macOS 12.0, *) {
            let topInset = screen.safeAreaInsets.top
            if topInset > 0 {
                hasNotch = true
                height = max(32, topInset)
            }
            if let leftAux = screen.auxiliaryTopLeftArea, let rightAux = screen.auxiliaryTopRightArea {
                hasNotch = true
                let gap = rightAux.minX - leftAux.maxX
                if gap > 100 {
                    width = gap
                }
            }
        }
        
        self.hasPhysicalNotch = hasNotch
        self.notchHeight = hasNotch ? height : 36
        self.notchWidth = hasNotch ? width : 210
    }
    
    // MARK: - Actions
    
    public func toggleExpand() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
            isExpanded.toggle()
            if isExpanded {
                isPeeking = false
                activeHUD = nil
            }
        }
    }
    
    public func expand(tab: IslandTab? = nil) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
            if let tab = tab {
                selectedTab = tab
            }
            isExpanded = true
            isPeeking = false
            activeHUD = nil
        }
    }
    
    public func collapse() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
            isExpanded = false
            isPeeking = false
        }
    }
    
    public func setHoverPeekMode(_ enabled: Bool) {
        isHoverPeekMode = enabled
        if !enabled {
            isPeeking = false
        }
    }
    
    public func toggleHoverPeekMode() {
        setHoverPeekMode(!isHoverPeekMode)
    }
    
    public func toggleHidden() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
            isHidden.toggle()
            if isHidden {
                isExpanded = false
                isPeeking = false
            }
        }
    }
    
    public enum PageSlideDirection {
        case forward
        case backward
    }
    
    @Published public var slideDirection: PageSlideDirection = .forward
    
    public func selectTab(at index: Int) {
        let all = IslandTab.allCases
        guard index >= 0 && index < all.count else { return }
        let current = all.firstIndex(of: selectedTab) ?? 0
        slideDirection = (index >= current) ? .forward : .backward
        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
            selectedTab = all[index]
        }
    }
    
    public func selectNextTab() {
        let all = IslandTab.allCases
        guard let current = all.firstIndex(of: selectedTab), current < all.count - 1 else { return }
        slideDirection = .forward
        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
            selectedTab = all[current + 1]
        }
    }
    
    public func selectPreviousTab() {
        let all = IslandTab.allCases
        guard let current = all.firstIndex(of: selectedTab), current > 0 else { return }
        slideDirection = .backward
        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
            selectedTab = all[current - 1]
        }
    }
    
    public func triggerHUD(_ payload: HUDPayload, duration: TimeInterval = 1.4) {
        // Only show HUD if not already fully expanded
        guard !isExpanded else { return }
        
        // Protect Incoming Call: incoming calls are high-priority and shouldn't be interrupted by chat messages or volume
        if let active = activeHUD, active.type == .incomingCall && payload.type != .incomingCall {
            return
        }
        
        hudDismissTimer?.cancel()
        self.isReplyingWhatsApp = false
        withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
            activeHUD = payload
        }
        
        hudDismissTimer = Just(())
            .delay(for: .seconds(duration), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                    self?.activeHUD = nil
                    self?.isReplyingWhatsApp = false
                }
            }
    }
    
    public func enterWhatsAppReplyMode() {
        hudDismissTimer?.cancel()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
            self.isReplyingWhatsApp = true
        }
    }
    
    public func dismissHUD() {
        hudDismissTimer?.cancel()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
            self.activeHUD = nil
            self.isReplyingWhatsApp = false
        }
    }
    
    // MARK: - Active Ongoing Call (Compact Notch Live Activity)
    
    public func startActiveCall(caller: String, source: String = "from iPhone", isVideo: Bool = false, avatarImagePath: String? = nil) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
            self.activeHUD = nil
            self.activeCall = ActiveCallState(
                callerName: caller,
                callSource: source,
                startDate: Date(),
                isVideo: isVideo,
                isMuted: false,
                avatarImagePath: avatarImagePath
            )
        }
    }
    
    public func endActiveCall() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
            self.activeCall = nil
        }
    }
    
    public func toggleCallMute() {
        guard var call = activeCall else { return }
        call.isMuted.toggle()
        withAnimation(.easeInOut(duration: 0.2)) {
            self.activeCall = call
        }
    }
}

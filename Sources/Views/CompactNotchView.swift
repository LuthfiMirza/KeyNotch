import SwiftUI
import Combine

public struct CompactNotchView: View {
    @ObservedObject var state = IslandState.shared
    @ObservedObject var media = MediaRemoteService.shared
    @ObservedObject var battery = BatteryService.shared
    @ObservedObject var pomodoro = PomodoroService.shared
    @ObservedObject var mic = MicrophoneService.shared
    @ObservedObject var network = NetworkMonitorService.shared
    @ObservedObject var market = MarketTickerService.shared
    @ObservedObject var calendar = CalendarMeetingService.shared
    @ObservedObject var transfer = DownloadTransferService.shared
    @ObservedObject var privacy = PrivacyGuardService.shared
    
    @State private var currentTime: String = ""
    @State private var clockTimer: AnyCancellable?
    
    // Cached static DateFormatter to eliminate heap allocation on ticks
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
    
    // Vibrant Activity Ring Green & Cyan Download Blue
    private let ringColor = Color(red: 0.18, green: 0.86, blue: 0.44)
    private let downloadColor = Color(red: 0.18, green: 0.65, blue: 1.0)
    
    private var pingColor: Color {
        switch network.pingQuality {
        case .excellent, .good: return .green
        case .fair: return .yellow
        case .poor: return .red
        case .unknown: return .gray
        }
    }
    
    public init() {}
    
    private var progressValue: Double {
        if pomodoro.isRunning {
            return pomodoro.progress
        } else {
            return max(0.06, min(1.0, Double(battery.batteryPercentage) / 100.0))
        }
    }
    
    public var body: some View {
        HStack(spacing: 0) {
            // MARK: - Left: Privacy Spy Guard (Camera/Mic) OR Download Ring OR Battery/Pomodoro Ring
            HStack {
                if privacy.isCameraInUse && privacy.isMicInUse {
                    // Dual Spy Guard Dot: Green Camera + Orange/Red Mic
                    Button(action: {
                        privacy.toggleMute()
                    }) {
                        HStack(spacing: 3.5) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                                .shadow(color: Color.green.opacity(0.8), radius: 2)
                            Circle()
                                .fill(privacy.isMicMuted ? Color.red : Color.orange)
                                .frame(width: 6, height: 6)
                                .shadow(color: (privacy.isMicMuted ? Color.red : Color.orange).opacity(0.8), radius: 2)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3.5)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                } else if privacy.isCameraInUse {
                    // Camera Spy Indicator: Green Dot
                    ZStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 17, height: 17)
                            .shadow(color: Color.green.opacity(0.6), radius: 3)
                        Image(systemName: "video.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.black)
                    }
                } else if privacy.isMicInUse {
                    // Microphone Spy Indicator: Orange/Red Dot
                    Button(action: {
                        privacy.toggleMute()
                    }) {
                        ZStack {
                            Circle()
                                .fill(privacy.isMicMuted ? Color.red : Color.orange)
                                .frame(width: 17, height: 17)
                                .shadow(color: (privacy.isMicMuted ? Color.red : Color.orange).opacity(0.6), radius: 3)
                            Image(systemName: privacy.isMicMuted ? "mic.slash.fill" : "mic.fill")
                                .font(.system(size: 8.5, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                } else if let dl = transfer.primaryTransfer {
                    // Live Download / AirDrop Progress Ring
                    ZStack {
                        Circle()
                            .stroke(downloadColor.opacity(0.25), lineWidth: 3.5)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(dl.progress))
                            .stroke(
                                downloadColor,
                                style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 0.4), value: dl.progress)
                        
                        Image(systemName: dl.isAirDrop ? "airdrop" : "arrow.down")
                            .font(.system(size: 7.5, weight: .bold))
                            .foregroundColor(downloadColor)
                    }
                    .frame(width: 17, height: 17)
                } else {
                    ZStack {
                        // Track
                        Circle()
                            .stroke(ringColor.opacity(0.22), lineWidth: 3.5)
                        
                        // Progress Stroke
                        Circle()
                            .trim(from: 0, to: CGFloat(progressValue))
                            .stroke(
                                ringColor,
                                style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 0.5), value: progressValue)
                    }
                    .frame(width: 17, height: 17)
                }
            }
            .frame(width: 48, alignment: .leading)
            .padding(.leading, 14)
            
            Spacer(minLength: 0)
            
            // MARK: - Center: Dead-Center Balanced Clock
            Text(currentTime.isEmpty ? Self.timeFormatter.string(from: Date()) : currentTime)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
            
            Spacer(minLength: 0)
            
            // MARK: - Right: Imminent Meeting OR Live Download OR Active Privacy App OR Waveform
            HStack {
                if let meeting = calendar.nextMeeting, meeting.isImminent {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(meeting.isOngoing ? Color.orange : Color.green)
                            .frame(width: 5, height: 5)
                        Text("\(meeting.platform.shortName) \(meeting.timeUntilString)")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                } else if let dl = transfer.primaryTransfer {
                    HStack(spacing: 3) {
                        Image(systemName: dl.isAirDrop ? "airdrop" : "arrow.down.circle.fill")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundColor(downloadColor)
                        Text("\(dl.percentageString) · \(dl.speedString)")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                } else if privacy.isCameraInUse || privacy.isMicInUse {
                    HStack(spacing: 3.5) {
                        Circle()
                            .fill(privacy.isCameraInUse ? Color.green : (privacy.isMicMuted ? Color.red : Color.orange))
                            .frame(width: 5, height: 5)
                        Text(privacy.activeAppName)
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.95))
                            .lineLimit(1)
                    }
                } else if media.isPlaying {
                    WaveformView(
                        isPlaying: true,
                        color: .white,
                        barCount: 4,
                        maxHeight: 15
                    )
                } else if market.showTickerInCompactNotch, let item = market.pinnedItem {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(item.isPositive ? Color.green : Color.red)
                            .frame(width: 5, height: 5)
                        Text(item.priceString)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(1)
                    }
                } else if network.showInCompactNotch {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(pingColor)
                            .frame(width: 5, height: 5)
                        Text(network.downloadSpeedString)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(1)
                    }
                } else {
                    WaveformView(
                        isPlaying: false,
                        color: .white,
                        barCount: 4,
                        maxHeight: 15
                    )
                }
            }
            .frame(width: (privacy.isCameraInUse || privacy.isMicInUse || transfer.primaryTransfer != nil || calendar.nextMeeting?.isImminent == true || (!media.isPlaying && (market.showTickerInCompactNotch || network.showInCompactNotch))) ? 84 : 48, alignment: .trailing)
            .padding(.trailing, 14)
        }
        .frame(height: state.notchHeight)
        .contentShape(Rectangle())
        .onTapGesture {
            state.toggleExpand()
        }
        .onAppear {
            startMinuteSynchronizedClock()
        }
        .onDisappear {
            clockTimer?.cancel()
            clockTimer = nil
        }
    }
    
    /// Synchronizes clock ticks to minute boundaries, reducing wakeups from 60x/min to 1x/min
    private func startMinuteSynchronizedClock() {
        currentTime = Self.timeFormatter.string(from: Date())
        
        let now = Date()
        let calendar = Calendar.current
        let seconds = calendar.component(.second, from: now)
        let nanoseconds = calendar.component(.nanosecond, from: now)
        let delay = Double(60 - seconds) - (Double(nanoseconds) / 1_000_000_000.0) + 0.1
        
        clockTimer?.cancel()
        clockTimer = Just(())
            .delay(for: .seconds(max(0.5, delay)), scheduler: RunLoop.main)
            .sink { [self] _ in
                self.currentTime = Self.timeFormatter.string(from: Date())
                // Repeat exactly once per minute with power-saving tolerance
                self.clockTimer = Timer.publish(every: 60.0, tolerance: 0.5, on: .main, in: .common)
                    .autoconnect()
                    .sink { _ in
                        self.currentTime = Self.timeFormatter.string(from: Date())
                    }
            }
    }
}

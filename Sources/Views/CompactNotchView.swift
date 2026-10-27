import SwiftUI
import Combine

public struct CompactNotchView: View {
    @ObservedObject var state = IslandState.shared
    @ObservedObject var media = MediaRemoteService.shared
    @ObservedObject var battery = BatteryService.shared
    @ObservedObject var pomodoro = PomodoroService.shared
    @ObservedObject var mic = MicrophoneService.shared
    @ObservedObject var network = NetworkMonitorService.shared
    
    @State private var currentTime: String = ""
    @State private var clockTimer: AnyCancellable?
    
    // Cached static DateFormatter to eliminate heap allocation on ticks
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
    
    // Vibrant Activity Ring Green
    private let ringColor = Color(red: 0.18, green: 0.86, blue: 0.44)
    
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
            // MARK: - Left: Circular Progress Ring OR Active Microphone Privacy Radar
            HStack {
                if mic.isMicInUse {
                    Button(action: {
                        mic.toggleMute()
                    }) {
                        ZStack {
                            Circle()
                                .fill(mic.isMuted ? Color.red : Color.orange)
                                .frame(width: 17, height: 17)
                            Image(systemName: mic.isMuted ? "mic.slash.fill" : "mic.fill")
                                .font(.system(size: 8.5, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
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
            
            // MARK: - Right: Reactive Audio Waveform OR Compact Network Pill
            HStack {
                if media.isPlaying {
                    WaveformView(
                        isPlaying: true,
                        color: .white,
                        barCount: 4,
                        maxHeight: 15
                    )
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
            .frame(width: (network.showInCompactNotch && !media.isPlaying) ? 68 : 48, alignment: .trailing)
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

import SwiftUI

public struct CompactNotchView: View {
    @ObservedObject var state = IslandState.shared
    @ObservedObject var media = MediaRemoteService.shared
    @ObservedObject var battery = BatteryService.shared
    @ObservedObject var pomodoro = PomodoroService.shared
    
    @State private var currentTime: String = ""
    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    // Vibrant Activity Ring Green
    private let ringColor = Color(red: 0.18, green: 0.86, blue: 0.44)
    
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
            // MARK: - Left: Circular Progress Ring (Activity / Battery / Pomodoro)
            HStack {
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
            .frame(width: 48, alignment: .leading)
            .padding(.leading, 14)
            
            Spacer(minLength: 0)
            
            // MARK: - Center: Dead-Center Balanced Clock
            Text(currentTime.isEmpty ? formattedCurrentTime() : currentTime)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
            
            Spacer(minLength: 0)
            
            // MARK: - Right: Reactive Audio Waveform
            HStack {
                WaveformView(
                    isPlaying: media.isPlaying,
                    color: .white,
                    barCount: 4,
                    maxHeight: 15
                )
            }
            .frame(width: 48, alignment: .trailing)
            .padding(.trailing, 14)
        }
        .frame(height: 32)
        .contentShape(Rectangle())
        .onTapGesture {
            state.toggleExpand()
        }
        .onAppear {
            currentTime = formattedCurrentTime()
        }
        .onReceive(timer) { _ in
            currentTime = formattedCurrentTime()
        }
    }
    
    private func formattedCurrentTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }
}

import SwiftUI

public struct CompactNotchView: View {
    @ObservedObject var state = IslandState.shared
    @ObservedObject var media = MediaRemoteService.shared
    @ObservedObject var battery = BatteryService.shared
    @ObservedObject var pomodoro = PomodoroService.shared
    
    @State private var currentTime: String = ""
    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    public init() {}
    
    public var body: some View {
        HStack(spacing: 6) {
            // Left Indicator (Status / Reactive Audio Waveform)
            HStack(spacing: 4) {
                if media.isPlaying {
                    WaveformView(isPlaying: true, color: .green, barCount: 4, maxHeight: 10)
                } else {
                    Circle()
                        .fill(Color.green.opacity(0.85))
                        .frame(width: 5, height: 5)
                    
                    Image(systemName: "music.note")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white.opacity(0.65))
                }
            }
            .frame(width: 48, alignment: .leading)
            .padding(.leading, 10)
            
            Spacer()
            
            // Center Section: Dead-Center Clock & Pomodoro Badge
            HStack(spacing: 6) {
                HStack(spacing: 3) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text(currentTime.isEmpty ? formattedCurrentTime() : currentTime)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .monospacedDigit()
                }
                
                // Small Pomodoro Countdown when active
                if pomodoro.isRunning {
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 7))
                            .foregroundColor(.orange)
                        Text(pomodoro.formattedTime)
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(.orange)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.orange.opacity(0.2))
                    .clipShape(Capsule())
                }
            }
            
            Spacer()
            
            // Right Indicator (Battery / Charging Glyph)
            HStack(spacing: 3) {
                if battery.isCharging || battery.isConnectedToAC {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.green)
                }
                
                Text("\(battery.batteryPercentage)%")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.75))
            }
            .frame(width: 48, alignment: .trailing)
            .padding(.trailing, 10)
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

import Cocoa
import Combine

public final class PomodoroService: ObservableObject {
    public static let shared = PomodoroService()
    
    @Published public var totalDuration: Int = 25 * 60
    @Published public var remainingSeconds: Int = 25 * 60
    @Published public var isRunning: Bool = false
    @Published public var currentPresetName: String = "Pomodoro"
    
    private var timer: Timer?
    
    private init() {}
    
    public var formattedTime: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    public var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return Double(totalDuration - remainingSeconds) / Double(totalDuration)
    }
    
    public func toggle() {
        if isRunning {
            pause()
        } else {
            start()
        }
    }
    
    public func start() {
        guard !isRunning else { return }
        isRunning = true
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.remainingSeconds > 0 {
                self.remainingSeconds -= 1
            } else {
                self.handleCompleted()
            }
        }
    }
    
    public func pause() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }
    
    public func reset() {
        pause()
        remainingSeconds = totalDuration
    }
    
    public func setPreset(name: String, minutes: Int) {
        pause()
        currentPresetName = name
        totalDuration = minutes * 60
        remainingSeconds = totalDuration
    }
    
    private func handleCompleted() {
        pause()
        remainingSeconds = 0
        NSSound.beep()
        IslandState.shared.triggerHUD(
            HUDPayload(
                type: .custom,
                title: "\(currentPresetName) Finished!",
                subtitle: "Time for a well-deserved break",
                iconName: "bell.badge.fill",
                isSuccess: true
            )
        )
    }
}

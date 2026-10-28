import Cocoa
import AVFoundation
import Combine

public final class PrivacyGuardService: ObservableObject {
    public static let shared = PrivacyGuardService()
    
    @Published public var isMicInUse: Bool = false
    @Published public var isCameraInUse: Bool = false
    @Published public var isMicMuted: Bool = false
    @Published public var activeAppName: String = "App"
    @Published public var isSimulatingSpyGuard: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    private var cameraPollTimer: Timer?
    
    // Known video & audio conferencing apps
    private let targetAppKeywords = [
        "zoom", "teams", "chrome", "meet", "facetime", "slack",
        "discord", "photo booth", "quicktime", "arc", "safari",
        "webex", "obs", "skype", "whatsapp", "telegram"
    ]
    
    private init() {
        setupMicrophoneBinding()
        startCameraMonitoring()
        detectActiveApp()
    }
    
    // MARK: - Microphone Binding
    
    private func setupMicrophoneBinding() {
        let mic = MicrophoneService.shared
        
        mic.$isMicInUse
            .receive(on: DispatchQueue.main)
            .sink { [weak self] inUse in
                guard let self = self else { return }
                if !self.isSimulatingSpyGuard {
                    self.isMicInUse = inUse
                    if inUse {
                        self.detectActiveApp()
                    }
                }
            }
            .store(in: &cancellables)
        
        mic.$isMuted
            .receive(on: DispatchQueue.main)
            .sink { [weak self] muted in
                self?.isMicMuted = muted
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Camera Monitoring (AVCaptureDevice)
    
    public func startCameraMonitoring() {
        checkCameraInUse()
        
        // Listen to device connection/disconnection
        NotificationCenter.default.publisher(for: .AVCaptureDeviceWasConnected)
            .sink { [weak self] _ in self?.checkCameraInUse() }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .AVCaptureDeviceWasDisconnected)
            .sink { [weak self] _ in self?.checkCameraInUse() }
            .store(in: &cancellables)
        
        // Poll camera status every 1.5 seconds with minimal overhead
        cameraPollTimer?.invalidate()
        cameraPollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.checkCameraInUse()
        }
    }
    
    public func checkCameraInUse() {
        guard !isSimulatingSpyGuard else { return }
        
        let session = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .externalUnknown],
            mediaType: .video,
            position: .unspecified
        )
        
        let inUse = session.devices.contains { $0.isInUseByAnotherApplication }
        if self.isCameraInUse != inUse {
            DispatchQueue.main.async {
                self.isCameraInUse = inUse
                if inUse {
                    self.detectActiveApp()
                }
            }
        }
    }
    
    // MARK: - Detect Which App Is Using Camera / Microphone
    
    public func detectActiveApp() {
        let running = NSWorkspace.shared.runningApplications
        
        // 1. Check frontmost application first
        if let front = NSWorkspace.shared.frontmostApplication,
           let name = front.localizedName {
            let lower = name.lowercased()
            if targetAppKeywords.contains(where: { lower.contains($0) }) {
                self.activeAppName = name
                return
            }
        }
        
        // 2. Scan running apps for top conferencing apps
        for app in running {
            guard let name = app.localizedName else { continue }
            let lower = name.lowercased()
            if lower.contains("zoom") { self.activeAppName = "Zoom"; return }
            if lower.contains("meet") { self.activeAppName = "Google Meet"; return }
            if lower.contains("facetime") { self.activeAppName = "FaceTime"; return }
            if lower.contains("teams") { self.activeAppName = "Microsoft Teams"; return }
            if lower.contains("slack") { self.activeAppName = "Slack"; return }
            if lower.contains("discord") { self.activeAppName = "Discord"; return }
            if lower.contains("chrome") { self.activeAppName = "Google Chrome"; return }
            if lower.contains("photo booth") { self.activeAppName = "Photo Booth"; return }
        }
        
        if isCameraInUse && !isMicInUse {
            self.activeAppName = "Camera App"
        } else if isMicInUse && !isCameraInUse {
            self.activeAppName = "Audio App"
        } else {
            self.activeAppName = "Call / Meeting"
        }
    }
    
    // MARK: - 1-Click Privacy Actions
    
    public func toggleMute() {
        MicrophoneService.shared.toggleMute()
        self.isMicMuted = MicrophoneService.shared.isMuted
        
        IslandState.shared.triggerHUD(
            HUDPayload(
                type: .custom,
                title: isMicMuted ? "Microphone Muted" : "Microphone Active",
                subtitle: isMicMuted ? "Audio input cut" : "Transmitting audio",
                iconName: isMicMuted ? "mic.slash.fill" : "mic.fill",
                isSuccess: !isMicMuted
            ),
            duration: 1.8
        )
    }
    
    // MARK: - Simulation / Demo Mode
    
    public func toggleSimulateSpyGuard() {
        isSimulatingSpyGuard.toggle()
        if isSimulatingSpyGuard {
            isMicInUse = true
            isCameraInUse = true
            activeAppName = "Zoom Meeting"
            
            IslandState.shared.triggerHUD(
                HUDPayload(
                    type: .custom,
                    title: "Privacy Spy Guard Active",
                    subtitle: "Zoom is accessing Camera & Mic",
                    iconName: "video.fill",
                    isSuccess: true
                ),
                duration: 2.2
            )
        } else {
            isMicInUse = MicrophoneService.shared.isMicInUse
            checkCameraInUse()
        }
    }
    
    deinit {
        cameraPollTimer?.invalidate()
    }
}

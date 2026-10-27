import Cocoa
import AudioToolbox
import Combine

public final class HUDInterceptorService: ObservableObject {
    public static let shared = HUDInterceptorService()
    
    @Published public var currentVolume: Float = 0.5
    @Published public var isMuted: Bool = false
    
    private var flagsGlobalMonitor: Any?
    private var flagsLocalMonitor: Any?
    private var lastCapsLockState: Bool = false
    private var currentDeviceID: AudioDeviceID = 0
    private var currentVolumeAddress: AudioObjectPropertyAddress?
    
    private init() {
        self.lastCapsLockState = NSEvent.modifierFlags.contains(.capsLock)
    }
    
    public func startMonitoring() {
        setupCapsLockMonitor()
        setupVolumeMonitor()
        readCurrentVolume()
    }
    
    // MARK: - Caps Lock HUD Interceptor
    
    private func setupCapsLockMonitor() {
        flagsGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.checkCapsLock(flags: event.modifierFlags)
        }
        
        flagsLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.checkCapsLock(flags: event.modifierFlags)
            return event
        }
    }
    
    private func checkCapsLock(flags: NSEvent.ModifierFlags) {
        let isCapsLockOn = flags.contains(.capsLock)
        if isCapsLockOn != lastCapsLockState {
            lastCapsLockState = isCapsLockOn
            let title = "Caps Lock"
            let stateStr = isCapsLockOn ? "ON" : "OFF"
            let icon = isCapsLockOn ? "capslock.fill" : "capslock"
            
            IslandState.shared.triggerHUD(
                HUDPayload(
                    type: .capsLock,
                    title: title,
                    subtitle: stateStr,
                    iconName: icon,
                    isSuccess: isCapsLockOn
                )
            )
        }
    }
    
    // MARK: - CoreAudio System Volume Monitoring & Control
    
    private func getDefaultOutputDevice() -> AudioDeviceID {
        var deviceID = AudioDeviceID(0)
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &deviceID
        )
        return status == noErr ? deviceID : 0
    }
    
    private func setupVolumeMonitor() {
        currentDeviceID = getDefaultOutputDevice()
        guard currentDeviceID != 0 else { return }
        
        var volumeAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        if !AudioObjectHasProperty(currentDeviceID, &volumeAddress) {
            volumeAddress.mElement = 1 // Try stereo channel 1
        }
        
        currentVolumeAddress = volumeAddress
        
        _ = AudioObjectAddPropertyListenerBlock(
            currentDeviceID,
            &volumeAddress,
            DispatchQueue.main
        ) { [weak self] _, _ in
            self?.handleVolumeChanged()
        }
    }
    
    private func handleVolumeChanged() {
        let prevVol = currentVolume
        readCurrentVolume()
        
        // Only trigger HUD toast if volume actually moved noticeably
        if abs(currentVolume - prevVol) > 0.01 {
            let icon: String
            if currentVolume == 0 {
                icon = "speaker.slash.fill"
            } else if currentVolume < 0.33 {
                icon = "speaker.wave.1.fill"
            } else if currentVolume < 0.66 {
                icon = "speaker.wave.2.fill"
            } else {
                icon = "speaker.wave.3.fill"
            }
            
            IslandState.shared.triggerHUD(
                HUDPayload(
                    type: .volume,
                    title: "Output Volume",
                    subtitle: nil,
                    iconName: icon,
                    value: currentVolume,
                    isSuccess: true
                )
            )
        }
    }
    
    public func readCurrentVolume() {
        let deviceID = getDefaultOutputDevice()
        guard deviceID != 0 else { return }
        
        var vol: Float32 = 0.5
        var volSize = UInt32(MemoryLayout<Float32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        if !AudioObjectHasProperty(deviceID, &address) {
            address.mElement = 1
        }
        
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &volSize, &vol)
        if status == noErr {
            DispatchQueue.main.async {
                self.currentVolume = max(0.0, min(1.0, vol))
                self.isMuted = (self.currentVolume == 0.0)
            }
        }
    }
    
    public func setSystemVolume(_ volume: Float) {
        let deviceID = getDefaultOutputDevice()
        guard deviceID != 0 else { return }
        
        var clampedVolume = max(0.0, min(1.0, volume))
        let volSize = UInt32(MemoryLayout<Float32>.size)
        
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        if !AudioObjectHasProperty(deviceID, &address) {
            // Set for channel 1 and 2
            address.mElement = 1
            _ = AudioObjectSetPropertyData(deviceID, &address, 0, nil, volSize, &clampedVolume)
            address.mElement = 2
            _ = AudioObjectSetPropertyData(deviceID, &address, 0, nil, volSize, &clampedVolume)
        } else {
            _ = AudioObjectSetPropertyData(deviceID, &address, 0, nil, volSize, &clampedVolume)
        }
        
        self.currentVolume = clampedVolume
        self.isMuted = (clampedVolume == 0.0)
    }
    
    deinit {
        if let g = flagsGlobalMonitor { NSEvent.removeMonitor(g) }
        if let l = flagsLocalMonitor { NSEvent.removeMonitor(l) }
    }
}

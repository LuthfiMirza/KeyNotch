import Cocoa
import CoreAudio
import AudioToolbox
import Combine

public final class MicrophoneService: ObservableObject {
    public static let shared = MicrophoneService()
    
    @Published public var isMicInUse: Bool = false
    @Published public var isMuted: Bool = false
    @Published public var inputVolume: Float = 1.0
    
    private var defaultInputDeviceID: AudioDeviceID = 0
    private var previousVolume: Float = 1.0
    
    // CoreAudio Property Addresses
    private var defaultDeviceAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultInputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    
    private var runningAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    
    private var muteAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyMute,
        mScope: kAudioDevicePropertyScopeInput,
        mElement: kAudioObjectPropertyElementMain
    )
    
    private var volumeAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyVolumeScalar,
        mScope: kAudioDevicePropertyScopeInput,
        mElement: kAudioObjectPropertyElementMain
    )
    
    private var isMonitoring: Bool = false
    
    private init() {
        updateDefaultDevice()
        refreshState()
    }
    
    public func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        
        // 1. Observe changes to the system default input device
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultDeviceAddress,
            DispatchQueue.main
        ) { [weak self] _, _ in
            self?.handleDefaultDeviceChanged()
        }
        
        // 2. Attach listeners to the current default device
        attachDeviceListeners(defaultInputDeviceID)
        
        refreshState()
    }
    
    private func updateDefaultDevice() {
        var deviceID = AudioDeviceID(0)
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultDeviceAddress,
            0,
            nil,
            &propertySize,
            &deviceID
        )
        
        if status == noErr {
            self.defaultInputDeviceID = deviceID
        }
    }
    
    private func handleDefaultDeviceChanged() {
        detachDeviceListeners(defaultInputDeviceID)
        updateDefaultDevice()
        attachDeviceListeners(defaultInputDeviceID)
        refreshState()
    }
    
    private func attachDeviceListeners(_ deviceID: AudioDeviceID) {
        guard deviceID != 0 else { return }
        
        AudioObjectAddPropertyListenerBlock(
            deviceID,
            &runningAddress,
            DispatchQueue.main
        ) { [weak self] _, _ in
            self?.refreshRunningState()
        }
        
        AudioObjectAddPropertyListenerBlock(
            deviceID,
            &muteAddress,
            DispatchQueue.main
        ) { [weak self] _, _ in
            self?.refreshMuteState()
        }
        
        AudioObjectAddPropertyListenerBlock(
            deviceID,
            &volumeAddress,
            DispatchQueue.main
        ) { [weak self] _, _ in
            self?.refreshVolumeState()
        }
    }
    
    private func detachDeviceListeners(_ deviceID: AudioDeviceID) {
        guard deviceID != 0 else { return }
        // CoreAudio will automatically clean block-based listeners or we can replace on next device change
    }
    
    public func refreshState() {
        refreshRunningState()
        refreshMuteState()
        refreshVolumeState()
    }
    
    private func refreshRunningState() {
        guard defaultInputDeviceID != 0 else { return }
        
        var isRunning = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        
        let status = AudioObjectGetPropertyData(
            defaultInputDeviceID,
            &runningAddress,
            0,
            nil,
            &size,
            &isRunning
        )
        
        let inUse = (status == noErr && isRunning != 0)
        if self.isMicInUse != inUse {
            self.isMicInUse = inUse
        }
    }
    
    private func refreshMuteState() {
        guard defaultInputDeviceID != 0 else { return }
        
        var isMutedVal = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        
        let status = AudioObjectGetPropertyData(
            defaultInputDeviceID,
            &muteAddress,
            0,
            nil,
            &size,
            &isMutedVal
        )
        
        var muted = (status == noErr && isMutedVal != 0)
        
        // Also verify volume scalar (if volume is 0.0, consider effectively muted)
        if !muted && inputVolume == 0.0 {
            muted = true
        }
        
        if self.isMuted != muted {
            self.isMuted = muted
        }
    }
    
    private func refreshVolumeState() {
        guard defaultInputDeviceID != 0 else { return }
        
        var vol = Float32(1.0)
        var size = UInt32(MemoryLayout<Float32>.size)
        
        let status = AudioObjectGetPropertyData(
            defaultInputDeviceID,
            &volumeAddress,
            0,
            nil,
            &size,
            &vol
        )
        
        if status == noErr {
            self.inputVolume = vol
            if vol > 0.05 {
                self.previousVolume = vol
            }
        }
    }
    
    // MARK: - Actions
    
    public func toggleMute() {
        setMute(!isMuted)
    }
    
    public func setMute(_ mute: Bool) {
        guard defaultInputDeviceID != 0 else { return }
        
        // 1. Try hardware mute property first
        var isSettable: DarwinBoolean = false
        AudioObjectIsPropertySettable(defaultInputDeviceID, &muteAddress, &isSettable)
        
        if isSettable.boolValue {
            var muteVal = UInt32(mute ? 1 : 0)
            let size = UInt32(MemoryLayout<UInt32>.size)
            _ = AudioObjectSetPropertyData(
                defaultInputDeviceID,
                &muteAddress,
                0,
                nil,
                size,
                &muteVal
            )
        }
        
        // 2. Also adjust input volume scalar as seamless fallback
        var volSettable: DarwinBoolean = false
        AudioObjectIsPropertySettable(defaultInputDeviceID, &volumeAddress, &volSettable)
        if volSettable.boolValue {
            var newVol = Float32(mute ? 0.0 : max(0.5, previousVolume))
            let volSize = UInt32(MemoryLayout<Float32>.size)
            _ = AudioObjectSetPropertyData(
                defaultInputDeviceID,
                &volumeAddress,
                0,
                nil,
                volSize,
                &newVol
            )
            inputVolume = newVol
        }
        
        self.isMuted = mute
        
        // Trigger live iOS-style HUD Toast from the Notch
        triggerMicHUD(isMuted: mute)
    }
    
    private func triggerMicHUD(isMuted: Bool) {
        let payload = HUDPayload(
            type: .custom,
            title: isMuted ? "Microphone Muted" : "Microphone Active",
            subtitle: isMuted ? "Input audio silenced" : "Input audio live",
            iconName: isMuted ? "mic.slash.fill" : "mic.fill",
            value: isMuted ? 0.0 : 1.0,
            rightDetail: isMuted ? "MUTED" : "LIVE",
            customBadgeIcon: nil,
            isSuccess: !isMuted
        )
        IslandState.shared.triggerHUD(payload, duration: 1.2)
    }
}

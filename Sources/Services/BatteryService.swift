import Cocoa
import IOKit.ps
import Combine

public final class BatteryService: ObservableObject {
    public static let shared = BatteryService()
    
    @Published public var batteryPercentage: Int = 100
    @Published public var isCharging: Bool = false
    @Published public var isConnectedToAC: Bool = true
    @Published public var powerSourceState: String = "AC Power"
    
    private var runLoopSource: CFRunLoopSource?
    private var prevConnectedToAC: Bool?
    
    private init() {
        updateBatteryState(isInitial: true)
        setupPowerNotification()
    }
    
    private func setupPowerNotification() {
        let callback: IOPowerSourceCallbackType = { _ in
            BatteryService.shared.updateBatteryState(isInitial: false)
        }
        
        if let source = IOPSNotificationCreateRunLoopSource(callback, nil)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
            self.runLoopSource = source
        }
    }
    
    public func updateBatteryState(isInitial: Bool = false) {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else {
            return
        }
        
        for ps in list {
            guard let desc = IOPSGetPowerSourceDescription(info, ps)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }
            
            let currentCap = desc[kIOPSCurrentCapacityKey] as? Int ?? 100
            let maxCap = desc[kIOPSMaxCapacityKey] as? Int ?? 100
            let state = desc[kIOPSPowerSourceStateKey] as? String ?? "AC Power"
            let isChargingNow = desc[kIOPSIsChargingKey] as? Bool ?? false
            
            let percent = maxCap > 0 ? Int((Double(currentCap) / Double(maxCap)) * 100.0) : currentCap
            let connected = (state == kIOPSACPowerValue)
            
            DispatchQueue.main.async {
                self.batteryPercentage = percent
                self.isCharging = isChargingNow
                self.isConnectedToAC = connected
                self.powerSourceState = state
                
                // Trigger animated Dynamic Island HUD when charging cable plugged/unplugged
                if !isInitial, let prev = self.prevConnectedToAC, prev != connected {
                    if connected {
                        IslandState.shared.triggerHUD(
                            HUDPayload(
                                type: .battery,
                                title: "Charging",
                                subtitle: "Charger connected",
                                iconName: "bolt.fill",
                                value: Float(percent) / 100.0,
                                rightDetail: "\(percent)%",
                                isSuccess: true
                            ),
                            duration: 3.5
                        )
                    } else {
                        IslandState.shared.triggerHUD(
                            HUDPayload(
                                type: .battery,
                                title: "Battery",
                                subtitle: "Using battery power",
                                iconName: "battery.75",
                                value: Float(percent) / 100.0,
                                rightDetail: "\(percent)%",
                                isSuccess: false
                            ),
                            duration: 3.0
                        )
                    }
                }
                
                self.prevConnectedToAC = connected
            }
            break
        }
    }
    
    public func triggerTestChargingHUD(percent: Int = 70) {
        IslandState.shared.triggerHUD(
            HUDPayload(
                type: .battery,
                title: "Charging",
                subtitle: "Charger connected",
                iconName: "bolt.fill",
                value: Float(percent) / 100.0,
                rightDetail: "\(percent)%",
                isSuccess: true
            ),
            duration: 3.5
        )
    }
    
    deinit {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
    }
}

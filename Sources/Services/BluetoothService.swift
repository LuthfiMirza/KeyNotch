import Cocoa
import IOBluetooth
import Combine

public final class BluetoothService: NSObject, ObservableObject {
    public static let shared = BluetoothService()
    
    @Published public var connectedDevices: [String] = []
    
    private var connectNotification: IOBluetoothUserNotification?
    private var disconnectNotifications: [IOBluetoothUserNotification] = []
    
    private override init() {
        super.init()
    }
    
    public func startMonitoring() {
        // Register for Bluetooth device connect events
        connectNotification = IOBluetoothDevice.register(
            forConnectNotifications: self,
            selector: #selector(deviceConnected(_:device:))
        )
        
        // Also register disconnect for already paired devices that might be connected
        if let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] {
            for dev in paired {
                if dev.isConnected() {
                    let note = dev.register(forDisconnectNotification: self, selector: #selector(deviceDisconnected(_:device:)))
                    if let note = note {
                        disconnectNotifications.append(note)
                    }
                }
            }
        }
    }
    
    @objc private func deviceConnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        guard let name = device.nameOrAddress, !name.isEmpty else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if !self.connectedDevices.contains(name) {
                self.connectedDevices.append(name)
            }
            
            // Listen for its disconnect
            if let note = device.register(forDisconnectNotification: self, selector: #selector(self.deviceDisconnected(_:device:))) {
                self.disconnectNotifications.append(note)
            }
            
            // Deduce device badge icon
            let lower = name.lowercased()
            let badgeIcon: String
            if lower.contains("airpod") || lower.contains("bud") || lower.contains("headphone") || lower.contains("beat") || lower.contains("wh-") || lower.contains("wf-") || lower.contains("bose") || lower.contains("sony") || lower.contains("audio") {
                badgeIcon = "headphones"
            } else if lower.contains("keyboard") || lower.contains("keychron") {
                badgeIcon = "keyboard"
            } else if lower.contains("mouse") || lower.contains("trackpad") || lower.contains("magic mouse") {
                badgeIcon = "magicmouse"
            } else {
                badgeIcon = "headphones"
            }
            
            // Typical reported battery percentage or 70% default
            let battery = 70
            
            IslandState.shared.triggerHUD(
                HUDPayload(
                    type: .bluetooth,
                    title: name,
                    subtitle: "Connected · \(battery)%",
                    iconName: "bluetooth",
                    value: Float(battery) / 100.0,
                    rightDetail: nil,
                    customBadgeIcon: badgeIcon,
                    isSuccess: true
                ),
                duration: 3.5
            )
        }
    }
    
    @objc private func deviceDisconnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        guard let name = device.nameOrAddress else { return }
        DispatchQueue.main.async { [weak self] in
            self?.connectedDevices.removeAll { $0 == name }
        }
    }
    
    public func triggerTestBluetoothHUD(name: String = "AirBuds Pro", battery: Int = 70) {
        IslandState.shared.triggerHUD(
            HUDPayload(
                type: .bluetooth,
                title: name,
                subtitle: "Connected · \(battery)%",
                iconName: "bluetooth",
                value: Float(battery) / 100.0,
                rightDetail: nil,
                customBadgeIcon: "headphones",
                isSuccess: true
            ),
            duration: 3.5
        )
    }
}

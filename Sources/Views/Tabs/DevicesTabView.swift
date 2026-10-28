import SwiftUI
import IOBluetooth

public struct DevicesTabView: View {
    @ObservedObject var battery = BatteryService.shared
    @ObservedObject var bluetooth = BluetoothService.shared
    @ObservedObject var mic = MicrophoneService.shared
    @ObservedObject var hud = HUDInterceptorService.shared
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 12) {
            // MARK: - Row 1: Mac Power & Battery Card
            macBatteryCard
            
            // MARK: - Row 2: Bluetooth Peripherals Matrix
            peripheralsSection
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 10)
    }
    
    // MARK: - Mac Battery Card
    
    private var macBatteryCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 4)
                
                Circle()
                    .trim(from: 0, to: CGFloat(battery.batteryPercentage) / 100.0)
                    .stroke(
                        battery.isCharging ? Color.green : (battery.batteryPercentage <= 20 ? Color.red : Color.blue),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                
                Image(systemName: battery.isCharging || battery.isConnectedToAC ? "bolt.fill" : "laptopcomputer")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(battery.isCharging ? .green : .white)
            }
            .frame(width: 38, height: 38)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("MacBook Pro")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    
                    if battery.isCharging {
                        Text("CHARGING")
                            .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                            .foregroundColor(.black)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.green)
                            .clipShape(Capsule())
                    }
                }
                
                Text("\(battery.batteryPercentage)% · \(battery.powerSourceState)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.65))
            }
            
            Spacer()
            
            Text("\(battery.batteryPercentage)%")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    // MARK: - Peripherals Section
    
    private var peripheralsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Connected Peripherals")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
                
                Spacer()
                
                Text("\(bluetooth.connectedDevices.count) Active")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.horizontal, 4)
            
            if bluetooth.connectedDevices.isEmpty {
                // Default / Paired Devices Quick Preview (AirPods Demo / Placeholder)
                HStack(spacing: 10) {
                    peripheralPill(
                        name: "AirPods Pro",
                        icon: "headphones",
                        batteryPercent: 78,
                        isConnected: true
                    )
                    
                    peripheralPill(
                        name: "Magic Mouse",
                        icon: "magicmouse",
                        batteryPercent: 84,
                        isConnected: true
                    )
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(bluetooth.connectedDevices, id: \.self) { devName in
                            peripheralPill(
                                name: devName,
                                icon: deduceDeviceIcon(devName),
                                batteryPercent: 70,
                                isConnected: true
                            )
                        }
                    }
                }
            }
        }
    }
    
    private func peripheralPill(name: String, icon: String, batteryPercent: Int, isConnected: Bool) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text("\(batteryPercent)% Battery")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer(minLength: 4)
            
            Circle()
                .fill(Color.green)
                .frame(width: 6, height: 6)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    
    private func deduceDeviceIcon(_ name: String) -> String {
        let l = name.lowercased()
        if l.contains("bud") || l.contains("pod") || l.contains("headphone") || l.contains("wh-") || l.contains("bose") || l.contains("sony") {
            return "headphones"
        } else if l.contains("mouse") || l.contains("trackpad") {
            return "magicmouse"
        } else if l.contains("keyboard") || l.contains("keychron") {
            return "keyboard"
        }
        return "wave.3.forward"
    }
}

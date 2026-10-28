import SwiftUI
import CoreWLAN

public struct ControlsMediaTabView: View {
    @ObservedObject var telemetry = SystemTelemetryService.shared
    @ObservedObject var battery = BatteryService.shared
    @ObservedObject var caffeinate = CaffeinateService.shared
    @ObservedObject var hud = HUDInterceptorService.shared
    @ObservedObject var pomodoro = PomodoroService.shared
    @ObservedObject var bluetooth = BluetoothService.shared
    @ObservedObject var brightness = BrightnessService.shared
    
    @State private var wifiName: String = "Wi-Fi"
    @State private var isWifiOn: Bool = true
    @State private var isBluetoothOn: Bool = true
    @State private var isFocusActive: Bool = false
    @State private var activeSliderMode: SliderMode = .volume
    
    public enum SliderMode {
        case volume
        case brightness
    }
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 12) {
            // MARK: - Row 1: Wi-Fi & Bluetooth (2 Large Cards)
            networkRow
            
            // MARK: - Row 2: Focus, Awake, Timer (3 Medium Cards)
            togglesRow
            
            // MARK: - Row 3: CPU & RAM Telemetry Bar
            telemetryRow
            
            // MARK: - Row 4: Full-Width Capsule Slider (Volume / Brightness)
            sliderRow
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 10)
        .onAppear {
            refreshWiFi()
            brightness.readCurrentBrightness()
            hud.readCurrentVolume()
        }
    }
    
    // MARK: - Row 1: Wi-Fi & Bluetooth (2 Large Squircle Cards)
    
    private var networkRow: some View {
        HStack(spacing: 12) {
            // Wi-Fi Card
            Button(action: {
                refreshWiFi()
            }) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(isWifiOn ? Color.blue : Color.white.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: "wifi")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Wi-Fi")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                        Text(wifiName)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(.white.opacity(0.65))
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(PlainButtonStyle())
            
            // Bluetooth Card
            Button(action: {
                isBluetoothOn.toggle()
            }) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(isBluetoothOn ? Color.blue : Color.white.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: "wave.3.forward")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Bluetooth")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                        Text(bluetoothSubtitle)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(.white.opacity(0.65))
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private var bluetoothSubtitle: String {
        if !isBluetoothOn { return "Off" }
        if let first = bluetooth.connectedDevices.first {
            return first
        }
        return "On"
    }
    
    // MARK: - Row 2: Focus, Awake, Timer (3 Medium Squircle Cards)
    
    private var togglesRow: some View {
        HStack(spacing: 10) {
            // Focus Card
            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                    isFocusActive.toggle()
                }
            }) {
                HStack(spacing: 9) {
                    ZStack {
                        Circle()
                            .fill(isFocusActive ? Color.indigo : Color.white.opacity(0.12))
                            .frame(width: 30, height: 30)
                        Image(systemName: "moon.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Focus")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                        Text(isFocusActive ? "On" : "Off")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(PlainButtonStyle())
            
            // Awake Card (Caffeinate)
            Button(action: {
                caffeinate.toggle()
            }) {
                HStack(spacing: 9) {
                    ZStack {
                        Circle()
                            .fill(caffeinate.isCaffeinated ? Color.orange : Color.white.opacity(0.12))
                            .frame(width: 30, height: 30)
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Awake")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                        Text(caffeinate.isCaffeinated ? "Active" : "Normal")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(PlainButtonStyle())
            
            // Timer Card (Pomodoro)
            Button(action: {
                pomodoro.toggle()
            }) {
                HStack(spacing: 9) {
                    ZStack {
                        Circle()
                            .fill(pomodoro.isRunning ? Color.green : Color.white.opacity(0.12))
                            .frame(width: 30, height: 30)
                        Image(systemName: "timer")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Timer")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                        Text(pomodoro.isRunning ? pomodoro.formattedTime : "25m")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // MARK: - Row 3: CPU & RAM Telemetry Bar
    
    private var telemetryRow: some View {
        HStack {
            // CPU Metric
            HStack(spacing: 8) {
                Image(systemName: "cpu")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.green)
                Text("CPU")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(String(format: "%.0f%%", telemetry.cpuUsagePercent))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            
            Spacer(minLength: 40)
            
            // RAM Metric
            HStack(spacing: 8) {
                Image(systemName: "memorychip")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.blue)
                Text("RAM")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(String(format: "%.1f/%.0fGB", telemetry.usedRAMGB, telemetry.totalRAMGB))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 2)
    }
    
    // MARK: - Row 4: Full-Width Capsule Slider
    
    private var sliderRow: some View {
        CapsuleSliderView(
            value: Binding(
                get: {
                    activeSliderMode == .volume ? hud.currentVolume : brightness.currentBrightness
                },
                set: { val in
                    if activeSliderMode == .volume {
                        hud.setSystemVolume(val)
                    } else {
                        brightness.setBrightness(val)
                    }
                }
            ),
            iconName: activeSliderMode == .volume ? "speaker.wave.2.fill" : "sun.max.fill"
        ) { newVal in
            if activeSliderMode == .volume {
                hud.setSystemVolume(newVal)
            } else {
                brightness.setBrightness(newVal)
            }
        }
        .frame(height: 38)
    }
    
    // MARK: - Helper Methods
    
    private func refreshWiFi() {
        if let interface = CWWiFiClient.shared().interface() {
            if let ssid = interface.ssid(), !ssid.isEmpty {
                self.wifiName = ssid
                self.isWifiOn = true
            } else {
                let p = interface.powerOn()
                self.isWifiOn = p
                self.wifiName = p ? "Wi-Fi On" : "Wi-Fi Off"
            }
        } else {
            self.wifiName = "Wi-Fi"
        }
    }
}

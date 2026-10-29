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
    @ObservedObject var privacy = PrivacyGuardService.shared
    @ObservedObject var network = NetworkMonitorService.shared
    
    @State private var wifiName: String = "Wi-Fi"
    @State private var isWifiOn: Bool = true
    @State private var isBluetoothOn: Bool = true
    @State private var isFocusActive: Bool = false
    @State private var activeSliderMode: SliderMode = .volume
    
    private var pingColor: Color {
        switch network.pingQuality {
        case .excellent, .good: return .green
        case .fair: return .yellow
        case .poor: return .red
        case .unknown: return .gray
        }
    }
    
    public enum SliderMode {
        case volume
        case brightness
    }
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 10) {
            // MARK: - Privacy Spy Guard Alert Banner (if Camera or Mic active)
            if privacy.isCameraInUse || privacy.isMicInUse {
                privacyAlertBanner
            }
            
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
        .padding(.top, (privacy.isCameraInUse || privacy.isMicInUse) ? 2 : 6)
        .padding(.bottom, 8)
        .onAppear {
            refreshWiFi()
            brightness.readCurrentBrightness()
            hud.readCurrentVolume()
            network.sampleNetwork()
        }
    }
    
    // MARK: - Row 1: Wi-Fi & Bluetooth (2 Large Squircle Cards)
    
    private var networkRow: some View {
        HStack(spacing: 12) {
            // Wi-Fi Card
            Button(action: {
                refreshWiFi()
                network.sampleNetwork()
            }) {
                HStack(spacing: 10) {
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
                    
                    Spacer(minLength: 4)
                    
                    // Live Network Speed & Ping Quality Badge
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(pingColor)
                                .frame(width: 5, height: 5)
                            Text(network.pingString)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.green)
                            Text(network.downloadSpeedString)
                                .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.75))
                        }
                    }
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
    
    // MARK: - Row 3: CPU, Network Speedometer, Ping Radar, Spy Guard & RAM Telemetry Bar
    
    private var telemetryRow: some View {
        HStack(spacing: 8) {
            // CPU Metric
            HStack(spacing: 6) {
                Image(systemName: "cpu")
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundColor(.green)
                Text("CPU")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                Text(String(format: "%.0f%%", telemetry.cpuUsagePercent))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            
            Spacer(minLength: 4)
            
            // Center Cluster: Live Network Speedometer + Ping Latency Radar + Spy Guard
            HStack(spacing: 5) {
                // Network Speedometer Pill (Download & Upload) - Click to toggle compact notch view
                Button(action: {
                    network.toggleShowInCompactNotch()
                }) {
                    HStack(spacing: 5) {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.green)
                            Text(network.downloadSpeedString)
                                .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.cyan)
                            Text(network.uploadSpeedString)
                                .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3.5)
                    .background(network.showInCompactNotch ? Color.cyan.opacity(0.18) : Color.white.opacity(0.06))
                    .overlay(
                        Capsule()
                            .stroke(network.showInCompactNotch ? Color.cyan.opacity(0.4) : Color.clear, lineWidth: 1)
                    )
                    .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
                .help(network.showInCompactNotch ? "Pin in compact notch is ON (click to disable)" : "Click to pin live network speed inside compact notch")
                
                // Ping Radar Pill - Click to ping immediate refresh
                Button(action: {
                    network.sampleNetwork()
                }) {
                    HStack(spacing: 3.5) {
                        Circle()
                            .fill(pingColor)
                            .frame(width: 5, height: 5)
                        Text(network.pingString)
                            .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3.5)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
                .help("Click to refresh Ping Latency Radar (TCP 1.1.1.1 / 8.8.8.8)")
                
                // Center Spy Guard Status / Test Pill
                Button(action: {
                    privacy.toggleSimulateSpyGuard()
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: (privacy.isCameraInUse || privacy.isMicInUse) ? "shield.fill" : "shield")
                            .font(.system(size: 8.5, weight: .bold))
                        Text((privacy.isCameraInUse || privacy.isMicInUse) ? "Guarding" : "Spy Guard")
                            .font(.system(size: 9.5, weight: .semibold))
                    }
                    .foregroundColor((privacy.isCameraInUse || privacy.isMicInUse) ? Color.green : Color.white.opacity(0.45))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3.5)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
                .help("Click to test Privacy Spy Guard")
            }
            
            Spacer(minLength: 4)
            
            // RAM Metric
            HStack(spacing: 6) {
                Image(systemName: "memorychip")
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundColor(.blue)
                Text("RAM")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                Text(String(format: "%.1f/%.0fGB", telemetry.usedRAMGB, telemetry.totalRAMGB))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 2)
    }
    
    // MARK: - Privacy Spy Guard Alert Banner
    private var privacyAlertBanner: some View {
        HStack(spacing: 9) {
            // Pulsing Dot Indicators
            HStack(spacing: 4) {
                if privacy.isCameraInUse {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                        .shadow(color: Color.green.opacity(0.8), radius: 3)
                }
                if privacy.isMicInUse {
                    Circle()
                        .fill(privacy.isMicMuted ? Color.red : Color.orange)
                        .frame(width: 8, height: 8)
                        .shadow(color: (privacy.isMicMuted ? Color.red : Color.orange).opacity(0.8), radius: 3)
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(privacy.activeAppName)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(privacyStatusText)
                    .font(.system(size: 9.5))
                    .foregroundColor(.white.opacity(0.65))
            }
            
            Spacer()
            
            // 1-Click Mute Mic
            if privacy.isMicInUse {
                Button(action: {
                    privacy.toggleMute()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: privacy.isMicMuted ? "mic.slash.fill" : "mic.fill")
                            .font(.system(size: 9, weight: .bold))
                        Text(privacy.isMicMuted ? "Unmute" : "Mute Mic")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(privacy.isMicMuted ? Color.red : Color.orange)
                    .clipShape(Capsule())
                    .shadow(color: (privacy.isMicMuted ? Color.red : Color.orange).opacity(0.4), radius: 3)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke((privacy.isCameraInUse ? Color.green : Color.orange).opacity(0.35), lineWidth: 1)
                )
        )
    }
    
    private var privacyStatusText: String {
        if privacy.isCameraInUse && privacy.isMicInUse {
            return privacy.isMicMuted ? "Camera active • Mic muted" : "Camera & Microphone active"
        } else if privacy.isCameraInUse {
            return "Camera is currently recording"
        } else {
            return privacy.isMicMuted ? "Microphone input is muted" : "Microphone is capturing audio"
        }
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

import SwiftUI
import CoreWLAN

public struct ControlsMediaTabView: View {
    @ObservedObject var media = MediaRemoteService.shared
    @ObservedObject var telemetry = SystemTelemetryService.shared
    @ObservedObject var battery = BatteryService.shared
    @ObservedObject var caffeinate = CaffeinateService.shared
    @ObservedObject var hud = HUDInterceptorService.shared
    @ObservedObject var devTools = DevToolsService.shared
    @ObservedObject var mic = MicrophoneService.shared
    @ObservedObject var network = NetworkMonitorService.shared
    @ObservedObject var brightness = BrightnessService.shared
    
    @State private var wifiName: String = "Wi-Fi"
    @State private var isFocusActive: Bool = false
    @State private var isBluetoothOn: Bool = true
    
    private var pingColor: Color {
        switch network.pingQuality {
        case .excellent, .good: return .green
        case .fair: return .yellow
        case .poor: return .red
        case .unknown: return .gray
        }
    }
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 10) {
            // MARK: - 1. Dual Sliders: Display Brightness & Sound Volume
            slidersSection
            
            // MARK: - 2. Quick Toggles Matrix (Wi-Fi, Bluetooth, Mute, Caffeinate, Focus)
            quickTogglesSection
            
            // MARK: - 3. Mini Now Playing Shortcut (if active)
            if media.hasActiveMedia || !media.title.isEmpty {
                nowPlayingShortcutBar
            }
            
            // MARK: - 4. Mach Kernel System Stats & Battery Strip
            systemTelemetryStrip
            
            // MARK: - 5. Dev Tools Strip (Ports & Native Color Picker)
            devToolsStrip
        }
        .padding(.horizontal, 14)
        .padding(.top, 4)
        .onAppear {
            refreshWiFi()
            brightness.readCurrentBrightness()
            devTools.scanActivePorts()
        }
    }
    
    // MARK: - 1. Dual Sliders (Display Brightness & Sound Volume)
    
    private var slidersSection: some View {
        HStack(spacing: 8) {
            // Display Brightness Slider
            CapsuleSliderView(
                value: Binding(
                    get: { brightness.currentBrightness },
                    set: { brightness.setBrightness($0) }
                ),
                iconName: "sun.max.fill"
            ) { newBrightness in
                brightness.setBrightness(newBrightness)
            }
            
            // Sound Volume Slider
            CapsuleSliderView(
                value: Binding(
                    get: { hud.currentVolume },
                    set: { hud.setSystemVolume($0) }
                ),
                iconName: "speaker.wave.3.fill"
            ) { newVolume in
                hud.setSystemVolume(newVolume)
            }
        }
    }
    
    // MARK: - 2. Quick Toggles Matrix (Wi-Fi, Bluetooth, Mute, Caffeinate, Focus)
    
    private var quickTogglesSection: some View {
        HStack(spacing: 6) {
            // Wi-Fi Button
            Button(action: {
                refreshWiFi()
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "wifi")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.blue)
                    
                    Text(wifiName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(PlainButtonStyle())
            
            // Bluetooth Button
            Button(action: {
                isBluetoothOn.toggle()
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "wave.3.forward")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(isBluetoothOn ? .blue : .gray)
                    
                    Text(isBluetoothOn ? "Bluetooth On" : "Bluetooth Off")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(PlainButtonStyle())
            
            // Microphone Privacy & Global Mute Button
            Button(action: {
                mic.toggleMute()
            }) {
                HStack(spacing: 5) {
                    Image(systemName: mic.isMuted ? "mic.slash.fill" : (mic.isMicInUse ? "mic.fill" : "mic"))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(mic.isMuted ? .red : (mic.isMicInUse ? .orange : .white.opacity(0.6)))
                    
                    Text(mic.isMuted ? "Muted" : (mic.isMicInUse ? "Mic Live" : "Mic On"))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    mic.isMuted
                    ? Color.red.opacity(0.22)
                    : (mic.isMicInUse ? Color.orange.opacity(0.22) : Color.white.opacity(0.08))
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(PlainButtonStyle())
            
            // Caffeinate Toggle Button
            Button(action: {
                caffeinate.toggle()
            }) {
                HStack(spacing: 5) {
                    Image(systemName: caffeinate.isCaffeinated ? "cup.and.saucer.fill" : "cup.and.saucer")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(caffeinate.isCaffeinated ? .orange : .white.opacity(0.6))
                    
                    Text(caffeinate.isCaffeinated ? "Awake" : "Caffeinate")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    caffeinate.isCaffeinated
                    ? Color.orange.opacity(0.25)
                    : Color.white.opacity(0.08)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(PlainButtonStyle())
            
            // Focus / DND Button
            Button(action: {
                isFocusActive.toggle()
            }) {
                HStack(spacing: 5) {
                    Image(systemName: isFocusActive ? "moon.fill" : "moon")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(isFocusActive ? .indigo : .white.opacity(0.6))
                    
                    Text(isFocusActive ? "Focus On" : "Focus")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    isFocusActive
                    ? Color.indigo.opacity(0.25)
                    : Color.white.opacity(0.08)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // MARK: - 3. Mini Now Playing Shortcut Bar
    
    private var nowPlayingShortcutBar: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                IslandState.shared.selectedTab = .music
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: "music.note")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.green)
                
                Text(media.title + (media.artist.isEmpty ? "" : " · \(media.artist)"))
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
                
                Spacer()
                
                if media.isPlaying {
                    WaveformView(isPlaying: true, color: .green, barCount: 4, maxHeight: 9)
                }
                
                Text("Open Player →")
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.55))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - System Telemetry Strip
    
    private var systemTelemetryStrip: some View {
        HStack(spacing: 6) {
            // CPU Pill
            HStack(spacing: 4) {
                Image(systemName: "cpu")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.cyan)
                
                Text(String(format: "CPU: %.1f%%", telemetry.cpuUsagePercent))
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.07))
            .clipShape(Capsule())
            
            // RAM Pill
            HStack(spacing: 4) {
                Image(systemName: "memorychip")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.purple)
                
                Text(telemetry.ramUsageString)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.07))
            .clipShape(Capsule())
            
            // Network Speedometer Pill (Download & Upload)
            HStack(spacing: 5) {
                HStack(spacing: 2) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.green)
                    Text(network.downloadSpeedString)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.9))
                }
                
                HStack(spacing: 2) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.blue)
                    Text(network.uploadSpeedString)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.07))
            .clipShape(Capsule())
            
            // Ping Radar Pill
            Button(action: {
                network.sampleNetwork()
            }) {
                HStack(spacing: 3) {
                    Circle()
                        .fill(pingColor)
                        .frame(width: 5, height: 5)
                    Text(network.pingString)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.07))
                .clipShape(Capsule())
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            // Battery & MagSafe Indicator
            HStack(spacing: 3) {
                Image(systemName: battery.isCharging || battery.isConnectedToAC ? "bolt.fill" : "battery.75")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(battery.batteryPercentage <= 20 ? .red : (battery.isCharging ? .green : .white))
                
                Text("\(battery.batteryPercentage)%")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                battery.isCharging
                ? Color.green.opacity(0.2)
                : Color.white.opacity(0.07)
            )
            .clipShape(Capsule())
        }
    }
    

    
    // MARK: - Dev Tools Strip (Color Picker & Active Ports)
    
    private var devToolsStrip: some View {
        HStack(spacing: 8) {
            // Color Picker Button
            Button(action: {
                devTools.pickColor()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "eyedropper.halffull")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.pink)
                    Text(devTools.lastPickedHex ?? "Pick Color")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
            }
            .buttonStyle(PlainButtonStyle())
            
            // Active Dev Ports
            if devTools.activePorts.isEmpty {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.gray.opacity(0.5))
                        .frame(width: 4, height: 4)
                    Text("No dev servers")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.4))
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        ForEach(devTools.activePorts) { port in
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 4, height: 4)
                                Text(":\(String(port.port))")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                
                                Button(action: { devTools.openPort(port.port) }) {
                                    Image(systemName: "arrow.up.right")
                                        .font(.system(size: 7, weight: .bold))
                                        .foregroundColor(.cyan)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Button(action: { devTools.killProcess(pid: port.pid, port: port.port) }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 7, weight: .bold))
                                        .foregroundColor(.red.opacity(0.8))
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Capsule())
                        }
                    }
                }
            }
            
            Spacer()
            
            // Refresh Ports Button
            Button(action: { devTools.scanActivePorts() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private func refreshWiFi() {
        if let interface = CWWiFiClient.shared().interface() {
            if let ssid = interface.ssid(), !ssid.isEmpty {
                self.wifiName = ssid
            } else {
                self.wifiName = interface.powerOn() ? "Wi-Fi On" : "Wi-Fi Off"
            }
        } else {
            self.wifiName = "Wi-Fi"
        }
    }
}

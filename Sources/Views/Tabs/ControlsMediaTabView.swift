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
    
    @State private var wifiName: String = "Wi-Fi"
    @State private var isFocusActive: Bool = false
    @State private var isBluetoothOn: Bool = true
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 8) {
            // MARK: - 1. Universal Now Playing Card
            mediaPlayerCard
            
            // MARK: - 2. Mach Kernel System Stats & Battery Strip
            systemTelemetryStrip
            
            // MARK: - 3. iOS Control Center Quick Toggles & Volume Slider
            controlCenterSection
            
            // MARK: - 4. Dev Tools Strip (Ports & Native Color Picker)
            devToolsStrip
        }
        .padding(.horizontal, 14)
        .padding(.top, 2)
        .onAppear {
            refreshWiFi()
            media.refreshNowPlaying()
            devTools.scanActivePorts()
        }
    }
    
    // MARK: - Media Player Card
    
    private var mediaPlayerCard: some View {
        HStack(spacing: 12) {
            // Album Artwork
            ZStack {
                if let artwork = media.artwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "music.note")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
            )
            
            // Track Info & Animated Waveform
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(media.title.isEmpty ? "No Media Playing" : media.title)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    if media.isPlaying {
                        WaveformView(isPlaying: true, color: .green, barCount: 4, maxHeight: 10)
                    }
                }
                
                Text(media.artist.isEmpty ? "Audio playback will appear here" : media.artist)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.white.opacity(0.65))
                    .lineLimit(1)
            }
            
            Spacer(minLength: 8)
            
            // Playback Controls
            HStack(spacing: 8) {
                // Previous
                Button(action: {
                    media.previousTrack()
                }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.75))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Play / Pause
                Button(action: {
                    media.togglePlayPause()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 28, height: 28)
                        
                        Image(systemName: media.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.black)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                // Next
                Button(action: {
                    media.nextTrack()
                }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.75))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
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
    
    // MARK: - Control Center Grid & Volume Slider
    
    private var controlCenterSection: some View {
        VStack(spacing: 6) {
            // Grid of 4 Control Center Pills
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
            
            // Interactive iOS Volume Capsule Slider
            CapsuleSliderView(
                value: Binding(
                    get: { hud.currentVolume },
                    set: { hud.setSystemVolume($0) }
                )
            ) { newVolume in
                hud.setSystemVolume(newVolume)
            }
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
                                Text(":\(port.port)")
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

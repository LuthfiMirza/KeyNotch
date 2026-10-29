import SwiftUI

public struct BluetoothIconShape: Shape {
    public init() {}
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        path.move(to: CGPoint(x: w * 0.22, y: h * 0.28))
        path.addLine(to: CGPoint(x: w * 0.78, y: h * 0.72))
        path.addLine(to: CGPoint(x: w * 0.50, y: h * 0.96))
        path.addLine(to: CGPoint(x: w * 0.50, y: h * 0.04))
        path.addLine(to: CGPoint(x: w * 0.78, y: h * 0.28))
        path.addLine(to: CGPoint(x: w * 0.22, y: h * 0.72))
        
        return path
    }
}

public struct HUDToastView: View {
    let payload: HUDPayload
    
    // Vibrant Curated Colors matching Apple Dynamic Island
    private let chargingGreen = Color(red: 0.18, green: 0.86, blue: 0.44)
    private let bluetoothBlue = Color(red: 0.28, green: 0.74, blue: 1.0)
    
    public init(payload: HUDPayload) {
        self.payload = payload
    }
    
    public var body: some View {
        Group {
            switch payload.type {
            case .battery:
                chargingToastView
            case .bluetooth:
                bluetoothToastView
            case .volume, .brightness:
                sliderToastView
            case .whatsapp:
                whatsAppToastView
            case .incomingCall:
                incomingCallToastView
            default:
                standardToastView
            }
        }
        .frame(height: payload.type == .battery ? 52 : (payload.type == .bluetooth ? 48 : (payload.type == .whatsapp ? 96 : (payload.type == .incomingCall ? ((payload.iconName == "video.fill" || (payload.subtitle?.lowercased().contains("video") == true)) ? 92 : 66) : 46))))
    }
    
    // MARK: - 1. Charging Toast (Enlarged Morphing Capsule 370x52)
    
    private var chargingToastView: some View {
        HStack(spacing: 14) {
            // Circular Battery Ring with Lightning Bolt in center
            ZStack {
                // Background Track
                Circle()
                    .stroke(chargingGreen.opacity(0.22), lineWidth: 3.5)
                
                // Progress Stroke
                Circle()
                    .trim(from: 0, to: CGFloat(payload.value ?? 0.70))
                    .stroke(
                        chargingGreen,
                        style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                
                // Center Dark Background
                Circle()
                    .fill(Color.black.opacity(0.85))
                    .frame(width: 22, height: 22)
                
                // Center Bolt
                Image(systemName: "bolt.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(width: 32, height: 32)
            .padding(.leading, 18)
            
            // Text: Title & Subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(payload.title)
                    .font(.system(size: 14.5, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(payload.subtitle ?? "Charger connected")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.white.opacity(0.65))
                    .lineLimit(1)
            }
            
            Spacer(minLength: 12)
            
            // Right Large Percentage
            Text(payload.rightDetail ?? "\(Int((payload.value ?? 0.70) * 100))%")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
                .padding(.trailing, 20)
        }
    }
    
    // MARK: - 2. Bluetooth Device Connected Toast (Enlarged Capsule 360x48)
    
    private var bluetoothToastView: some View {
        HStack(spacing: 12) {
            // Circular Blue Ring with Bluetooth icon in center
            ZStack {
                // Background Track
                Circle()
                    .stroke(bluetoothBlue.opacity(0.25), lineWidth: 3.2)
                
                // Progress Stroke
                Circle()
                    .trim(from: 0, to: CGFloat(payload.value ?? 0.70))
                    .stroke(
                        bluetoothBlue,
                        style: StrokeStyle(lineWidth: 3.2, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                
                // Center Dark Background
                Circle()
                    .fill(Color.black.opacity(0.85))
                    .frame(width: 20, height: 20)
                
                // Center Bluetooth Rune
                BluetoothIconShape()
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                    .frame(width: 9, height: 13)
            }
            .frame(width: 29, height: 29)
            .padding(.leading, 16)
            
            // Text: Device Name & Subtitle
            VStack(alignment: .leading, spacing: 1.5) {
                Text(payload.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(payload.subtitle ?? "Connected · 70%")
                    .font(.system(size: 10.5, weight: .regular))
                    .foregroundColor(.white.opacity(0.65))
                    .lineLimit(1)
            }
            
            Spacer(minLength: 12)
            
            // Right Concentric Radar Waves with Headphones Icon
            ZStack {
                Circle()
                    .stroke(bluetoothBlue.opacity(0.25), lineWidth: 1.2)
                    .frame(width: 32, height: 32)
                
                Circle()
                    .stroke(bluetoothBlue.opacity(0.70), lineWidth: 1.5)
                    .frame(width: 25, height: 25)
                
                Circle()
                    .fill(Color(red: 0.08, green: 0.22, blue: 0.32))
                    .frame(width: 19, height: 19)
                
                Image(systemName: payload.customBadgeIcon ?? "headphones")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(.trailing, 18)
        }
    }
    
    // MARK: - 3. Volume / Brightness Slider Toast
    
    private var sliderToastView: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 26, height: 26)
                
                Image(systemName: payload.iconName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(.leading, 12)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(payload.title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                if let value = payload.value {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.18))
                                .frame(height: 5)
                            
                            Capsule()
                                .fill(Color.white)
                                .frame(width: geo.size.width * CGFloat(max(0.0, min(1.0, value))), height: 5)
                        }
                    }
                    .frame(height: 5)
                }
            }
            
            Spacer()
            
            if let value = payload.value {
                Text("\(Int(value * 100))%")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.trailing, 14)
            }
        }
    }
    
    // MARK: - 4. Standard Capsule Toast (Caps Lock / Custom)
    
    private var standardToastView: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 26, height: 26)
                
                Image(systemName: payload.iconName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(payload.isSuccess ? .white : .orange)
            }
            .padding(.leading, 12)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(payload.title)
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                if let sub = payload.subtitle {
                    Text(sub)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(.white.opacity(0.65))
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            if let sub = payload.subtitle {
                Text(sub.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Capsule())
                    .foregroundColor(.white)
                    .padding(.trailing, 12)
            }
        }
    }
    
    // MARK: - 4. WhatsApp Message Toast with Quick Reply (Screenshot 3 & 5)
    
    private var whatsAppToastView: some View {
        WhatsAppToastContentView(payload: payload)
    }
    
    // MARK: - 5. Incoming Call Toast (Screenshot 1)
    
    private var incomingCallToastView: some View {
        IncomingCallToastContentView(payload: payload)
    }
}

// MARK: - Subviews

public struct WhatsAppToastContentView: View {
    let payload: HUDPayload
    @State private var replyText: String = ""
    @FocusState private var isFieldFocused: Bool
    
    public init(payload: HUDPayload) {
        self.payload = payload
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            // Top: Contact Avatar with App Badge + Name + "now" + Message Preview
            Button(action: {
                WhatsAppNotificationService.shared.openWhatsApp()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                    IslandState.shared.activeHUD = nil
                }
            }) {
                HStack(alignment: .top, spacing: 12) {
                    ContactAvatarView(
                        name: payload.title,
                        imagePath: payload.avatarImagePath,
                        size: 38,
                        appBadge: "whatsapp"
                    )
                    
                    VStack(alignment: .leading, spacing: 2.5) {
                        HStack {
                            Text(payload.title)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text(payload.timestampText ?? "now")
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundColor(.white.opacity(0.45))
                        }
                        
                        Text(payload.subtitle ?? "Pesan baru")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Bottom: Inline Quick Reply Capsule (Screenshot 5)
            HStack(spacing: 8) {
                TextField("WhatsApp", text: $replyText, onCommit: {
                    sendReply()
                })
                .focused($isFieldFocused)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 12.5, weight: .regular))
                .foregroundColor(.white)
                .padding(.leading, 12)
                .padding(.vertical, 6)
                
                if replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.45))
                        .padding(.trailing, 12)
                } else {
                    Button(action: {
                        sendReply()
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(Color(red: 0.15, green: 0.83, blue: 0.40))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.trailing, 8)
                }
            }
            .frame(height: 32)
            .background(Color.white.opacity(0.08))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isFieldFocused ? Color(red: 0.15, green: 0.83, blue: 0.40).opacity(0.6) : Color.white.opacity(0.12), lineWidth: 0.8)
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    private func sendReply() {
        let text = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        WhatsAppNotificationService.shared.sendQuickReply(text: text)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
            IslandState.shared.activeHUD = nil
        }
    }
}

public struct CameraFramingBoxView: View {
    @ObservedObject var camera = CameraPreviewService.shared
    let fallbackName: String
    let fallbackAvatar: String?
    
    public init(fallbackName: String, fallbackAvatar: String?) {
        self.fallbackName = fallbackName
        self.fallbackAvatar = fallbackAvatar
    }
    
    public var body: some View {
        ZStack {
            if camera.isAuthorized && camera.hasCamera {
                CameraPreviewView()
                    .frame(width: 105, height: 68)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.4), Color(red: 0.18, green: 0.86, blue: 0.44).opacity(0.5), Color.white.opacity(0.12)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.2
                            )
                    )
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 105, height: 68)
                    
                    ContactAvatarView(
                        name: fallbackName,
                        imagePath: fallbackAvatar,
                        size: 38,
                        appBadge: nil
                    )
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
            }
            
            // Bottom-left LIVE camera indicator pill
            VStack {
                Spacer()
                HStack {
                    HStack(spacing: 3.5) {
                        Circle()
                            .fill(Color(red: 0.18, green: 0.86, blue: 0.44))
                            .frame(width: 5.5, height: 5.5)
                        Image(systemName: "video.fill")
                            .font(.system(size: 7.5, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 5.5)
                    .padding(.vertical, 2.5)
                    .background(Color.black.opacity(0.65))
                    .clipShape(Capsule())
                    .padding(5)
                    
                    Spacer()
                }
            }
        }
        .frame(width: 105, height: 68)
        .onAppear {
            camera.start()
        }
        .onDisappear {
            camera.stop()
        }
    }
}

public struct IncomingCallToastContentView: View {
    let payload: HUDPayload
    
    public init(payload: HUDPayload) {
        self.payload = payload
    }
    
    private var isVideo: Bool {
        payload.iconName == "video.fill" || (payload.subtitle?.lowercased().contains("video") == true)
    }
    
    public var body: some View {
        if isVideo {
            widescreenVideoCallView
        } else {
            standardAudioCallView
        }
    }
    
    // MARK: - Option A: Widescreen Video Call with Live Camera Framing Mirror
    private var widescreenVideoCallView: some View {
        HStack(spacing: 14) {
            // Left: Live Camera Framing Mirror
            CameraFramingBoxView(
                fallbackName: payload.title,
                fallbackAvatar: payload.avatarImagePath
            )
            .padding(.leading, 12)
            
            // Middle: Caller Details
            VStack(alignment: .leading, spacing: 3) {
                // WhatsApp Video Badge
                HStack(spacing: 4.5) {
                    Image(systemName: "video.fill")
                        .font(.system(size: 9, weight: .bold))
                    Text("WHATSAPP VIDEO")
                        .font(.system(size: 9.5, weight: .heavy))
                }
                .foregroundColor(Color(red: 0.18, green: 0.86, blue: 0.44))
                .padding(.horizontal, 7)
                .padding(.vertical, 2.5)
                .background(Color(red: 0.18, green: 0.86, blue: 0.44).opacity(0.15))
                .clipShape(Capsule())
                
                Text(payload.title)
                    .font(.system(size: 16.5, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text("Panggilan Video Masuk...")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(.white.opacity(0.65))
                    .lineLimit(1)
            }
            
            Spacer(minLength: 8)
            
            // Right: Dual Interactive Action Buttons (Decline 🔴 & Accept 🟢)
            HStack(spacing: 12) {
                // Red Decline Button
                Button(action: {
                    WhatsAppNotificationService.shared.declineCall()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.95, green: 0.26, blue: 0.24))
                            .frame(width: 38, height: 38)
                            .shadow(color: Color(red: 0.95, green: 0.26, blue: 0.24).opacity(0.35), radius: 4)
                        
                        Image(systemName: "phone.down.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .help("Tolak Panggilan")
                
                // Green Accept Video Call Button
                Button(action: {
                    WhatsAppNotificationService.shared.acceptCall(
                        caller: payload.title,
                        isVideo: true,
                        source: "WhatsApp Video",
                        avatarPath: payload.avatarImagePath
                    )
                }) {
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.18, green: 0.86, blue: 0.44))
                            .frame(width: 38, height: 38)
                            .shadow(color: Color(red: 0.18, green: 0.86, blue: 0.44).opacity(0.4), radius: 4)
                        
                        Image(systemName: "video.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .help("Jawab Video Call")
            }
            .padding(.trailing, 14)
        }
    }
    
    // MARK: - Standard Audio Call View
    private var standardAudioCallView: some View {
        HStack(spacing: 12) {
            // Left: Circular Contact Avatar
            ContactAvatarView(
                name: payload.title,
                imagePath: payload.avatarImagePath,
                size: 44,
                appBadge: nil
            )
            .padding(.leading, 14)
            
            // Middle: "from iPhone" Subtitle + Bold Caller Name
            VStack(alignment: .leading, spacing: 2) {
                Text(payload.subtitle ?? "from iPhone")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.65))
                    .lineLimit(1)
                
                Text(payload.title)
                    .font(.system(size: 15.5, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            
            Spacer(minLength: 8)
            
            // Right: Dual Interactive Buttons
            HStack(spacing: 12) {
                Button(action: {
                    WhatsAppNotificationService.shared.declineCall()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.95, green: 0.26, blue: 0.24))
                            .frame(width: 38, height: 38)
                            .shadow(color: Color(red: 0.95, green: 0.26, blue: 0.24).opacity(0.35), radius: 4)
                        
                        Image(systemName: "phone.down.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .help("Tolak Panggilan")
                
                Button(action: {
                    WhatsAppNotificationService.shared.acceptCall(
                        caller: payload.title,
                        isVideo: false,
                        source: payload.subtitle ?? "from iPhone",
                        avatarPath: payload.avatarImagePath
                    )
                }) {
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.18, green: 0.86, blue: 0.44))
                            .frame(width: 38, height: 38)
                            .shadow(color: Color(red: 0.18, green: 0.86, blue: 0.44).opacity(0.4), radius: 4)
                        
                        Image(systemName: "phone.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .help("Jawab Panggilan")
            }
            .padding(.trailing, 14)
        }
    }
}

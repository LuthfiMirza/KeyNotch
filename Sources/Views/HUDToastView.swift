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
            default:
                standardToastView
            }
        }
        .frame(height: payload.type == .battery ? 52 : (payload.type == .bluetooth ? 48 : (payload.type == .whatsapp ? 54 : 46)))
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
    
    // MARK: - 5. WhatsApp Incoming Message Banner (Morphing Capsule 390x54)
    
    private var whatsAppToastView: some View {
        Button(action: {
            WhatsAppNotificationService.shared.openWhatsApp()
            IslandState.shared.activeHUD = nil
        }) {
            HStack(spacing: 12) {
                // Glowing WhatsApp App Icon Badge
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.15, green: 0.83, blue: 0.40), Color(red: 0.08, green: 0.68, blue: 0.32)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 34, height: 34)
                        .shadow(color: Color(red: 0.15, green: 0.83, blue: 0.40).opacity(0.4), radius: 4)
                    
                    Image(systemName: "message.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.leading, 14)
                
                // Contact / Group Name & Message Preview
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(payload.title)
                            .font(.system(size: 13.5, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text("WhatsApp")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundColor(Color(red: 0.15, green: 0.83, blue: 0.40))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Color(red: 0.15, green: 0.83, blue: 0.40).opacity(0.18))
                            .clipShape(Capsule())
                    }
                    
                    Text(payload.subtitle ?? "Pesan baru")
                        .font(.system(size: 11.5, weight: .regular))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(1)
                }
                
                Spacer(minLength: 8)
                
                // Action: "Open / Buka" Pill
                HStack(spacing: 3) {
                    Text("Buka")
                        .font(.system(size: 10, weight: .bold))
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 8, weight: .bold))
                }
                .foregroundColor(.white.opacity(0.85))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.12))
                .clipShape(Capsule())
                .padding(.trailing, 14)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

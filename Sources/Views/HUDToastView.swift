import SwiftUI

public struct HUDToastView: View {
    let payload: HUDPayload
    
    public init(payload: HUDPayload) {
        self.payload = payload
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            // Left Status Glyph
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 32, height: 32)
                
                Image(systemName: payload.iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(payload.isSuccess ? .white : .orange)
            }
            .padding(.leading, 8)
            
            // Middle Content: Title + Subtitle or Slider Bar
            VStack(alignment: .leading, spacing: 3) {
                Text(payload.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                if let value = payload.value {
                    // Capsule Slider Bar (iOS style)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.18))
                                .frame(height: 6)
                            
                            Capsule()
                                .fill(Color.white)
                                .frame(width: geo.size.width * CGFloat(max(0.0, min(1.0, value))), height: 6)
                        }
                    }
                    .frame(height: 6)
                } else if let subtitle = payload.subtitle {
                    Text(subtitle)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Right Value Pill
            if let value = payload.value {
                Text("\(Int(value * 100))%")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.trailing, 8)
            } else if let subtitle = payload.subtitle, payload.value == nil {
                // If it's a state like "ON" / "OFF"
                Text(subtitle.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Capsule())
                    .foregroundColor(.white)
                    .padding(.trailing, 6)
            }
        }
        .frame(height: 46)
        .padding(.horizontal, 6)
    }
}

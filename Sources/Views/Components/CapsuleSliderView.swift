import SwiftUI

public struct CapsuleSliderView: View {
    @Binding var value: Float
    let iconName: String
    let onEditingChanged: ((Float) -> Void)?
    
    public init(
        value: Binding<Float>,
        iconName: String = "speaker.wave.3.fill",
        onEditingChanged: ((Float) -> Void)? = nil
    ) {
        self._value = value
        self.iconName = iconName
        self.onEditingChanged = onEditingChanged
    }
    
    public var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let fillWidth = max(0, min(width, width * CGFloat(value)))
            
            ZStack(alignment: .leading) {
                // Background Track
                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .fill(Color.white.opacity(0.12))
                
                // Active Fill
                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .fill(Color.white)
                    .frame(width: fillWidth)
                
                // Content Overlay: Speaker Icon & Label
                HStack(spacing: 8) {
                    Image(systemName: dynamicIconName())
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(value > 0.08 ? Color.black.opacity(0.85) : Color.white)
                        .padding(.leading, 14)
                    
                    Spacer()
                    
                    Text("\(Int(value * 100))%")
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        .foregroundColor(value > 0.88 ? Color.black.opacity(0.85) : Color.white)
                        .padding(.trailing, 16)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let newValue = Float(max(0.0, min(1.0, gesture.location.x / width)))
                        value = newValue
                        onEditingChanged?(newValue)
                    }
            )
        }
        .frame(height: 38)
    }
    
    private func dynamicIconName() -> String {
        if iconName.contains("sun") {
            return value < 0.33 ? "sun.min.fill" : "sun.max.fill"
        }
        if value <= 0.001 {
            return "speaker.slash.fill"
        } else if value < 0.33 {
            return "speaker.wave.1.fill"
        } else if value < 0.66 {
            return "speaker.wave.2.fill"
        } else {
            return "speaker.wave.3.fill"
        }
    }
}

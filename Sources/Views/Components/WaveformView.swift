import SwiftUI

public struct WaveformView: View {
    let isPlaying: Bool
    let color: Color
    let barCount: Int
    let maxHeight: CGFloat
    
    // Resting heights matching authentic Apple Music equalizer glyph
    private let restingHeights: [CGFloat] = [0.38, 0.75, 1.0, 0.6]
    // Distinct target heights for organic non-uniform audio spectrum feel
    private let targetHeights: [CGFloat] = [0.95, 0.35, 0.85, 0.45]
    // Non-harmonic cycle durations so bars never pulse in robotic lockstep
    private let cycleDurations: [Double] = [0.45, 0.34, 0.52, 0.39]
    private let delays: [Double] = [0.0, 0.08, 0.04, 0.12]
    
    @State private var animated: Bool = false
    
    public init(
        isPlaying: Bool,
        color: Color = .white,
        barCount: Int = 4,
        maxHeight: CGFloat = 15
    ) {
        self.isPlaying = isPlaying
        self.color = color
        self.barCount = barCount
        self.maxHeight = maxHeight
    }
    
    public var body: some View {
        HStack(alignment: .center, spacing: 2.8) {
            ForEach(0..<barCount, id: \.self) { index in
                Capsule()
                    .fill(color)
                    .frame(
                        width: 3.0,
                        height: currentHeight(for: index)
                    )
                    .animation(
                        isPlaying && animated
                            ? Animation.easeInOut(duration: cycleDurations[index % cycleDurations.count])
                                .repeatForever(autoreverses: true)
                                .delay(delays[index % delays.count])
                            : .easeOut(duration: 0.25),
                        value: animated
                    )
            }
        }
        .frame(height: maxHeight)
        .onAppear {
            if isPlaying {
                animated = true
            }
        }
        .onChange(of: isPlaying) { playing in
            animated = playing
        }
    }
    
    private func currentHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat
        if isPlaying && animated {
            baseHeight = targetHeights[index % targetHeights.count]
        } else {
            baseHeight = restingHeights[index % restingHeights.count]
        }
        return max(3.5, baseHeight * maxHeight)
    }
}

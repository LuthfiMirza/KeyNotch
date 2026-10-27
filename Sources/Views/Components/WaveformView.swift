import SwiftUI

public struct WaveformView: View {
    let isPlaying: Bool
    let color: Color
    let barCount: Int
    let maxHeight: CGFloat
    
    // Resting heights matching authentic audio glyph: [0.38, 0.75, 1.0, 0.6]
    @State private var barHeights: [CGFloat] = [0.38, 0.75, 1.0, 0.6]
    @State private var isAnimating: Bool = false
    
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
                        height: max(4.0, barHeights[index % barHeights.count] * maxHeight)
                    )
            }
        }
        .frame(height: maxHeight)
        .onAppear {
            if isPlaying {
                startAnimation()
            }
        }
        .onChange(of: isPlaying) { playing in
            if playing {
                startAnimation()
            } else {
                stopAnimation()
            }
        }
    }
    
    private func startAnimation() {
        guard !isAnimating else { return }
        isAnimating = true
        animateBars()
    }
    
    private func stopAnimation() {
        isAnimating = false
        withAnimation(.easeOut(duration: 0.3)) {
            barHeights = [0.38, 0.75, 1.0, 0.6]
        }
    }
    
    private func animateBars() {
        guard isAnimating && isPlaying else { return }
        
        withAnimation(.easeInOut(duration: 0.32)) {
            barHeights = (0..<barCount).map { _ in
                CGFloat.random(in: 0.25...1.0)
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.33) {
            if self.isAnimating && self.isPlaying {
                self.animateBars()
            }
        }
    }
}

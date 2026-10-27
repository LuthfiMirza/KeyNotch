import SwiftUI

public struct WaveformView: View {
    let isPlaying: Bool
    let color: Color
    let barCount: Int
    let maxHeight: CGFloat
    
    @State private var barHeights: [CGFloat] = [0.3, 0.7, 0.5, 0.9]
    @State private var isAnimating: Bool = false
    
    public init(
        isPlaying: Bool,
        color: Color = .green,
        barCount: Int = 4,
        maxHeight: CGFloat = 14
    ) {
        self.isPlaying = isPlaying
        self.color = color
        self.barCount = barCount
        self.maxHeight = maxHeight
    }
    
    public var body: some View {
        HStack(alignment: .center, spacing: 2.5) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(color)
                    .frame(
                        width: 2.5,
                        height: isPlaying ? max(3, barHeights[index % barHeights.count] * maxHeight) : 3
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
        withAnimation(.easeOut(duration: 0.25)) {
            barHeights = [0.2, 0.2, 0.2, 0.2]
        }
    }
    
    private func animateBars() {
        guard isAnimating && isPlaying else { return }
        
        withAnimation(.easeInOut(duration: 0.35)) {
            barHeights = (0..<barCount).map { _ in
                CGFloat.random(in: 0.25...1.0)
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) {
            if self.isAnimating && self.isPlaying {
                self.animateBars()
            }
        }
    }
}

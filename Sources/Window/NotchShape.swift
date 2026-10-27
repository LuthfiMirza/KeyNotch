import SwiftUI

public struct NotchShape: Shape {
    public var cornerRadius: CGFloat
    public var topShoulderRadius: CGFloat
    
    public init(cornerRadius: CGFloat = 20, topShoulderRadius: CGFloat = 8) {
        self.cornerRadius = cornerRadius
        self.topShoulderRadius = topShoulderRadius
    }
    
    public var animatableData: CGFloat {
        get { cornerRadius }
        set { cornerRadius = newValue }
    }
    
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        guard rect.width > 0 && rect.height > 0 else { return path }
        
        let w = rect.width
        let h = rect.height
        
        if h <= 6 {
            // Micro-lip state: sleek subtle lip pinned to top
            path.addRoundedRect(in: rect, cornerSize: CGSize(width: 2, height: 2))
            return path
        }
        
        let bottomRadius = min(cornerRadius, min(w / 2, h))
        let shoulder = min(topShoulderRadius, min(bottomRadius * 0.6, h * 0.25))
        
        // Start at top-left flush edge
        path.move(to: CGPoint(x: 0, y: 0))
        
        // Top edge: perfectly flat against the bezel (0px gap)
        path.addLine(to: CGPoint(x: w, y: 0))
        
        if shoulder > 1 && h > shoulder * 2 {
            // Right subtle shoulder curve
            path.addQuadCurve(
                to: CGPoint(x: w - shoulder, y: shoulder),
                control: CGPoint(x: w - shoulder * 0.3, y: 0)
            )
            
            // Right edge down
            path.addLine(to: CGPoint(x: w - shoulder, y: h - bottomRadius))
            
            // Bottom-right continuous squircle corner
            path.addQuadCurve(
                to: CGPoint(x: w - shoulder - bottomRadius, y: h),
                control: CGPoint(x: w - shoulder, y: h)
            )
            
            // Bottom edge
            path.addLine(to: CGPoint(x: shoulder + bottomRadius, y: h))
            
            // Bottom-left continuous squircle corner
            path.addQuadCurve(
                to: CGPoint(x: shoulder, y: h - bottomRadius),
                control: CGPoint(x: shoulder, y: h)
            )
            
            // Left edge up
            path.addLine(to: CGPoint(x: shoulder, y: shoulder))
            
            // Left subtle shoulder curve to flush edge
            path.addQuadCurve(
                to: CGPoint(x: 0, y: 0),
                control: CGPoint(x: shoulder * 0.3, y: 0)
            )
        } else {
            // Fallback for smaller heights
            path.addLine(to: CGPoint(x: w, y: h - bottomRadius))
            path.addQuadCurve(
                to: CGPoint(x: w - bottomRadius, y: h),
                control: CGPoint(x: w, y: h)
            )
            path.addLine(to: CGPoint(x: bottomRadius, y: h))
            path.addQuadCurve(
                to: CGPoint(x: 0, y: h - bottomRadius),
                control: CGPoint(x: 0, y: h)
            )
            path.addLine(to: CGPoint(x: 0, y: 0))
        }
        
        path.closeSubpath()
        return path
    }
}

import SwiftUI

public struct NotchShape: Shape {
    public var cornerRadius: CGFloat
    public var topShoulderRadius: CGFloat
    
    public init(
        cornerRadius: CGFloat = 18,
        topShoulderRadius: CGFloat = 7
    ) {
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
        let shoulder = min(topShoulderRadius, min(bottomRadius * 0.45, h * 0.22))
        let kCircle: CGFloat = 0.55228475
        
        // Start at top-left edge pinned flush to the screen bezel
        path.move(to: CGPoint(x: 0, y: 0))
        
        // Top edge: flat against bezel
        path.addLine(to: CGPoint(x: w, y: 0))
        
        if shoulder > 1 && h > shoulder * 2 {
            // MARK: - Right Top Concave Fillet (Cubic Bézier: 100% tangential, 0 kink)
            // Starts horizontal at (w, 0), curves smoothly to vertical wall at (w - shoulder, shoulder)
            path.addCurve(
                to: CGPoint(x: w - shoulder, y: shoulder),
                control1: CGPoint(x: w - shoulder * kCircle, y: 0),
                control2: CGPoint(x: w - shoulder, y: shoulder * (1.0 - kCircle))
            )
            
            // Right vertical straight wall
            path.addLine(to: CGPoint(x: w - shoulder, y: h - bottomRadius))
            
            // MARK: - Bottom-Right Continuous Squircle Corner
            // Starts vertical at (w - shoulder, h - bottomRadius), curves smoothly to horizontal at (w - shoulder - bottomRadius, h)
            path.addCurve(
                to: CGPoint(x: w - shoulder - bottomRadius, y: h),
                control1: CGPoint(x: w - shoulder, y: h - bottomRadius * (1.0 - kCircle)),
                control2: CGPoint(x: w - shoulder - bottomRadius * (1.0 - kCircle), y: h)
            )
            
            // Bottom horizontal line
            path.addLine(to: CGPoint(x: shoulder + bottomRadius, y: h))
            
            // MARK: - Bottom-Left Continuous Squircle Corner
            // Starts horizontal at (shoulder + bottomRadius, h), curves smoothly to vertical at (shoulder, h - bottomRadius)
            path.addCurve(
                to: CGPoint(x: shoulder, y: h - bottomRadius),
                control1: CGPoint(x: shoulder + bottomRadius * (1.0 - kCircle), y: h),
                control2: CGPoint(x: shoulder, y: h - bottomRadius * (1.0 - kCircle))
            )
            
            // Left vertical straight wall
            path.addLine(to: CGPoint(x: shoulder, y: shoulder))
            
            // MARK: - Left Top Concave Fillet (Cubic Bézier: 100% tangential, 0 kink)
            // Starts vertical at (shoulder, shoulder), curves smoothly to horizontal at (0, 0)
            path.addCurve(
                to: CGPoint(x: 0, y: 0),
                control1: CGPoint(x: shoulder, y: shoulder * (1.0 - kCircle)),
                control2: CGPoint(x: shoulder * kCircle, y: 0)
            )
        } else {
            // Fallback for compact states without shoulder
            path.addLine(to: CGPoint(x: w, y: h - bottomRadius))
            path.addCurve(
                to: CGPoint(x: w - bottomRadius, y: h),
                control1: CGPoint(x: w, y: h - bottomRadius * (1.0 - kCircle)),
                control2: CGPoint(x: w - bottomRadius * (1.0 - kCircle), y: h)
            )
            path.addLine(to: CGPoint(x: bottomRadius, y: h))
            path.addCurve(
                to: CGPoint(x: 0, y: h - bottomRadius),
                control1: CGPoint(x: bottomRadius * (1.0 - kCircle), y: h),
                control2: CGPoint(x: 0, y: h - bottomRadius * (1.0 - kCircle))
            )
            path.addLine(to: CGPoint(x: 0, y: 0))
        }
        
        path.closeSubpath()
        return path
    }
}

import SwiftUI

public struct NotchShape: Shape {
    public var cornerRadius: CGFloat
    public var topShoulderRadius: CGFloat
    public var hasPhysicalNotch: Bool
    
    public init(
        cornerRadius: CGFloat = 18,
        topShoulderRadius: CGFloat = 8,
        hasPhysicalNotch: Bool = false
    ) {
        self.cornerRadius = cornerRadius
        self.topShoulderRadius = topShoulderRadius
        self.hasPhysicalNotch = hasPhysicalNotch
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
        let kCircle: CGFloat = 0.55228475
        
        if hasPhysicalNotch {
            // MARK: - Mode 1: True Apple MacBook Notch (Physical Notch Bezel)
            // Uses tangential Cubic Bézier curves so top shoulders meet side walls at 90° with 0 kink
            let shoulder = min(topShoulderRadius, min(bottomRadius * 0.5, h * 0.25))
            
            // Start at top-left flush edge
            path.move(to: CGPoint(x: 0, y: 0))
            
            // Top flat line
            path.addLine(to: CGPoint(x: w, y: 0))
            
            if shoulder > 1 && h > shoulder * 2 {
                // Right concave fillet (tangential: horizontal entry at top, vertical exit at wall)
                path.addCurve(
                    to: CGPoint(x: w - shoulder, y: shoulder),
                    control1: CGPoint(x: w - shoulder * (1.0 - kCircle), y: 0),
                    control2: CGPoint(x: w - shoulder, y: shoulder * (1.0 - kCircle))
                )
                
                // Right straight vertical wall
                path.addLine(to: CGPoint(x: w - shoulder, y: h - bottomRadius))
                
                // Bottom-right continuous squircle corner
                path.addCurve(
                    to: CGPoint(x: w - shoulder - bottomRadius, y: h),
                    control1: CGPoint(x: w - shoulder, y: h - bottomRadius * (1.0 - kCircle)),
                    control2: CGPoint(x: w - shoulder - bottomRadius * (1.0 - kCircle), y: h)
                )
                
                // Bottom edge
                path.addLine(to: CGPoint(x: shoulder + bottomRadius, y: h))
                
                // Bottom-left continuous squircle corner
                path.addCurve(
                    to: CGPoint(x: shoulder, y: h - bottomRadius),
                    control1: CGPoint(x: shoulder + bottomRadius * (1.0 - kCircle), y: h),
                    control2: CGPoint(x: shoulder, y: h - bottomRadius * (1.0 - kCircle))
                )
                
                // Left straight vertical wall
                path.addLine(to: CGPoint(x: shoulder, y: shoulder))
                
                // Left concave fillet (tangential: vertical entry from wall, horizontal exit to top bezel)
                path.addCurve(
                    to: CGPoint(x: 0, y: 0),
                    control1: CGPoint(x: shoulder, y: shoulder * (1.0 - kCircle)),
                    control2: CGPoint(x: shoulder * (1.0 - kCircle), y: 0)
                )
            } else {
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
        } else {
            // MARK: - Mode 2: Non-Notched Display (Pure Apple Dynamic Island Pill)
            // No flared horns or flanges! Straight vertical walls with deep, butter-smooth Apple continuous squircle bottom corners.
            // Start at top-left flush against bezel
            path.move(to: CGPoint(x: 0, y: 0))
            
            // Top flat edge against screen top bezel (0px gap)
            path.addLine(to: CGPoint(x: w, y: 0))
            
            // Right straight vertical wall down to start of corner
            path.addLine(to: CGPoint(x: w, y: h - bottomRadius))
            
            // Bottom-right continuous squircle corner
            path.addCurve(
                to: CGPoint(x: w - bottomRadius, y: h),
                control1: CGPoint(x: w, y: h - bottomRadius * (1.0 - kCircle)),
                control2: CGPoint(x: w - bottomRadius * (1.0 - kCircle), y: h)
            )
            
            // Bottom horizontal line
            path.addLine(to: CGPoint(x: bottomRadius, y: h))
            
            // Bottom-left continuous squircle corner
            path.addCurve(
                to: CGPoint(x: 0, y: h - bottomRadius),
                control1: CGPoint(x: bottomRadius * (1.0 - kCircle), y: h),
                control2: CGPoint(x: 0, y: h - bottomRadius * (1.0 - kCircle))
            )
            
            // Left straight vertical wall back to top
            path.addLine(to: CGPoint(x: 0, y: 0))
        }
        
        path.closeSubpath()
        return path
    }
}

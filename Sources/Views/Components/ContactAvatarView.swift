import SwiftUI
import AppKit

public struct ContactAvatarView: View {
    let name: String
    let imagePath: String?
    let size: CGFloat
    let appBadge: String? // "whatsapp", "messages", "phone"
    
    public init(name: String, imagePath: String? = nil, size: CGFloat = 40, appBadge: String? = nil) {
        self.name = name
        self.imagePath = imagePath
        self.size = size
        self.appBadge = appBadge
    }
    
    // Curated Apple-style gradients based on hash
    private var avatarGradient: LinearGradient {
        let palettes: [[Color]] = [
            [Color(red: 0.28, green: 0.52, blue: 0.96), Color(red: 0.12, green: 0.32, blue: 0.78)], // Ocean Blue
            [Color(red: 0.94, green: 0.38, blue: 0.57), Color(red: 0.78, green: 0.18, blue: 0.38)], // Rose
            [Color(red: 0.35, green: 0.78, blue: 0.48), Color(red: 0.16, green: 0.56, blue: 0.30)], // Emerald
            [Color(red: 0.96, green: 0.58, blue: 0.22), Color(red: 0.82, green: 0.36, blue: 0.12)], // Sunset Orange
            [Color(red: 0.68, green: 0.38, blue: 0.96), Color(red: 0.46, green: 0.16, blue: 0.78)], // Purple
            [Color(red: 0.22, green: 0.76, blue: 0.88), Color(red: 0.10, green: 0.52, blue: 0.64)]  // Cyan
        ]
        let idx = abs(name.hashValue) % palettes.count
        return LinearGradient(colors: palettes[idx], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    
    private var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        } else if let first = parts.first, !first.isEmpty {
            return String(first.prefix(2)).uppercased()
        }
        return "WA"
    }
    
    private var loadedImage: NSImage? {
        guard let path = imagePath, !path.isEmpty else { return nil }
        if FileManager.default.fileExists(atPath: path) {
            return NSImage(contentsOfFile: path)
        }
        return nil
    }
    
    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Main Circular Avatar
            if let img = loadedImage {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
            } else {
                ZStack {
                    Circle()
                        .fill(avatarGradient)
                        .frame(width: size, height: size)
                    
                    Text(initials)
                        .font(.system(size: size * 0.40, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
            }
            
            // App Badge Overlay at bottom-right corner (e.g. WhatsApp, Messages)
            if let badge = appBadge {
                ZStack {
                    Circle()
                        .fill(badge == "whatsapp" ? Color(red: 0.15, green: 0.83, blue: 0.40) : (badge == "messages" ? Color(red: 0.22, green: 0.84, blue: 0.44) : Color.blue))
                        .frame(width: size * 0.42, height: size * 0.42)
                        .overlay(Circle().stroke(Color.black, lineWidth: 2))
                        .shadow(color: Color.black.opacity(0.35), radius: 2)
                    
                    Image(systemName: badge == "whatsapp" ? "phone.fill" : "message.fill")
                        .font(.system(size: size * 0.20, weight: .bold))
                        .foregroundColor(.white)
                }
                .offset(x: size * 0.08, y: size * 0.08)
            }
        }
    }
}

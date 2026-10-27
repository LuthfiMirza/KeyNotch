import SwiftUI
import UniformTypeIdentifiers

public struct StagedFile: Identifiable {
    public let id: UUID = UUID()
    public let url: URL
    public let name: String
    public let icon: NSImage
    public let isImage: Bool
    public let fileSizeString: String
    
    public init(url: URL) {
        self.url = url
        self.name = url.lastPathComponent
        self.icon = NSWorkspace.shared.icon(forFile: url.path)
        
        let ext = url.pathExtension.lowercased()
        self.isImage = ["png", "jpg", "jpeg", "webp", "heic", "tiff", "gif", "bmp"].contains(ext)
        
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int64 {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useKB, .useMB]
            formatter.countStyle = .file
            self.fileSizeString = formatter.string(fromByteCount: size)
        } else {
            self.fileSizeString = "--"
        }
    }
}

public struct ShelfClipboardTabView: View {
    @ObservedObject var clipboard = ClipboardService.shared
    @State private var subTab: Int = 0 // 0 = Files Shelf, 1 = Clipboard
    @State private var stagedFiles: [StagedFile] = []
    @State private var isTargeted: Bool = false
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 8) {
            // Sub-Tab Switcher
            HStack(spacing: 6) {
                // Files Shelf Tab
                Button(action: { subTab = 0 }) {
                    HStack(spacing: 5) {
                        Image(systemName: "square.and.arrow.down.on.square")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Files Shelf")
                            .font(.system(size: 11, weight: .semibold))
                        if !stagedFiles.isEmpty {
                            Text("\(stagedFiles.count)")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.blue)
                                .clipShape(Capsule())
                        }
                    }
                    .foregroundColor(subTab == 0 ? .white : .white.opacity(0.5))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(subTab == 0 ? Color.white.opacity(0.12) : Color.clear)
                    .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
                
                // Clipboard History Tab
                Button(action: { subTab = 1 }) {
                    HStack(spacing: 5) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Clipboard")
                            .font(.system(size: 11, weight: .semibold))
                        if !clipboard.history.isEmpty {
                            Text("\(clipboard.history.count)")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.yellow.opacity(0.8))
                                .foregroundColor(.black)
                                .clipShape(Capsule())
                        }
                    }
                    .foregroundColor(subTab == 1 ? .white : .white.opacity(0.5))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(subTab == 1 ? Color.white.opacity(0.12) : Color.clear)
                    .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                if subTab == 0 && !stagedFiles.isEmpty {
                    Button(action: { stagedFiles.removeAll() }) {
                        Text("Clear All")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .buttonStyle(PlainButtonStyle())
                } else if subTab == 1 && !clipboard.history.isEmpty {
                    Button(action: { clipboard.clearHistory() }) {
                        Text("Clear")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 14)
            
            // Content
            if subTab == 0 {
                filesShelfView
            } else {
                clipboardHistoryView
            }
        }
    }
    
    // MARK: - Files Shelf View
    
    private var filesShelfView: some View {
        VStack(spacing: 6) {
            if stagedFiles.isEmpty {
                // Drop Target Area
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            isTargeted ? Color.blue : Color.white.opacity(0.2),
                            style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                        )
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(isTargeted ? Color.blue.opacity(0.1) : Color.white.opacity(0.04))
                        )
                    
                    VStack(spacing: 5) {
                        Image(systemName: "arrow.down.doc.fill")
                            .font(.system(size: 24))
                            .foregroundColor(isTargeted ? .blue : .white.opacity(0.6))
                        
                        Text("Drag & drop files from Desktop or Finder")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                        
                        Text("Instant staging area • Drag out anywhere • Image Convert & OCR")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.45))
                    }
                    .padding(12)
                }
                .frame(height: 125)
                .padding(.horizontal, 14)
                .onDrop(of: ["public.file-url"], isTargeted: $isTargeted) { providers in
                    handleDrop(providers)
                }
            } else {
                // List of Staged Files
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 6) {
                        ForEach(stagedFiles) { file in
                            stagedFileRow(file)
                        }
                    }
                    .padding(.horizontal, 14)
                }
                .frame(height: 130)
                .onDrop(of: ["public.file-url"], isTargeted: $isTargeted) { providers in
                    handleDrop(providers)
                }
            }
        }
    }
    
    private func stagedFileRow(_ file: StagedFile) -> some View {
        HStack(spacing: 10) {
            // macOS File Icon
            Image(nsImage: file.icon)
                .resizable()
                .frame(width: 28, height: 28)
            
            // Name & Size
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(file.fileSizeString)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
            
            // Quick Actions for Images
            if file.isImage {
                HStack(spacing: 5) {
                    // Compress JPG
                    Button(action: {
                        FileConverterService.shared.convertImage(url: file.url, to: .jpg(quality: 0.75)) { newUrl in
                            if let newUrl = newUrl {
                                stagedFiles.append(StagedFile(url: newUrl))
                            }
                        }
                    }) {
                        Text("Compress")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.orange.opacity(0.3))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // To PNG
                    Button(action: {
                        FileConverterService.shared.convertImage(url: file.url, to: .png) { newUrl in
                            if let newUrl = newUrl {
                                stagedFiles.append(StagedFile(url: newUrl))
                            }
                        }
                    }) {
                        Text("To PNG")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.blue.opacity(0.3))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Quick OCR
                    Button(action: {
                        FileConverterService.shared.performOCR(on: file.url) { _ in }
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "text.viewfinder")
                                .font(.system(size: 9))
                            Text("OCR")
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.3))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            // Remove Button
            Button(action: {
                stagedFiles.removeAll { $0.id == file.id }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        // Enables dragging file back out to any application
        .onDrag {
            NSItemProvider(contentsOf: file.url) ?? NSItemProvider()
        }
    }
    
    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { (urlData, error) in
                guard let data = urlData as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else {
                    if let url = urlData as? URL {
                        DispatchQueue.main.async {
                            self.stagedFiles.append(StagedFile(url: url))
                        }
                    }
                    return
                }
                DispatchQueue.main.async {
                    self.stagedFiles.append(StagedFile(url: url))
                }
            }
        }
        return true
    }
    
    // MARK: - Clipboard History View
    
    private var clipboardHistoryView: some View {
        VStack(spacing: 6) {
            if clipboard.history.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.3))
                    Text("No clipboard snippets yet")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(height: 125)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 5) {
                        ForEach(clipboard.history) { item in
                            clipboardRow(item)
                        }
                    }
                    .padding(.horizontal, 14)
                }
                .frame(height: 130)
            }
        }
    }
    
    private func clipboardRow(_ item: ClipboardItem) -> some View {
        HStack(spacing: 8) {
            // Color Swatch if HEX code
            if item.isHexColor, let hex = item.colorHex {
                Circle()
                    .fill(Color(hex: hex))
                    .frame(width: 16, height: 16)
                    .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
            } else {
                Image(systemName: "text.quote")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }
            
            Text(item.content)
                .font(.system(size: 11, design: item.isHexColor ? .monospaced : .default))
                .foregroundColor(.white)
                .lineLimit(1)
            
            Spacer()
            
            // 1-Click Copy with Checkmark Feedback
            Button(action: {
                clipboard.copyToPasteboard(item)
            }) {
                HStack(spacing: 4) {
                    if clipboard.recentlyCopiedId == item.id {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.green)
                        Text("Copied")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

// MARK: - Color Hex Initializer Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 128, 128, 128)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

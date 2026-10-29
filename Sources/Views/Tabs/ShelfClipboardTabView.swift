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
    @ObservedObject var transfer = DownloadTransferService.shared
    @State private var subTab: Int = 0 // 0 = Files Shelf, 1 = Clipboard History, 2 = Sequential Paste Queue
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
                    .padding(.horizontal, 9)
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
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(subTab == 1 ? Color.white.opacity(0.12) : Color.clear)
                    .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
                
                // Sequential Paste Queue Tab
                Button(action: { subTab = 2 }) {
                    HStack(spacing: 5) {
                        Image(systemName: "square.stack.3d.down.right.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Paste Queue")
                            .font(.system(size: 11, weight: .semibold))
                        if !clipboard.pasteQueue.isEmpty {
                            Text("\(clipboard.pasteQueue.count)")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.green)
                                .foregroundColor(.black)
                                .clipShape(Capsule())
                        }
                    }
                    .foregroundColor(subTab == 2 ? .white : .white.opacity(0.5))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(subTab == 2 ? Color.white.opacity(0.12) : Color.clear)
                    .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                // Context Actions
                if subTab == 0 {
                    HStack(spacing: 8) {
                        Button(action: {
                            transfer.toggleDemoTransfer()
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: transfer.isSimulatingDemo ? "stop.circle.fill" : "arrow.down.circle")
                                    .font(.system(size: 9, weight: .bold))
                                Text(transfer.isSimulatingDemo ? "Stop Demo" : "Simulate DL")
                                    .font(.system(size: 9, weight: .medium))
                            }
                            .foregroundColor(transfer.isSimulatingDemo ? .orange : Color.cyan)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(transfer.isSimulatingDemo ? Color.orange.opacity(0.18) : Color.cyan.opacity(0.12))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if !stagedFiles.isEmpty {
                            Button(action: { stagedFiles.removeAll() }) {
                                Text("Clear All")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                } else if subTab == 1 {
                    HStack(spacing: 8) {
                        // Plain-Text Sanitizer Toggle
                        Button(action: {
                            clipboard.toggleAutoCleanPlainText()
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: clipboard.autoCleanPlainText ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(clipboard.autoCleanPlainText ? .green : .white.opacity(0.4))
                                Text("Clean Text")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(clipboard.autoCleanPlainText ? .white : .white.opacity(0.5))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(clipboard.autoCleanPlainText ? Color.green.opacity(0.18) : Color.white.opacity(0.06))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if !clipboard.history.isEmpty {
                            Button(action: { clipboard.clearHistory() }) {
                                Text("Clear")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                } else if subTab == 2 {
                    HStack(spacing: 8) {
                        Button(action: {
                            clipboard.toggleAutoQueueMode()
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: clipboard.autoQueueMode ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(clipboard.autoQueueMode ? .green : .white.opacity(0.4))
                                Text("Auto-Queue")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(clipboard.autoQueueMode ? .white : .white.opacity(0.5))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(clipboard.autoQueueMode ? Color.green.opacity(0.18) : Color.white.opacity(0.06))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("When ON, every Cmd+C is automatically added into Sequential Paste Queue")
                        
                        if !clipboard.pasteQueue.isEmpty {
                            Button(action: { clipboard.clearQueue() }) {
                                Text("Clear Queue")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            
            // Content
            if subTab == 0 {
                filesShelfView
            } else if subTab == 1 {
                clipboardHistoryView
            } else {
                pasteQueueView
            }
        }
        .onAppear {
            clipboard.checkPasteboard()
        }
    }
    
    // MARK: - Files Shelf View
    
    private var filesShelfView: some View {
        VStack(spacing: 6) {
            // Live Transfer Card if active download exists
            if let primary = transfer.primaryTransfer {
                activeTransferCard(primary)
            }
            
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
                    
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.down.doc.fill")
                            .font(.system(size: transfer.primaryTransfer != nil ? 18 : 24))
                            .foregroundColor(isTargeted ? .blue : .white.opacity(0.6))
                        
                        Text("Drag & drop files from Desktop or Finder")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundColor(.white)
                        
                        Text("Instant staging area • Drag out anywhere • Image Convert & OCR")
                            .font(.system(size: 9.5))
                            .foregroundColor(.white.opacity(0.45))
                    }
                    .padding(8)
                }
                .frame(height: transfer.primaryTransfer != nil ? 75 : 125)
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
                .frame(height: transfer.primaryTransfer != nil ? 78 : 130)
                .onDrop(of: ["public.file-url"], isTargeted: $isTargeted) { providers in
                    handleDrop(providers)
                }
            }
        }
    }
    
    // MARK: - 📥 Active Transfer Card
    private func activeTransferCard(_ item: ActiveTransferItem) -> some View {
        HStack(spacing: 10) {
            // Circular Progress Ring & Icon
            ZStack {
                Circle()
                    .stroke(Color.cyan.opacity(0.2), lineWidth: 3)
                    .frame(width: 32, height: 32)
                
                Circle()
                    .trim(from: 0, to: CGFloat(item.progress))
                    .stroke(
                        Color.cyan,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 32, height: 32)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.5), value: item.progress)
                
                Image(systemName: item.isAirDrop ? "airdrop" : "arrow.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.cyan)
            }
            
            // File Details & Progress Bar
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(item.filename)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text("\(item.percentageString) · \(item.speedString)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.cyan)
                }
                
                // Linear Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 4)
                        
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.cyan, Color.blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(4, geo.size.width * CGFloat(item.progress)), height: 4)
                            .animation(.linear(duration: 0.5), value: item.progress)
                    }
                }
                .frame(height: 4)
                
                // Metadata
                HStack {
                    Text(item.sizeProgressString)
                        .font(.system(size: 9.5))
                        .foregroundColor(.white.opacity(0.55))
                    
                    Spacer()
                    
                    Text(item.timeRemainingString)
                        .font(.system(size: 9.5))
                        .foregroundColor(.white.opacity(0.55))
                }
            }
            
            // Finder Button
            Button(action: {
                transfer.revealInFinder(item)
            }) {
                Image(systemName: "folder")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.75))
                    .padding(6)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
            .help("Show in Finder")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 14)
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
                    Button(action: {
                        FileConverterService.shared.convertImage(url: file.url, to: .png) { _ in }
                    }) {
                        Text("PNG")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        FileConverterService.shared.convertImage(url: file.url, to: .jpg(quality: 0.8)) { _ in }
                    }) {
                        Text("JPG")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        FileConverterService.shared.performOCR(on: file.url) { _ in }
                    }) {
                        Image(systemName: "text.viewfinder")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Color.purple.opacity(0.3))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            // Remove Button
            Button(action: {
                withAnimation {
                    stagedFiles.removeAll { $0.id == file.id }
                }
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
                        .foregroundColor(.yellow.opacity(0.6))
                    Text("No clipboard snippets yet")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Copy any text in any app (⌘C or right-click).\nKeyNotch automatically records it here!")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.45))
                        .multilineTextAlignment(.center)
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
            
            // Add to Sequential Paste Queue
            Button(action: {
                clipboard.addToQueue(item)
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .bold))
                    Text("Queue")
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 7)
                .padding(.vertical, 3.5)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
            }
            .buttonStyle(PlainButtonStyle())
            
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
    
    // MARK: - Sequential Paste Queue View
    
    private var pasteQueueView: some View {
        VStack(spacing: 6) {
            if clipboard.pasteQueue.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "square.stack.3d.down.right")
                        .font(.system(size: 24))
                        .foregroundColor(.green.opacity(0.6))
                    Text("Sequential Paste Queue is empty")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Click '+ Queue' on any snippet or turn on 'Auto-Queue'.\nThen press ⌥⇧V anywhere to paste each item in order.")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.45))
                        .multilineTextAlignment(.center)
                }
                .padding(12)
                .frame(height: 125)
            } else {
                VStack(spacing: 6) {
                    // Quick Action: Paste Next
                    HStack {
                        Button(action: {
                            clipboard.popNextInQueue()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 10, weight: .bold))
                                Text("Paste Next Snippet")
                                    .font(.system(size: 11, weight: .bold))
                                Text("(⌥⇧V)")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(.black.opacity(0.6))
                            }
                            .foregroundColor(.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Color.green)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Spacer()
                        
                        Text("\(clipboard.pasteQueue.count) items ready")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.horizontal, 14)
                    
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 5) {
                            ForEach(Array(clipboard.pasteQueue.enumerated()), id: \.element.id) { index, item in
                                HStack(spacing: 8) {
                                    Text("#\(index + 1)")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundColor(index == 0 ? .green : .white.opacity(0.4))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(index == 0 ? Color.green.opacity(0.2) : Color.white.opacity(0.06))
                                        .clipShape(Capsule())
                                    
                                    Text(item.content)
                                        .font(.system(size: 11))
                                        .foregroundColor(index == 0 ? .white : .white.opacity(0.7))
                                        .lineLimit(1)
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        clipboard.removeFromQueue(at: index)
                                    }) {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(.white.opacity(0.35))
                                            .frame(width: 18, height: 18)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(index == 0 ? Color.green.opacity(0.08) : Color.white.opacity(0.04))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                        }
                        .padding(.horizontal, 14)
                    }
                    .frame(height: 98)
                }
            }
        }
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
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

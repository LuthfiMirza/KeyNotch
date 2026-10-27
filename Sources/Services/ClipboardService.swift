import Cocoa
import SwiftUI
import Combine

public struct ClipboardItem: Identifiable, Equatable {
    public let id: UUID = UUID()
    public let content: String
    public let timestamp: Date
    public let isHexColor: Bool
    public let colorHex: String?
    
    public init(content: String, timestamp: Date = Date()) {
        self.content = content
        self.timestamp = timestamp
        
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if ClipboardItem.isValidHex(trimmed) {
            self.isHexColor = true
            self.colorHex = trimmed
        } else {
            self.isHexColor = false
            self.colorHex = nil
        }
    }
    
    private static func isValidHex(_ str: String) -> Bool {
        let pattern = "^#?([0-9A-Fa-f]{6}|[0-9A-Fa-f]{3}|[0-9A-Fa-f]{8})$"
        return str.range(of: pattern, options: .regularExpression) != nil
    }
    
    public static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        lhs.id == rhs.id
    }
}

public final class ClipboardService: ObservableObject {
    public static let shared = ClipboardService()
    
    @Published public var history: [ClipboardItem] = []
    @Published public var pasteQueue: [ClipboardItem] = []
    @Published public var recentlyCopiedId: UUID? = nil
    
    @Published public var autoCleanPlainText: Bool {
        didSet {
            UserDefaults.standard.set(autoCleanPlainText, forKey: "autoCleanPlainText")
        }
    }
    
    private var lastChangeCount: Int = 0
    private var keyMonitor: Any?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        if UserDefaults.standard.object(forKey: "autoCleanPlainText") == nil {
            self.autoCleanPlainText = true // Default ON for pure clean text experience
        } else {
            self.autoCleanPlainText = UserDefaults.standard.bool(forKey: "autoCleanPlainText")
        }
        
        self.lastChangeCount = NSPasteboard.general.changeCount
        checkPasteboard()
        setupEventDrivenCopyMonitor()
    }
    
    /// Zero-polling event monitor: captures Cmd+C and Cmd+X to evaluate pasteboard only on user action
    private func setupEventDrivenCopyMonitor() {
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard event.modifierFlags.contains(.command) else { return }
            guard let char = event.charactersIgnoringModifiers?.lowercased() else { return }
            
            if char == "c" || char == "x" {
                // Delay slightly (100ms) for the source application to write to pasteboard
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self?.checkPasteboard()
                }
            }
        }
    }
    
    public func toggleAutoCleanPlainText() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            autoCleanPlainText.toggle()
        }
        
        IslandState.shared.triggerHUD(
            HUDPayload(
                type: .custom,
                title: autoCleanPlainText ? "Plain-Text Cleaner ON" : "Plain-Text Cleaner OFF",
                subtitle: autoCleanPlainText ? "Formatting automatically stripped" : "Preserving rich text & styling",
                iconName: autoCleanPlainText ? "text.badge.checkmark" : "text.alignleft",
                isSuccess: autoCleanPlainText
            ),
            duration: 1.2
        )
    }
    
    public func checkPasteboard() {
        let pasteboard = NSPasteboard.general
        let currentCount = pasteboard.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount
        
        guard let text = pasteboard.string(forType: .string), !text.isEmpty else {
            return
        }
        
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // Auto-sanitize rich text formatting if enabled
        if autoCleanPlainText {
            sanitizePasteboardToPlainText(trimmed)
        }
        
        // Avoid immediate duplicate of top history item
        if let first = history.first, first.content == trimmed {
            return
        }
        
        DispatchQueue.main.async {
            let item = ClipboardItem(content: trimmed)
            self.history.removeAll { $0.content == trimmed }
            self.history.insert(item, at: 0)
            if self.history.count > 20 {
                self.history = Array(self.history.prefix(20))
            }
        }
    }
    
    private func sanitizePasteboardToPlainText(_ cleanText: String) {
        let pasteboard = NSPasteboard.general
        let types = pasteboard.types ?? []
        let hasRichTypes = types.contains(where: {
            $0.rawValue.contains("rtf") || $0.rawValue.contains("html") || $0.rawValue.contains("rtfd")
        })
        
        if hasRichTypes {
            pasteboard.clearContents()
            pasteboard.setString(cleanText, forType: .string)
            self.lastChangeCount = pasteboard.changeCount
        }
    }
    
    public func copyToPasteboard(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.content, forType: .string)
        self.lastChangeCount = pasteboard.changeCount
        
        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
            self.recentlyCopiedId = item.id
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
            withAnimation(.easeOut(duration: 0.2)) {
                if self?.recentlyCopiedId == item.id {
                    self?.recentlyCopiedId = nil
                }
            }
        }
    }
    
    // MARK: - Sequential Paste Queue (Stack)
    
    public func addToQueue(_ item: ClipboardItem) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
            pasteQueue.append(item)
        }
        
        IslandState.shared.triggerHUD(
            HUDPayload(
                type: .custom,
                title: "Added to Paste Queue",
                subtitle: item.content,
                iconName: "square.stack.3d.down.right.fill",
                value: Float(pasteQueue.count),
                rightDetail: "#\(pasteQueue.count) in Queue"
            ),
            duration: 1.0
        )
    }
    
    public func removeFromQueue(at index: Int) {
        guard index < pasteQueue.count else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
            _ = pasteQueue.remove(at: index)
        }
    }
    
    public func clearQueue() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
            pasteQueue.removeAll()
        }
    }
    
    /// Pops the next item in the sequential queue and primes the system pasteboard for Cmd+V
    public func popNextInQueue() {
        guard !pasteQueue.isEmpty else {
            IslandState.shared.triggerHUD(
                HUDPayload(
                    type: .custom,
                    title: "Paste Queue Empty",
                    subtitle: "Add items in Shelf > Clipboard",
                    iconName: "tray",
                    isSuccess: false
                ),
                duration: 1.2
            )
            return
        }
        
        let nextItem = pasteQueue[0]
        withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
            _ = pasteQueue.removeFirst()
        }
        
        // Prime system pasteboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(nextItem.content, forType: .string)
        self.lastChangeCount = pasteboard.changeCount
        
        let remaining = pasteQueue.count
        IslandState.shared.triggerHUD(
            HUDPayload(
                type: .custom,
                title: "Primed for Paste (Cmd+V)",
                subtitle: nextItem.content,
                iconName: "doc.on.clipboard.fill",
                value: remaining > 0 ? Float(remaining) : 1.0,
                rightDetail: remaining > 0 ? "\(remaining) left" : "Done!",
                isSuccess: true
            ),
            duration: 1.4
        )
    }
    
    public func clearHistory() {
        withAnimation {
            history.removeAll()
        }
    }
    
    deinit {
        if let km = keyMonitor {
            NSEvent.removeMonitor(km)
        }
    }
}

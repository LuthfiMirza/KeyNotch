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
    @Published public var recentlyCopiedId: UUID? = nil
    
    private var lastChangeCount: Int = 0
    private var pollTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        self.lastChangeCount = NSPasteboard.general.changeCount
        checkPasteboard()
        
        // Polling only runs while the Island is expanded or active to guarantee 0% idle CPU
        IslandState.shared.$isExpanded
            .receive(on: RunLoop.main)
            .sink { [weak self] expanded in
                if expanded {
                    self?.startMonitoring()
                } else {
                    self?.stopMonitoring()
                }
            }
            .store(in: &cancellables)
    }
    
    public func startMonitoring() {
        checkPasteboard()
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.checkPasteboard()
        }
    }
    
    public func stopMonitoring() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
    
    public func checkPasteboard() {
        let currentCount = NSPasteboard.general.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount
        
        guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else {
            return
        }
        
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // Avoid duplicate of current top item
        if let first = history.first, first.content == trimmed {
            return
        }
        
        DispatchQueue.main.async {
            let item = ClipboardItem(content: trimmed)
            self.history.removeAll { $0.content == trimmed }
            self.history.insert(item, at: 0)
            if self.history.count > 15 {
                self.history = Array(self.history.prefix(15))
            }
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
    
    public func clearHistory() {
        withAnimation {
            history.removeAll()
        }
    }
}

import SwiftUI
import Combine

public enum IslandTab: String, CaseIterable, Identifiable {
    case controls = "Controls"
    case shelf = "Shelf"
    case notes = "Notes"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .controls: return "slider.horizontal.3"
        case .shelf: return "square.and.arrow.down.on.square"
        case .notes: return "checklist"
        }
    }
}

public enum HUDType {
    case volume
    case brightness
    case capsLock
    case battery
    case custom
}

public struct HUDPayload: Identifiable, Equatable {
    public let id: UUID = UUID()
    public let type: HUDType
    public let title: String
    public let subtitle: String?
    public let iconName: String
    public let value: Float? // 0.0 ... 1.0 (for sliders)
    public let isSuccess: Bool
    
    public init(
        type: HUDType,
        title: String,
        subtitle: String? = nil,
        iconName: String,
        value: Float? = nil,
        isSuccess: Bool = true
    ) {
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.iconName = iconName
        self.value = value
        self.isSuccess = isSuccess
    }
    
    public static func == (lhs: HUDPayload, rhs: HUDPayload) -> Bool {
        lhs.id == rhs.id
    }
}

public final class IslandState: ObservableObject {
    public static let shared = IslandState()
    
    // Core Display States
    @Published public var isExpanded: Bool = false
    @Published public var isHoverPeekMode: Bool {
        didSet {
            UserDefaults.standard.set(isHoverPeekMode, forKey: "isHoverPeekMode")
        }
    }
    @Published public var isPeeking: Bool = false
    @Published public var isHidden: Bool = false
    @Published public var selectedTab: IslandTab = .controls
    @Published public var activeHUD: HUDPayload? = nil
    
    // Notch Dimensions (Calculated or Dynamic)
    @Published public var notchWidth: CGFloat = 210
    @Published public var notchHeight: CGFloat = 32
    
    private var hudDismissTimer: AnyCancellable?
    
    private init() {
        self.isHoverPeekMode = UserDefaults.standard.bool(forKey: "isHoverPeekMode")
    }
    
    // MARK: - Actions
    
    public func toggleExpand() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
            isExpanded.toggle()
            if isExpanded {
                isPeeking = false
                activeHUD = nil
            }
        }
    }
    
    public func expand(tab: IslandTab? = nil) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
            if let tab = tab {
                selectedTab = tab
            }
            isExpanded = true
            isPeeking = false
            activeHUD = nil
        }
    }
    
    public func collapse() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
            isExpanded = false
            isPeeking = false
        }
    }
    
    public func setHoverPeekMode(_ enabled: Bool) {
        isHoverPeekMode = enabled
        if !enabled {
            isPeeking = false
        }
    }
    
    public func toggleHoverPeekMode() {
        setHoverPeekMode(!isHoverPeekMode)
    }
    
    public func toggleHidden() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
            isHidden.toggle()
            if isHidden {
                isExpanded = false
                isPeeking = false
            }
        }
    }
    
    public func triggerHUD(_ payload: HUDPayload, duration: TimeInterval = 1.4) {
        // Only show HUD if not already fully expanded
        guard !isExpanded else { return }
        
        hudDismissTimer?.cancel()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) {
            activeHUD = payload
        }
        
        hudDismissTimer = Just(())
            .delay(for: .seconds(duration), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                    self?.activeHUD = nil
                }
            }
    }
}

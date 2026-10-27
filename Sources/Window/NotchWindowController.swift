import Cocoa
import SwiftUI
import Combine

public final class NotchWindowController: NSObject {
    public static let shared = NotchWindowController()
    
    public private(set) var panel: NotchPanel?
    private var cancellables = Set<AnyCancellable>()
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var globalClickMonitor: Any?
    private var localClickMonitor: Any?
    
    // Maximum canvas bounds for the NSPanel so animations have space without window resizing
    private let maxPanelWidth: CGFloat = 560
    private let maxPanelHeight: CGFloat = 280
    
    public override init() {
        super.init()
    }
    
    public func setup() {
        let initialRect = calculateWindowFrame()
        let panel = NotchPanel(contentRect: initialRect)
        
        let hostingView = NSHostingView(rootView: NotchRootView())
        hostingView.frame = NSRect(x: 0, y: 0, width: maxPanelWidth, height: maxPanelHeight)
        hostingView.autoresizingMask = [.width, .height]
        
        panel.contentView = hostingView
        panel.setFrame(initialRect, display: true)
        panel.orderFrontRegardless()
        
        self.panel = panel
        
        setupScreenObserver()
        setupStateObservers()
        setupEventMonitors()
    }
    
    // MARK: - Frame & Position
    
    private func calculateWindowFrame() -> NSRect {
        guard let screen = NSScreen.main else {
            return NSRect(x: 100, y: 500, width: maxPanelWidth, height: maxPanelHeight)
        }
        
        let screenFrame = screen.frame
        let x = screenFrame.midX - (maxPanelWidth / 2)
        // Flush with top edge of screen: window top equals screen.frame.maxY
        let y = screenFrame.maxY - maxPanelHeight
        
        return NSRect(x: x, y: y, width: maxPanelWidth, height: maxPanelHeight)
    }
    
    public func recenter() {
        guard let panel = panel else { return }
        let newFrame = calculateWindowFrame()
        panel.setFrame(newFrame, display: true)
    }
    
    private func setupScreenObserver() {
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.recenter()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - State Observers
    
    private func setupStateObservers() {
        let state = IslandState.shared
        
        // Re-evaluate key window capability when tab changes to notes
        state.$selectedTab
            .combineLatest(state.$isExpanded)
            .receive(on: RunLoop.main)
            .sink { [weak self] tab, expanded in
                guard let self = self, let panel = self.panel else { return }
                if expanded && tab == .notes {
                    panel.makeKey()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Mouse Event Monitoring & Smart Pass-Through
    
    private func setupEventMonitors() {
        // Monitor global cursor movements
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged]
        ) { [weak self] event in
            self?.handleCursorLocation(NSEvent.mouseLocation, isDragging: event.type == .leftMouseDragged)
        }
        
        // Monitor local cursor movements
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged]
        ) { [weak self] event in
            self?.handleCursorLocation(NSEvent.mouseLocation, isDragging: event.type == .leftMouseDragged)
            return event
        }
        
        // Monitor clicks outside notch for auto-collapse
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            self?.handleOutsideClick(NSEvent.mouseLocation)
        }
        
        localClickMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            self?.handleOutsideClick(NSEvent.mouseLocation)
            return event
        }
    }
    
    private func activeNotchScreenRect() -> NSRect {
        guard let screen = NSScreen.main else { return .zero }
        let state = IslandState.shared
        
        if state.isHidden {
            return .zero
        }
        
        let width: CGFloat
        let height: CGFloat
        
        if state.isExpanded {
            width = 520
            height = 240
        } else if state.activeHUD != nil {
            width = 280
            height = 46
        } else if state.isHoverPeekMode {
            if state.isPeeking {
                width = 210
                height = 32
            } else {
                width = 180
                height = 6 // slight buffer for micro-lip
            }
        } else {
            width = 210
            height = 32
        }
        
        let x = screen.frame.midX - (width / 2)
        let y = screen.frame.maxY - height
        return NSRect(x: x, y: y, width: width, height: height)
    }
    
    private func handleCursorLocation(_ location: NSPoint, isDragging: Bool) {
        guard let panel = panel, let screen = NSScreen.main else { return }
        let state = IslandState.shared
        let activeRect = activeNotchScreenRect()
        
        let isInside = activeRect.contains(location)
        
        // Smart pass-through: If cursor is outside the visible shape, pass clicks to underlying windows
        if panel.ignoresMouseEvents == isInside {
            panel.ignoresMouseEvents = !isInside
        }
        
        // Hover Peek Detection
        if state.isHoverPeekMode && !state.isExpanded {
            let distanceFromTop = screen.frame.maxY - location.y
            let horizontalDistance = abs(location.x - screen.frame.midX)
            
            if distanceFromTop <= 4 && horizontalDistance <= (activeRect.width / 2 + 40) {
                if !state.isPeeking {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                        state.isPeeking = true
                    }
                }
            } else if state.isPeeking && distanceFromTop > (activeRect.height + 25) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                    state.isPeeking = false
                }
            }
        }
        
        // File Drag toward notch triggers Shelf Tab
        if isDragging {
            let distanceFromTop = screen.frame.maxY - location.y
            let horizontalDistance = abs(location.x - screen.frame.midX)
            
            if distanceFromTop <= 50 && horizontalDistance <= 150 {
                if !state.isExpanded {
                    state.expand(tab: .shelf)
                }
            }
        }
    }
    
    private func handleOutsideClick(_ location: NSPoint) {
        let state = IslandState.shared
        guard state.isExpanded else { return }
        
        let activeRect = activeNotchScreenRect()
        if !activeRect.contains(location) {
            state.collapse()
        }
    }
    
    deinit {
        if let g = globalMouseMonitor { NSEvent.removeMonitor(g) }
        if let l = localMouseMonitor { NSEvent.removeMonitor(l) }
        if let gc = globalClickMonitor { NSEvent.removeMonitor(gc) }
        if let lc = localClickMonitor { NSEvent.removeMonitor(lc) }
    }
}

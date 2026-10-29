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
    private var globalScrollMonitor: Any?
    private var localScrollMonitor: Any?
    private var localKeyMonitor: Any?
    
    // Trackpad Horizontal Discrete Snapping Buffer
    private var accumulatedScrollDeltaX: CGFloat = 0
    private var isScrollPagingLocked: Bool = false
    private var scrollLockResetTimer: Timer?
    
    // Maximum canvas bounds for the NSPanel so animations have space without window resizing
    private let maxPanelWidth: CGFloat = 740
    private let maxPanelHeight: CGFloat = 320
    
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
                    IslandState.shared.updateScreenMetrics()
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
            
        // Make panel key when WhatsApp Quick Reply HUD appears so user can type immediately
        state.$activeHUD
            .receive(on: RunLoop.main)
            .sink { [weak self] hud in
                guard let self = self, let panel = self.panel else { return }
                if hud?.type == .whatsapp {
                    panel.makeKey()
                }
            }
            .store(in: &cancellables)
            
        // True Zero-Draw: cut WindowServer compositing entirely when hidden / full-screen
        Publishers.CombineLatest4(
            state.$isHidden,
            state.$autoHideOnFullScreen,
            state.$isFullScreenAppActive,
            state.$isPeeking
        )
        .combineLatest(state.$isExpanded, state.$activeHUD)
        .receive(on: RunLoop.main)
        .sink { [weak self] combined, expanded, activeHUD in
            guard let self = self, let panel = self.panel else { return }
            let (isHidden, autoHideFS, isFS, isPeeking) = combined
            let shouldHide = isHidden || (autoHideFS && isFS && !isPeeking && !expanded && activeHUD == nil)
            
            if shouldHide {
                // Wait for spring slide-up animation to complete before removing from WindowServer compositing
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
                    if IslandState.shared.shouldHideForFullScreen || IslandState.shared.isHidden {
                        panel.orderOut(nil)
                    }
                }
            } else {
                // Immediately attach window to compositor before slide-down animation begins
                if !panel.isVisible {
                    panel.orderFrontRegardless()
                }
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
        
        // Monitor global scroll wheel for 2-finger horizontal trackpad swipe
        globalScrollMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.scrollWheel]
        ) { [weak self] event in
            self?.handleTrackpadScroll(event)
        }
        
        // Monitor local scroll wheel
        localScrollMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.scrollWheel]
        ) { [weak self] event in
            self?.handleTrackpadScroll(event)
            return event
        }
        
        // Monitor keyboard Left/Right Arrow keys when expanded
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown]
        ) { event in
            guard IslandState.shared.isExpanded else { return event }
            // Let Notes tab handle its own typing / cursor movements
            if IslandState.shared.selectedTab == .notes {
                return event
            }
            if event.keyCode == 123 { // Left Arrow
                IslandState.shared.selectPreviousTab()
                return nil
            } else if event.keyCode == 124 { // Right Arrow
                IslandState.shared.selectNextTab()
                return nil
            }
            return event
        }
    }
    
    // MARK: - Trackpad 2-Finger Horizontal Swipe (Per-Dot Discrete Paging)
    
    private func handleTrackpadScroll(_ event: NSEvent) {
        guard IslandState.shared.isExpanded else { return }
        
        let mouseLocation = NSEvent.mouseLocation
        guard activeNotchScreenRect().contains(mouseLocation) else { return }
        
        // Extract horizontal & vertical deltas
        let dx = event.hasPreciseScrollingDeltas ? event.scrollingDeltaX : (event.deltaX * 12)
        let dy = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : (event.deltaY * 12)
        
        // If user is scrolling vertically inside a list (Clipboard history or Reminders), do not switch tabs
        if abs(dy) > abs(dx) * 1.3 && abs(dy) > 3 {
            return
        }
        
        // Gesture ended or cancelled -> unlock immediately
        if event.phase == .ended || event.phase == .cancelled {
            accumulatedScrollDeltaX = 0
            isScrollPagingLocked = false
            scrollLockResetTimer?.invalidate()
            return
        }
        
        guard !isScrollPagingLocked else { return }
        
        accumulatedScrollDeltaX += dx
        let threshold: CGFloat = 16.0
        
        if accumulatedScrollDeltaX < -threshold {
            // Swiped left with 2 fingers -> Advance to next dot/tab
            IslandState.shared.selectNextTab()
            lockScrollPaging()
        } else if accumulatedScrollDeltaX > threshold {
            // Swiped right with 2 fingers -> Move back to previous dot/tab
            IslandState.shared.selectPreviousTab()
            lockScrollPaging()
        }
    }
    
    private func lockScrollPaging() {
        isScrollPagingLocked = true
        accumulatedScrollDeltaX = 0
        scrollLockResetTimer?.invalidate()
        // Lock for 0.35s to guarantee exactly 1-dot movement per swipe
        scrollLockResetTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: false) { [weak self] _ in
            self?.isScrollPagingLocked = false
        }
    }
    
    private func activeNotchScreenRect() -> NSRect {
        guard let screen = NSScreen.main else { return .zero }
        let state = IslandState.shared
        
        if state.isHidden || state.shouldHideForFullScreen {
            return .zero
        }
        
        let width: CGFloat
        let height: CGFloat
        
        if state.isExpanded {
            width = (state.selectedTab == .music && LyricsService.shared.isLyricsExpanded) ? 680 : 540
            height = 282
        } else if let hud = state.activeHUD {
            if hud.type == .battery {
                width = 370
                height = 52
            } else if hud.type == .bluetooth {
                width = 360
                height = 48
            } else if hud.type == .whatsapp {
                width = 420
                height = 96
            } else if hud.type == .incomingCall {
                width = 420
                height = 66
            } else {
                width = 280
                height = 46
            }
        } else if state.activeCall != nil {
            width = max(state.notchWidth + 40, 240)
            height = state.notchHeight
        } else if state.isHoverPeekMode {
            if state.isPeeking {
                width = state.notchWidth
                height = state.notchHeight
            } else {
                width = 180
                height = 6 // slight buffer for micro-lip
            }
        } else {
            width = state.notchWidth
            height = state.notchHeight
        }
        
        let x = screen.frame.midX - (width / 2)
        let y = screen.frame.maxY - height
        return NSRect(x: x, y: y, width: width, height: height)
    }
    
    private func handleCursorLocation(_ location: NSPoint, isDragging: Bool) {
        autoreleasepool {
            guard let panel = panel, let screen = NSScreen.main else { return }
            let state = IslandState.shared
            let activeRect = activeNotchScreenRect()
            
            let isInside = activeRect.contains(location)
            
            // Smart pass-through: If cursor is outside the visible shape, pass clicks to underlying windows
            if panel.ignoresMouseEvents == isInside {
                panel.ignoresMouseEvents = !isInside
            }
            
            // Hover Peek Detection (Hover Peek Mode or Full Screen Auto-Hide)
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
            } else if state.autoHideOnFullScreen && state.isFullScreenAppActive && !state.isExpanded && state.activeHUD == nil {
                let distanceFromTop = screen.frame.maxY - location.y
                let horizontalDistance = abs(location.x - screen.frame.midX)
                
                if distanceFromTop <= 8 && horizontalDistance <= 130 {
                    if !state.isPeeking {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                            state.isPeeking = true
                        }
                    }
                } else if state.isPeeking && (distanceFromTop > (state.notchHeight + 25) || horizontalDistance > 160) {
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

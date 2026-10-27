import Cocoa
import Combine
import SwiftUI

public final class FullScreenMonitorService: NSObject, ObservableObject {
    public static let shared = FullScreenMonitorService()
    
    @Published public var isFullScreen: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    private override init() {
        super.init()
    }
    
    public func startMonitoring() {
        // 1. Observe active space changes (virtual desktop swipe or full-screen enter/exit)
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.activeSpaceDidChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.evaluateFullScreenState()
            }
            .store(in: &cancellables)
            
        // 2. Observe frontmost application activation
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didActivateApplicationNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.evaluateFullScreenState()
            }
            .store(in: &cancellables)
            
        // 3. Observe display geometry / screen parameter changes
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.evaluateFullScreenState()
            }
            .store(in: &cancellables)
            
        // Initial evaluation
        evaluateFullScreenState()
    }
    
    public func evaluateFullScreenState() {
        guard let screen = NSScreen.main else { return }
        
        var isFS = false
        
        // Signal 1: Check if visibleFrame extends to the top of screen.frame
        // (In normal mode, Menu Bar occupies top ~24-36pt so visibleFrame.maxY < screen.frame.maxY.
        // In full screen, the Menu Bar is hidden, so visibleFrame.maxY == screen.frame.maxY).
        let menuBarHidden = (screen.visibleFrame.maxY >= screen.frame.maxY - 1)
        
        // Signal 2: Check frontmost application's on-screen window frames
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            // Avoid detecting KeyNotch itself
            if frontApp.bundleIdentifier != Bundle.main.bundleIdentifier {
                let pid = frontApp.processIdentifier
                if let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] {
                    for win in windowList {
                        guard let winPID = win[kCGWindowOwnerPID as String] as? pid_t, winPID == pid else { continue }
                        guard let boundsDict = win[kCGWindowBounds as String] as? [String: Any],
                              let w = boundsDict["Width"] as? CGFloat,
                              let h = boundsDict["Height"] as? CGFloat else { continue }
                        
                        // Check if the front window covers the entire screen (within 4px tolerance)
                        if w >= screen.frame.width - 4 && h >= screen.frame.height - 4 {
                            isFS = true
                            break
                        }
                    }
                }
            }
        }
        
        // If front window covers full screen OR (menu bar is hidden and frontmost app is not Finder)
        if isFS || (menuBarHidden && isFrontAppFullScreenWindow(screen: screen)) {
            setFullScreenState(true)
        } else {
            setFullScreenState(false)
        }
    }
    
    private func isFrontAppFullScreenWindow(screen: NSScreen) -> Bool {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return false }
        if frontApp.bundleIdentifier == "com.apple.finder" {
            return false
        }
        return true
    }
    
    private func setFullScreenState(_ active: Bool) {
        guard isFullScreen != active else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isFullScreen = active
            withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                IslandState.shared.isFullScreenAppActive = active
            }
        }
    }
}

import Cocoa
import Combine
import SwiftUI

public final class FullScreenMonitorService: NSObject, ObservableObject {
    public static let shared = FullScreenMonitorService()
    
    @Published public var isFullScreen: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    // Dynamic SkyLight C Function Signatures (for 0% CPU native Space detection)
    private typealias CGSMainConnFunc = @convention(c) () -> Int32
    private typealias CGSCopySpacesFunc = @convention(c) (Int32) -> Unmanaged<CFArray>?
    
    private var getConn: CGSMainConnFunc?
    private var getSpaces: CGSCopySpacesFunc?
    private var skyLightHandle: UnsafeMutableRawPointer?
    
    private override init() {
        super.init()
        loadSkyLight()
    }
    
    private func loadSkyLight() {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW) else {
            return
        }
        self.skyLightHandle = handle
        
        if let connSym = dlsym(handle, "CGSMainConnectionID") {
            getConn = unsafeBitCast(connSym, to: CGSMainConnFunc.self)
        }
        if let spacesSym = dlsym(handle, "CGSCopyManagedDisplaySpaces") {
            getSpaces = unsafeBitCast(spacesSym, to: CGSCopySpacesFunc.self)
        }
    }
    
    public func startMonitoring() {
        // 1. Observe active space changes (virtual desktop swipe or full-screen enter/exit)
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.activeSpaceDidChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.evaluateFullScreenState()
                // Also evaluate after transition animation finishes (~200ms - 400ms)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self?.evaluateFullScreenState()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    self?.evaluateFullScreenState()
                }
            }
            .store(in: &cancellables)
            
        // 2. Observe frontmost application activation
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didActivateApplicationNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.evaluateFullScreenState()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    self?.evaluateFullScreenState()
                }
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
        
        // Signal 1: Native macOS Space Type via SkyLight
        // In macOS Mission Control / SkyLight, type 4 is ALWAYS a dedicated Full Screen Space
        if isCurrentSpaceFullScreen() {
            setFullScreenState(true)
            return
        }
        
        // Signal 2: Frontmost application window bounding box union
        // Handles multi-subwindow architectures like Google Chrome, which splits full-screen UI
        // into tab strip (top), toolbar, and web content instead of a single tall window.
        if isFrontAppCoveringScreen(screen: screen) {
            setFullScreenState(true)
            return
        }
        
        setFullScreenState(false)
    }
    
    private func isCurrentSpaceFullScreen() -> Bool {
        guard let getConn = getConn, let getSpaces = getSpaces else { return false }
        let cid = getConn()
        guard let displays = getSpaces(cid)?.takeRetainedValue() as? [[String: Any]] else { return false }
        
        for display in displays {
            if let currentSpace = display["Current Space"] as? [String: Any],
               let spaceType = currentSpace["type"] as? Int {
                // Type 4 is macOS native FullScreen Space (Type 0 is standard desktop)
                if spaceType == 4 {
                    return true
                }
            }
        }
        return false
    }
    
    private func isFrontAppCoveringScreen(screen: NSScreen) -> Bool {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return false }
        if frontApp.bundleIdentifier == Bundle.main.bundleIdentifier || frontApp.bundleIdentifier == "com.apple.finder" {
            return false
        }
        
        let pid = frontApp.processIdentifier
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        
        var fullWidthRects: [CGRect] = []
        
        for win in windowList {
            guard let winPID = win[kCGWindowOwnerPID as String] as? pid_t, winPID == pid else { continue }
            guard let boundsDict = win[kCGWindowBounds as String] as? [String: Any],
                  let x = boundsDict["X"] as? CGFloat,
                  let y = boundsDict["Y"] as? CGFloat,
                  let w = boundsDict["Width"] as? CGFloat,
                  let h = boundsDict["Height"] as? CGFloat else { continue }
            
            // Collect all windows of the frontmost app that span the screen width
            if w >= screen.frame.width - 10 {
                fullWidthRects.append(CGRect(x: x, y: y, width: w, height: h))
            }
        }
        
        guard !fullWidthRects.isEmpty else { return false }
        
        // Calculate the aggregate vertical span from top to bottom
        let minY = fullWidthRects.map { $0.minY }.min() ?? 9999
        let maxY = fullWidthRects.map { $0.maxY }.max() ?? -9999
        let totalSpan = maxY - minY
        
        // Full screen check: starts at top edge (minY <= 4) and spans the entire screen height
        if minY <= 4 && totalSpan >= screen.frame.height - 20 {
            return true
        }
        
        return false
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
    
    deinit {
        if let handle = skyLightHandle {
            dlclose(handle)
        }
    }
}

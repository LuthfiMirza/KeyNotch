import Cocoa
import SwiftUI

public final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize Core Window Engine
        NotchWindowController.shared.setup()
        
        // Initialize Global Carbon HotKey (Option + Space)
        HotKeyService.shared.register()
        
        // Initialize Background Telemetry & Interceptor Services
        HUDInterceptorService.shared.startMonitoring()
        BatteryService.shared.updateBatteryState(isInitial: true)
        MediaRemoteService.shared.refreshNowPlaying()
        
        // Setup Menu Bar Tray Icon
        setupStatusItem()
    }
    
    // MARK: - Menu Bar Setup
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        guard let button = statusItem.button else { return }
        button.title = "🏝️"
        button.target = self
        button.action = #selector(statusItemAction(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }
    
    @objc private func statusItemAction(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            // Right-click: Open Context Menu
            let menu = makeContextMenu()
            menu.delegate = self
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
        } else {
            // Left-click: Toggle Dynamic Island
            IslandState.shared.toggleExpand()
        }
    }
    
    public func menuDidClose(_ menu: NSMenu) {
        // Reset menu property so left-clicks continue to trigger statusItemAction
        statusItem.menu = nil
    }
    
    private func makeContextMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        
        // Header info
        let titleItem = NSMenuItem(title: "KeyNotch Dynamic Island", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(NSMenuItem.separator())
        
        // Toggle Expand
        let toggleItem = NSMenuItem(
            title: IslandState.shared.isExpanded ? "Collapse Island" : "Expand Island",
            action: #selector(toggleIsland),
            keyEquivalent: " "
        )
        toggleItem.keyEquivalentModifierMask = .option
        toggleItem.target = self
        menu.addItem(toggleItem)
        
        // Hover Peek Mode
        let peekItem = NSMenuItem(
            title: "Hover Peek Mode",
            action: #selector(toggleHoverPeekMode),
            keyEquivalent: ""
        )
        peekItem.target = self
        peekItem.state = IslandState.shared.isHoverPeekMode ? .on : .off
        menu.addItem(peekItem)
        
        // Caffeinate Toggle
        let caffItem = NSMenuItem(
            title: "Caffeinate (Prevent Sleep)",
            action: #selector(toggleCaffeinate),
            keyEquivalent: ""
        )
        caffItem.target = self
        caffItem.state = CaffeinateService.shared.isCaffeinated ? .on : .off
        menu.addItem(caffItem)
        
        // Hide / Show
        let hideItem = NSMenuItem(
            title: IslandState.shared.isHidden ? "Show Island" : "Hide Island",
            action: #selector(toggleHideIsland),
            keyEquivalent: ""
        )
        hideItem.target = self
        menu.addItem(hideItem)
        
        // Screen Color Picker
        let colorItem = NSMenuItem(
            title: "Pick Screen Color (Loupe)",
            action: #selector(pickScreenColor),
            keyEquivalent: "c"
        )
        colorItem.keyEquivalentModifierMask = [.option, .shift]
        colorItem.target = self
        menu.addItem(colorItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(
            title: "Quit KeyNotch",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
        
        return menu
    }
    
    @objc private func toggleIsland() {
        IslandState.shared.toggleExpand()
    }
    
    @objc private func toggleHoverPeekMode() {
        IslandState.shared.toggleHoverPeekMode()
    }
    
    @objc private func toggleCaffeinate() {
        CaffeinateService.shared.toggle()
    }
    
    @objc private func toggleHideIsland() {
        IslandState.shared.toggleHidden()
    }
    
    @objc private func triggerTestHUD() {
        IslandState.shared.triggerHUD(
            HUDPayload(
                type: .volume,
                title: "Output Volume",
                subtitle: nil,
                iconName: "speaker.wave.3.fill",
                value: 0.75
            )
        )
    }
    
    @objc private func pickScreenColor() {
        DevToolsService.shared.pickColor()
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    public func applicationWillTerminate(_ notification: Notification) {
        HotKeyService.shared.unregister()
        CaffeinateService.shared.cleanup()
    }
}

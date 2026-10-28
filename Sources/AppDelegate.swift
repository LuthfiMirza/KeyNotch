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
        BluetoothService.shared.startMonitoring()
        MicrophoneService.shared.startMonitoring()
        FullScreenMonitorService.shared.startMonitoring()
        MediaRemoteService.shared.refreshNowPlaying()
        _ = ClipboardService.shared
        _ = NetworkMonitorService.shared
        _ = MarketTickerService.shared
        _ = CalendarMeetingService.shared
        _ = DownloadTransferService.shared
        
        // Setup Menu Bar Tray Icon
        setupStatusItem()
        
        // Setup IPC Test Notifications
        setupIPCNotifications()
    }
    
    private func setupIPCNotifications() {
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.keynotch.triggerChargingHUD"),
            object: nil,
            queue: .main
        ) { _ in
            BatteryService.shared.triggerTestChargingHUD(percent: 70)
        }
        
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.keynotch.triggerBluetoothHUD"),
            object: nil,
            queue: .main
        ) { _ in
            BluetoothService.shared.triggerTestBluetoothHUD(name: "AirBuds Pro", battery: 70)
        }
        
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.keynotch.expandMusic"),
            object: nil,
            queue: .main
        ) { _ in
            IslandState.shared.selectedTab = .music
            if !IslandState.shared.isExpanded {
                IslandState.shared.expand()
            }
        }
        
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.keynotch.toggleLyrics"),
            object: nil,
            queue: .main
        ) { _ in
            IslandState.shared.selectedTab = .music
            if !IslandState.shared.isExpanded {
                IslandState.shared.expand()
            }
            LyricsService.shared.toggleLyrics()
        }
        
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.keynotch.refreshMedia"),
            object: nil,
            queue: .main
        ) { _ in
            MediaRemoteService.shared.refreshNowPlaying()
        }
        
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.keynotch.dumpMedia"),
            object: nil,
            queue: .main
        ) { _ in
            let m = MediaRemoteService.shared
            let l = LyricsService.shared
            let str = "Title: \(m.title)\nArtist: \(m.artist)\nisPlaying: \(m.isPlaying)\nduration: \(m.duration)\nelapsed: \(m.elapsedTime)\nhasMedia: \(m.hasActiveMedia)\nLyricsCount: \(l.lyrics.count)\nLyricsStatus: \(l.statusMessage ?? "none")"
            try? str.write(toFile: "/tmp/keynotch_media_debug.txt", atomically: true, encoding: .utf8)
        }
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
        
        // Auto-Hide in Full Screen
        let fsItem = NSMenuItem(
            title: "Auto-Hide in Full Screen",
            action: #selector(toggleAutoHideFullScreen),
            keyEquivalent: ""
        )
        fsItem.target = self
        fsItem.state = IslandState.shared.autoHideOnFullScreen ? .on : .off
        menu.addItem(fsItem)
        
        // Caffeinate Toggle
        let caffItem = NSMenuItem(
            title: "Caffeinate (Prevent Sleep)",
            action: #selector(toggleCaffeinate),
            keyEquivalent: ""
        )
        caffItem.target = self
        caffItem.state = CaffeinateService.shared.isCaffeinated ? .on : .off
        menu.addItem(caffItem)
        
        // Microphone Mute Toggle
        let micItem = NSMenuItem(
            title: MicrophoneService.shared.isMuted ? "Unmute Microphone" : "Mute Microphone",
            action: #selector(toggleMicMute),
            keyEquivalent: "m"
        )
        micItem.keyEquivalentModifierMask = [.option, .shift]
        micItem.target = self
        micItem.state = MicrophoneService.shared.isMuted ? .on : .off
        menu.addItem(micItem)
        
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
        
        // Plain-Text Sanitizer Toggle
        let cleanTextItem = NSMenuItem(
            title: "Clean Plain-Text Sanitizer",
            action: #selector(togglePlainTextCleaner),
            keyEquivalent: ""
        )
        cleanTextItem.target = self
        cleanTextItem.state = ClipboardService.shared.autoCleanPlainText ? .on : .off
        menu.addItem(cleanTextItem)
        
        // Paste Next from Sequential Queue
        let pasteQueueItem = NSMenuItem(
            title: "Paste Next Snippet (Queue)",
            action: #selector(pasteNextInQueue),
            keyEquivalent: "v"
        )
        pasteQueueItem.keyEquivalentModifierMask = [.option, .shift]
        pasteQueueItem.target = self
        menu.addItem(pasteQueueItem)
        
        // Network Speed in Compact Notch
        let netItem = NSMenuItem(
            title: "Network Speed in Notch",
            action: #selector(toggleNetworkSpeedInNotch),
            keyEquivalent: ""
        )
        netItem.target = self
        netItem.state = NetworkMonitorService.shared.showInCompactNotch ? .on : .off
        menu.addItem(netItem)
        
        // Market Ticker in Compact Notch
        let marketItem = NSMenuItem(
            title: "Market Ticker in Notch",
            action: #selector(toggleMarketTickerInNotch),
            keyEquivalent: ""
        )
        marketItem.target = self
        marketItem.state = MarketTickerService.shared.showTickerInCompactNotch ? .on : .off
        menu.addItem(marketItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // HUD Live Previews
        let testChargingItem = NSMenuItem(
            title: "⚡ Test Charging HUD (70%)",
            action: #selector(testChargingHUD),
            keyEquivalent: ""
        )
        testChargingItem.target = self
        menu.addItem(testChargingItem)
        
        let testBluetoothItem = NSMenuItem(
            title: "🎧 Test Bluetooth HUD (AirBuds Pro)",
            action: #selector(testBluetoothHUD),
            keyEquivalent: ""
        )
        testBluetoothItem.target = self
        menu.addItem(testBluetoothItem)
        
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
    
    @objc private func toggleAutoHideFullScreen() {
        IslandState.shared.toggleAutoHideFullScreen()
    }
    
    @objc private func toggleCaffeinate() {
        CaffeinateService.shared.toggle()
    }
    
    @objc private func toggleMicMute() {
        MicrophoneService.shared.toggleMute()
    }
    
    @objc private func togglePlainTextCleaner() {
        ClipboardService.shared.toggleAutoCleanPlainText()
    }
    
    @objc private func pasteNextInQueue() {
        ClipboardService.shared.popNextInQueue()
    }
    
    @objc private func toggleNetworkSpeedInNotch() {
        NetworkMonitorService.shared.toggleShowInCompactNotch()
    }
    
    @objc private func toggleMarketTickerInNotch() {
        MarketTickerService.shared.toggleShowTickerInNotch()
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
    
    @objc private func testChargingHUD() {
        BatteryService.shared.triggerTestChargingHUD(percent: 70)
    }
    
    @objc private func testBluetoothHUD() {
        BluetoothService.shared.triggerTestBluetoothHUD(name: "AirBuds Pro", battery: 70)
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

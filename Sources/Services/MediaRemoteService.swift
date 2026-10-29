import Cocoa
import Combine
import SwiftUI

public final class MediaRemoteService: ObservableObject {
    public static let shared = MediaRemoteService()
    
    // Published Media State
    @Published public var title: String = ""
    @Published public var artist: String = ""
    @Published public var album: String = ""
    @Published public var artwork: NSImage? = nil
    @Published public var ambientColor: Color = Color(red: 0.95, green: 0.22, blue: 0.38)
    @Published public var isPlaying: Bool = false
    @Published public var elapsedTime: Double = 0
    @Published public var duration: Double = 0
    @Published public var hasActiveMedia: Bool = false
    
    // Dynamic C Function Signatures
    private typealias MRRegisterFunction = @convention(c) (DispatchQueue) -> Void
    private typealias MRGetInfoFunction = @convention(c) (DispatchQueue, @escaping (CFDictionary?) -> Void) -> Void
    private typealias MRIsPlayingFunction = @convention(c) (DispatchQueue, @escaping (DarwinBoolean) -> Void) -> Void
    private typealias MRSendCommandFunction = @convention(c) (Int, CFDictionary?) -> DarwinBoolean
    private typealias MRSetElapsedFunction = @convention(c) (Double) -> Void
    
    private var mrGetInfo: MRGetInfoFunction?
    private var mrIsPlaying: MRIsPlayingFunction?
    private var mrSendCommand: MRSendCommandFunction?
    private var mrSetElapsedTime: MRSetElapsedFunction?
    private var handle: UnsafeMutableRawPointer?
    private var cancellables = Set<AnyCancellable>()
    
    // Helper Process (MediaBridge via /usr/bin/swift)
    private var bridgeProcess: Process?
    
    // Polling timer (active when expanded or playing)
    private var fallbackTimer: Timer?
    
    private init() {
        loadMediaRemote()
        startMediaBridgeIfNeeded()
        setupNotificationObservers()
        setupStateObservers()
        refreshNowPlaying()
    }
    
    // MARK: - MediaBridge Process Management
    
    private func startMediaBridgeIfNeeded() {
        guard bridgeProcess == nil || !bridgeProcess!.isRunning else { return }
        
        let bundlePath = Bundle.main.path(forResource: "MediaBridge", ofType: "swift")
        let localPath = "/Users/mac/KeyNotch/Resources/MediaBridge.swift"
        let scriptPath = (bundlePath != nil && FileManager.default.fileExists(atPath: bundlePath!)) ? bundlePath! : localPath
        
        guard FileManager.default.fileExists(atPath: scriptPath) else { return }
        
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        p.arguments = [scriptPath]
        p.standardOutput = Pipe()
        p.standardError = Pipe()
        try? p.run()
        bridgeProcess = p
    }
    
    private func loadMediaRemote() {
        handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW)
        guard let handle = handle else {
            NSLog("[KeyNotch MediaRemote] Unable to dlopen MediaRemote.framework")
            return
        }
        
        if let regSym = dlsym(handle, "MRMediaRemoteRegisterForNowPlayingNotifications") {
            let registerFunc = unsafeBitCast(regSym, to: MRRegisterFunction.self)
            registerFunc(DispatchQueue.main)
        }
        
        if let getInfoSym = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo") {
            mrGetInfo = unsafeBitCast(getInfoSym, to: MRGetInfoFunction.self)
        }
        
        if let isPlayingSym = dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationIsPlaying") {
            mrIsPlaying = unsafeBitCast(isPlayingSym, to: MRIsPlayingFunction.self)
        }
        
        if let sendCommandSym = dlsym(handle, "MRMediaRemoteSendCommand") {
            mrSendCommand = unsafeBitCast(sendCommandSym, to: MRSendCommandFunction.self)
        }
        
        if let setElapsedSym = dlsym(handle, "MRMediaRemoteSetElapsedTime") {
            mrSetElapsedTime = unsafeBitCast(setElapsedSym, to: MRSetElapsedFunction.self)
        }
    }
    
    private func setupStateObservers() {
        IslandState.shared.$isExpanded
            .receive(on: RunLoop.main)
            .sink { [weak self] expanded in
                guard let self = self else { return }
                if expanded {
                    self.startTimer()
                    self.refreshNowPlaying()
                } else if !self.isPlaying {
                    self.stopTimer()
                }
            }
            .store(in: &cancellables)
    }
    
    public func startTimer() {
        guard fallbackTimer == nil else { return }
        fallbackTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refreshNowPlaying()
        }
    }
    
    public func stopTimer() {
        fallbackTimer?.invalidate()
        fallbackTimer = nil
    }
    
    private func setupNotificationObservers() {
        let dnc = DistributedNotificationCenter.default()
        dnc.addObserver(
            self,
            selector: #selector(handleBridgeMediaUpdated),
            name: NSNotification.Name("com.keynotch.mediaUpdated"),
            object: nil
        )
        
        let nc = NotificationCenter.default
        nc.addObserver(
            self,
            selector: #selector(handleMediaChange),
            name: NSNotification.Name("kMRMediaRemoteNowPlayingInfoDidChangeNotification"),
            object: nil
        )
        nc.addObserver(
            self,
            selector: #selector(handleMediaChange),
            name: NSNotification.Name("kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification"),
            object: nil
        )
        nc.addObserver(
            self,
            selector: #selector(handleMediaChange),
            name: NSNotification.Name("kMRMediaRemoteNowPlayingApplicationDidChangeNotification"),
            object: nil
        )
    }
    
    @objc private func handleBridgeMediaUpdated() {
        readBridgePayload()
    }
    
    @objc private func handleMediaChange() {
        refreshNowPlaying()
    }
    
    public func refreshNowPlaying() {
        startMediaBridgeIfNeeded()
        readBridgePayload()
        
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name("com.keynotch.command.requestSync"),
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }
    
    private func readBridgePayload() {
        let jsonPath = "/tmp/keynotch_media.json"
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: jsonPath)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            fallbackAppleScriptCheck()
            return
        }
        
        let newTitle = json["title"] as? String ?? ""
        let newArtist = json["artist"] as? String ?? ""
        let newAlbum = json["album"] as? String ?? ""
        let newDuration = json["duration"] as? Double ?? 0
        let newElapsed = json["elapsedTime"] as? Double ?? 0
        let newIsPlaying = json["isPlaying"] as? Bool ?? false
        let artworkPath = json["artworkPath"] as? String ?? ""
        
        var newArtwork: NSImage? = nil
        if !artworkPath.isEmpty && FileManager.default.fileExists(atPath: artworkPath) {
            newArtwork = NSImage(contentsOfFile: artworkPath)
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let titleChanged = (self.title != newTitle || self.artist != newArtist)
            
            if !newTitle.isEmpty {
                self.title = newTitle
                self.artist = newArtist.isEmpty ? "Unknown Artist" : newArtist
                self.album = newAlbum
                self.duration = newDuration
                self.elapsedTime = newElapsed
                self.isPlaying = newIsPlaying
                self.hasActiveMedia = true
                if let newArtwork = newArtwork {
                    self.artwork = newArtwork
                    self.updateAmbientColor(from: newArtwork)
                }
                
                if newIsPlaying && self.fallbackTimer == nil {
                    self.startTimer()
                } else if !newIsPlaying && !IslandState.shared.isExpanded {
                    self.stopTimer()
                }
                
                if titleChanged {
                    LyricsService.shared.fetchLyrics(
                        title: newTitle,
                        artist: newArtist
                    )
                }
            } else {
                self.fallbackAppleScriptCheck()
            }
        }
    }
    
    // MARK: - AppleScript Fallback for Spotify & Music.app
    
    private func fallbackAppleScriptCheck() {
        let isSpotifyRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client").isEmpty
        let isMusicRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music").isEmpty
        
        if isSpotifyRunning {
            querySpotifyViaAppleScript()
        } else if isMusicRunning {
            queryMusicViaAppleScript()
        } else if title.isEmpty {
            hasActiveMedia = false
            isPlaying = false
        }
    }
    
    private func querySpotifyViaAppleScript() {
        let scriptText = """
        tell application "Spotify"
            if player state is playing then
                return (get name of current track) & "|||" & (get artist of current track) & "|||" & (get album of current track) & "|||" & (get duration of current track) & "|||" & (get player position) & "|||playing"
            else if player state is paused then
                return (get name of current track) & "|||" & (get artist of current track) & "|||" & (get album of current track) & "|||" & (get duration of current track) & "|||" & (get player position) & "|||paused"
            else
                return "|||||||||"
            end if
        end tell
        """
        runMediaScript(scriptText, defaultArtist: "Spotify")
    }
    
    private func queryMusicViaAppleScript() {
        let scriptText = """
        tell application "Music"
            if player state is playing then
                return (get name of current track) & "|||" & (get artist of current track) & "|||" & (get album of current track) & "|||" & (get duration of current track) & "|||" & (get player position) & "|||playing"
            else if player state is paused then
                return (get name of current track) & "|||" & (get artist of current track) & "|||" & (get album of current track) & "|||" & (get duration of current track) & "|||" & (get player position) & "|||paused"
            else
                return "|||||||||"
            end if
        end tell
        """
        runMediaScript(scriptText, defaultArtist: "Apple Music")
    }
    
    private func runMediaScript(_ scriptText: String, defaultArtist: String) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            var error: NSDictionary?
            if let script = NSAppleScript(source: scriptText),
               let result = script.executeAndReturnError(&error).stringValue,
               !result.isEmpty {
                let parts = result.components(separatedBy: "|||")
                if parts.count >= 6 {
                    let songTitle = parts[0]
                    let songArtist = parts[1].isEmpty ? defaultArtist : parts[1]
                    let songAlbum = parts[2]
                    let songDuration = (Double(parts[3]) ?? 0) / 1000.0
                    let songElapsed = Double(parts[4]) ?? 0
                    let songState = parts[5]
                    let playing = (songState == "playing")
                    
                    if !songTitle.isEmpty {
                        DispatchQueue.main.async {
                            let titleChanged = (self.title != songTitle || self.artist != songArtist)
                            self.title = songTitle
                            self.artist = songArtist
                            self.album = songAlbum
                            self.duration = songDuration
                            self.elapsedTime = songElapsed
                            self.isPlaying = playing
                            self.hasActiveMedia = true
                            
                            if playing && self.fallbackTimer == nil {
                                self.startTimer()
                            } else if !playing && !IslandState.shared.isExpanded {
                                self.stopTimer()
                            }
                            
                            if titleChanged {
                                LyricsService.shared.fetchLyrics(
                                    title: songTitle,
                                    artist: songArtist
                                )
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Native Playback Controls (MediaRemote + Bridge + AppleScript Fallback)
    
    public func togglePlayPause() {
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name("com.keynotch.command.playPause"),
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
        if let mrSendCommand = mrSendCommand {
            _ = mrSendCommand(2, nil) // 2 = TogglePlayPause
        } else {
            executeAppleScriptMediaCommand("playpause")
        }
        isPlaying.toggle()
    }
    
    public func play() {
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name("com.keynotch.command.playPause"),
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
        if let mrSendCommand = mrSendCommand {
            _ = mrSendCommand(0, nil) // 0 = Play
        } else {
            executeAppleScriptMediaCommand("play")
        }
        isPlaying = true
    }
    
    public func pause() {
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name("com.keynotch.command.playPause"),
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
        if let mrSendCommand = mrSendCommand {
            _ = mrSendCommand(1, nil) // 1 = Pause
        } else {
            executeAppleScriptMediaCommand("pause")
        }
        isPlaying = false
    }
    
    public func nextTrack() {
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name("com.keynotch.command.next"),
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
        if let mrSendCommand = mrSendCommand {
            _ = mrSendCommand(4, nil) // 4 = NextTrack
        } else {
            executeAppleScriptMediaCommand("next track")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.refreshNowPlaying()
        }
    }
    
    public func previousTrack() {
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name("com.keynotch.command.previous"),
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
        if let mrSendCommand = mrSendCommand {
            _ = mrSendCommand(5, nil) // 5 = PreviousTrack
        } else {
            executeAppleScriptMediaCommand("previous track")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.refreshNowPlaying()
        }
    }
    
    public func seek(to seconds: Double) {
        elapsedTime = seconds
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name("com.keynotch.command.seek"),
            object: nil,
            userInfo: ["seconds": "\(seconds)"],
            deliverImmediately: true
        )
        if let mrSetElapsedTime = mrSetElapsedTime {
            mrSetElapsedTime(seconds)
        }
        let isSpotifyRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client").isEmpty
        let isMusicRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music").isEmpty
        if isSpotifyRunning {
            let script = "tell application \"Spotify\" to set player position to \(seconds)"
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                NSAppleScript(source: script)?.executeAndReturnError(&error)
            }
        } else if isMusicRunning {
            let script = "tell application \"Music\" to set player position to \(seconds)"
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                NSAppleScript(source: script)?.executeAndReturnError(&error)
            }
        }
    }
    
    private func executeAppleScriptMediaCommand(_ command: String) {
        let isSpotifyRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client").isEmpty
        let target = isSpotifyRunning ? "Spotify" : "Music"
        let script = "tell application \"\(target)\" to \(command)"
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            NSAppleScript(source: script)?.executeAndReturnError(&error)
        }
    }
    
    // MARK: - Dynamic Ambient Color Extraction
    
    public func updateAmbientColor(from image: NSImage) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let color = Self.extractVibrantColor(from: image)
            DispatchQueue.main.async {
                withAnimation(.linear(duration: 0.6)) {
                    self?.ambientColor = color
                }
            }
        }
    }
    
    public static func extractVibrantColor(from image: NSImage) -> Color {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return Color(red: 0.95, green: 0.22, blue: 0.38)
        }
        let size = 10
        var pixels = [UInt8](repeating: 0, count: size * size * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let context = CGContext(
            data: &pixels,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: size * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return Color(red: 0.95, green: 0.22, blue: 0.38)
        }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: size, height: size))
        
        var bestColor = Color(red: 0.95, green: 0.22, blue: 0.38)
        var maxScore: Double = -1
        
        for i in 0..<(size * size) {
            let r = Double(pixels[i * 4]) / 255.0
            let g = Double(pixels[i * 4 + 1]) / 255.0
            let b = Double(pixels[i * 4 + 2]) / 255.0
            
            let maxVal = max(r, max(g, b))
            let minVal = min(r, min(g, b))
            let delta = maxVal - minVal
            let sat = maxVal == 0 ? 0 : delta / maxVal
            let brightness = maxVal
            
            // Prefer vibrant, saturated colors over muddy gray or pure black/white
            if brightness > 0.2 && brightness < 0.95 && sat > 0.25 {
                let score = sat * 0.7 + brightness * 0.3
                if score > maxScore {
                    maxScore = score
                    bestColor = Color(red: r, green: g, blue: b)
                }
            }
        }
        return bestColor
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
        bridgeProcess?.terminate()
        bridgeProcess = nil
        if let handle = handle {
            dlclose(handle)
        }
    }
}

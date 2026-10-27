import Cocoa
import Combine

public final class MediaRemoteService: ObservableObject {
    public static let shared = MediaRemoteService()
    
    // Published Media State
    @Published public var title: String = ""
    @Published public var artist: String = ""
    @Published public var album: String = ""
    @Published public var artwork: NSImage? = nil
    @Published public var isPlaying: Bool = false
    @Published public var elapsedTime: Double = 0
    @Published public var duration: Double = 0
    @Published public var hasActiveMedia: Bool = false
    
    // Dynamic C Function Signatures
    private typealias MRRegisterFunction = @convention(c) (DispatchQueue) -> Void
    private typealias MRGetInfoFunction = @convention(c) (DispatchQueue, @escaping (CFDictionary?) -> Void) -> Void
    private typealias MRIsPlayingFunction = @convention(c) (DispatchQueue, @escaping (DarwinBoolean) -> Void) -> Void
    private typealias MRSendCommandFunction = @convention(c) (Int, CFDictionary?) -> DarwinBoolean
    
    private var mrGetInfo: MRGetInfoFunction?
    private var mrIsPlaying: MRIsPlayingFunction?
    private var mrSendCommand: MRSendCommandFunction?
    private var handle: UnsafeMutableRawPointer?
    
    // Polling fallback timer (only active when expanded or playing)
    private var fallbackTimer: Timer?
    
    private init() {
        loadMediaRemote()
        setupNotificationObservers()
        refreshNowPlaying()
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
    }
    
    private func setupNotificationObservers() {
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
    
    @objc private func handleMediaChange() {
        DispatchQueue.main.async { [weak self] in
            self?.refreshNowPlaying()
        }
    }
    
    public func refreshNowPlaying() {
        if let mrIsPlaying = mrIsPlaying {
            mrIsPlaying(DispatchQueue.main) { [weak self] playing in
                DispatchQueue.main.async {
                    self?.isPlaying = playing.boolValue
                }
            }
        }
        
        if let mrGetInfo = mrGetInfo {
            mrGetInfo(DispatchQueue.main) { [weak self] dict in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    if let dict = dict as? [String: Any], !dict.isEmpty {
                        self.parseMediaDictionary(dict)
                    } else {
                        // MediaRemote empty, try AppleScript fallback for Spotify / Apple Music
                        self.fallbackAppleScriptCheck()
                    }
                }
            }
        } else {
            fallbackAppleScriptCheck()
        }
    }
    
    private func parseMediaDictionary(_ dict: [String: Any]) {
        let newTitle = dict["kMRMediaRemoteNowPlayingInfoTitle"] as? String ?? ""
        let newArtist = dict["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? ""
        let newAlbum = dict["kMRMediaRemoteNowPlayingInfoAlbum"] as? String ?? ""
        let newDuration = dict["kMRMediaRemoteNowPlayingInfoDuration"] as? Double ?? 0
        let newElapsed = dict["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? Double ?? 0
        
        var newArtwork: NSImage? = nil
        if let artData = dict["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data {
            newArtwork = NSImage(data: artData)
        }
        
        if !newTitle.isEmpty {
            self.title = newTitle
            self.artist = newArtist.isEmpty ? "Unknown Artist" : newArtist
            self.album = newAlbum
            self.duration = newDuration
            self.elapsedTime = newElapsed
            self.hasActiveMedia = true
            if let newArtwork = newArtwork {
                self.artwork = newArtwork
            }
        } else {
            self.hasActiveMedia = false
            self.isPlaying = false
            self.artwork = nil
            fallbackAppleScriptCheck()
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
        DispatchQueue.global(qos: .utility).async { [weak self] in
            var error: NSDictionary?
            if let script = NSAppleScript(source: scriptText),
               let descriptor = script.executeAndReturnError(&error).stringValue {
                let parts = descriptor.components(separatedBy: "|||")
                if parts.count >= 6 && !parts[0].isEmpty {
                    DispatchQueue.main.async {
                        self?.title = parts[0]
                        self?.artist = parts[1].isEmpty ? defaultArtist : parts[1]
                        self?.album = parts[2]
                        if let durMs = Double(parts[3]) {
                            // Spotify returns duration in ms, Music in seconds
                            self?.duration = durMs > 1000 ? durMs / 1000.0 : durMs
                        }
                        self?.elapsedTime = Double(parts[4]) ?? 0
                        self?.isPlaying = parts[5] == "playing"
                        self?.hasActiveMedia = true
                    }
                }
            }
        }
    }
    
    // MARK: - Playback Controls
    
    public func togglePlayPause() {
        if let mrSendCommand = mrSendCommand {
            _ = mrSendCommand(2, nil) // 2 = TogglePlayPause
        } else {
            executeAppleScriptMediaCommand("playpause")
        }
        isPlaying.toggle()
    }
    
    public func play() {
        if let mrSendCommand = mrSendCommand {
            _ = mrSendCommand(0, nil) // 0 = Play
        } else {
            executeAppleScriptMediaCommand("play")
        }
        isPlaying = true
    }
    
    public func pause() {
        if let mrSendCommand = mrSendCommand {
            _ = mrSendCommand(1, nil) // 1 = Pause
        } else {
            executeAppleScriptMediaCommand("pause")
        }
        isPlaying = false
    }
    
    public func nextTrack() {
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
        let isSpotifyRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client").isEmpty
        let target = isSpotifyRunning ? "Spotify" : "Music"
        let script = "tell application \"\(target)\" to set player position to \(seconds)"
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            NSAppleScript(source: script)?.executeAndReturnError(&error)
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
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        if let handle = handle {
            dlclose(handle)
        }
    }
}

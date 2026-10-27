import Cocoa

// MARK: - MediaBridge (macOS 15/26 MediaRemote Bridge)
// Runs via /usr/bin/swift to retain Apple-signed access to mediaremoted

guard let handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW) else {
    exit(1)
}

typealias MRRegisterFunction = @convention(c) (DispatchQueue) -> Void
typealias MRGetInfoFunction = @convention(c) (DispatchQueue, @escaping (CFDictionary?) -> Void) -> Void
typealias MRIsPlayingFunction = @convention(c) (DispatchQueue, @escaping (DarwinBoolean) -> Void) -> Void
typealias MRSendCommandFunction = @convention(c) (Int, CFDictionary?) -> DarwinBoolean
typealias MRSetElapsedFunction = @convention(c) (Double) -> Void

var mrGetInfo: MRGetInfoFunction?
var mrIsPlaying: MRIsPlayingFunction?
var mrSendCommand: MRSendCommandFunction?
var mrSetElapsedTime: MRSetElapsedFunction?

if let regSym = dlsym(handle, "MRMediaRemoteRegisterForNowPlayingNotifications") {
    let fn = unsafeBitCast(regSym, to: MRRegisterFunction.self)
    fn(DispatchQueue.main)
}

if let getInfoSym = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo") {
    mrGetInfo = unsafeBitCast(getInfoSym, to: MRGetInfoFunction.self)
}

if let isPlayingSym = dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationIsPlaying") {
    mrIsPlaying = unsafeBitCast(isPlayingSym, to: MRIsPlayingFunction.self)
}

if let sendCmdSym = dlsym(handle, "MRMediaRemoteSendCommand") {
    mrSendCommand = unsafeBitCast(sendCmdSym, to: MRSendCommandFunction.self)
}

if let setElapsedSym = dlsym(handle, "MRMediaRemoteSetElapsedTime") {
    mrSetElapsedTime = unsafeBitCast(setElapsedSym, to: MRSetElapsedFunction.self)
}

let jsonPath = "/tmp/keynotch_media.json"
let artPath = "/tmp/keynotch_artwork.jpg"

var currentIsPlaying = false
var pollTimer: Timer?

func cleanVideoTitle(_ str: String) -> String {
    var s = str
    let tags = [
        "(Official Video)", "(Official Music Video)", "[Official Video]",
        "[Official Music Video]", "(Official Audio)", "[Official Audio]",
        "(Lyric Video)", "[Lyric Video]", "(Lyrics Video)", "[Lyrics Video]",
        "(Audio)", "(Video)", "(Visualizer)", "[Visualizer]", "(Live)", "[Live]",
        "(Lyrics)", "[Lyrics]", "(Lyric)", "[Lyric]",
        ", lyric video", ", lyrics video", ", official video", ", visualizer",
        "| lyric video", "| lyrics video", "| official video",
        "(Tiktok Version)", "[Tiktok Version]", "(Speed Up)", "[Speed Up]",
        "(Slowed + Reverb)", "[Slowed + Reverb]", "(Slowed and Reverb)", "[Slowed and Reverb]",
        "(Remix)", "[Remix]", "(HD)", "[HD]", "(4K)", "[4K]"
    ]
    for tag in tags {
        if let r = s.range(of: tag, options: .caseInsensitive) {
            s.removeSubrange(r)
        }
    }
    return s.trimmingCharacters(in: .whitespacesAndNewlines)
}

func updateNowPlaying() {
    guard let mrIsPlaying = mrIsPlaying, let mrGetInfo = mrGetInfo else { return }
    
    mrIsPlaying(DispatchQueue.main) { playing in
        let isPlay = playing.boolValue
        currentIsPlaying = isPlay
        
        mrGetInfo(DispatchQueue.main) { dict in
            guard let dict = dict as? [String: Any], !dict.isEmpty else {
                writePayload(title: "", artist: "", album: "", duration: 0, elapsed: 0, isPlaying: false, hasArtwork: false)
                return
            }
            
            let rawTitle = dict["kMRMediaRemoteNowPlayingInfoTitle"] as? String ?? ""
            let rawArtist = dict["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? ""
            let rawAlbum = dict["kMRMediaRemoteNowPlayingInfoAlbum"] as? String ?? ""
            
            let duration = (dict["kMRMediaRemoteNowPlayingInfoDuration"] as? NSNumber)?.doubleValue
                ?? (dict["kMRMediaRemoteNowPlayingInfoDuration"] as? Double ?? 0)
            let elapsed = (dict["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? NSNumber)?.doubleValue
                ?? (dict["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? Double ?? 0)
            let playbackRate = (dict["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? NSNumber)?.doubleValue ?? 0
            let timestamp = dict["kMRMediaRemoteNowPlayingInfoTimestamp"] as? Date
            
            var calculatedElapsed = elapsed
            if let ts = timestamp, playbackRate > 0 {
                let diff = Date().timeIntervalSince(ts)
                calculatedElapsed += (diff * playbackRate)
            }
            if duration > 0 {
                calculatedElapsed = min(duration, max(0, calculatedElapsed))
            }
            
            var hasArtwork = false
            if let artData = dict["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data {
                try? artData.write(to: URL(fileURLWithPath: artPath), options: .atomic)
                hasArtwork = true
            }
            
            var title = cleanVideoTitle(rawTitle)
            var artist = rawArtist.isEmpty ? "Unknown Artist" : rawArtist
            
            // Standard YouTube formats:
            // 1. "Artist - Song Title" (e.g. "Phoebe Bridgers - Scott Street")
            var foundSep = false
            for sep in [" - ", " – ", " — "] {
                if rawTitle.contains(sep) {
                    let parts = rawTitle.components(separatedBy: sep)
                    if parts.count >= 2 {
                        let artistPart = cleanVideoTitle(parts[0])
                        let titlePart = cleanVideoTitle(parts[1...].joined(separator: sep))
                        artist = artistPart
                        title = titlePart
                        foundSep = true
                        break
                    }
                }
            }
            // 2. "Song Title by Artist" (e.g. "Cinnamon girl by Lana Del Rey")
            if !foundSep && title.contains(" by ") {
                let parts = title.components(separatedBy: " by ")
                if parts.count >= 2 {
                    let titlePart = cleanVideoTitle(parts[0])
                    let artistPart = cleanVideoTitle(parts[1...].joined(separator: " by "))
                    title = titlePart
                    artist = artistPart
                }
            }
            
            writePayload(
                title: title,
                artist: artist,
                album: rawAlbum,
                duration: duration,
                elapsed: calculatedElapsed,
                isPlaying: isPlay,
                hasArtwork: hasArtwork
            )
        }
    }
}

func writePayload(title: String, artist: String, album: String, duration: Double, elapsed: Double, isPlaying: Bool, hasArtwork: Bool) {
    let payload: [String: Any] = [
        "title": title,
        "artist": artist,
        "album": album,
        "duration": duration,
        "elapsedTime": elapsed,
        "isPlaying": isPlaying,
        "hasArtwork": hasArtwork,
        "artworkPath": hasArtwork ? artPath : "",
        "timestamp": Date().timeIntervalSince1970
    ]
    
    if let data = try? JSONSerialization.data(withJSONObject: payload, options: []) {
        try? data.write(to: URL(fileURLWithPath: jsonPath), options: .atomic)
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name("com.keynotch.mediaUpdated"),
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }
    
    // Manage polling timer
    if isPlaying {
        if pollTimer == nil {
            pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                updateNowPlaying()
            }
        }
    } else {
        pollTimer?.invalidate()
        pollTimer = nil
    }
}

// Observe Darwin & Local Media Notifications
let nc = NotificationCenter.default
nc.addObserver(forName: NSNotification.Name("kMRMediaRemoteNowPlayingInfoDidChangeNotification"), object: nil, queue: .main) { _ in
    updateNowPlaying()
}
nc.addObserver(forName: NSNotification.Name("kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification"), object: nil, queue: .main) { _ in
    updateNowPlaying()
}
nc.addObserver(forName: NSNotification.Name("kMRMediaRemoteNowPlayingApplicationDidChangeNotification"), object: nil, queue: .main) { _ in
    updateNowPlaying()
}

// Observe IPC Commands from KeyNotch UI
let dnc = DistributedNotificationCenter.default()
dnc.addObserver(forName: NSNotification.Name("com.keynotch.command.playPause"), object: nil, queue: .main) { _ in
    _ = mrSendCommand?(2, nil) // kMRTogglePlayPause
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { updateNowPlaying() }
}
dnc.addObserver(forName: NSNotification.Name("com.keynotch.command.next"), object: nil, queue: .main) { _ in
    _ = mrSendCommand?(4, nil) // kMRNextTrack
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { updateNowPlaying() }
}
dnc.addObserver(forName: NSNotification.Name("com.keynotch.command.previous"), object: nil, queue: .main) { _ in
    _ = mrSendCommand?(5, nil) // kMRPreviousTrack
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { updateNowPlaying() }
}
dnc.addObserver(forName: NSNotification.Name("com.keynotch.command.seek"), object: nil, queue: .main) { notif in
    if let secStr = notif.userInfo?["seconds"] as? String, let sec = Double(secStr) {
        mrSetElapsedTime?(sec)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { updateNowPlaying() }
    }
}
dnc.addObserver(forName: NSNotification.Name("com.keynotch.command.requestSync"), object: nil, queue: .main) { _ in
    updateNowPlaying()
}

// Watchdog timer: automatically exit if orphaned (parent PID becomes 1)
Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
    if getppid() == 1 {
        exit(0)
    }
}

// Initial Sync
updateNowPlaying()

// Keep RunLoop Alive
CFRunLoopRun()

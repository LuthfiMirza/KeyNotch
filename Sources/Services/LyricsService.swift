import Foundation
import Combine
import SwiftUI

public struct LyricLine: Identifiable, Equatable {
    public let id: Int
    public let time: TimeInterval
    public let text: String
    
    public init(id: Int, time: TimeInterval, text: String) {
        self.id = id
        self.time = time
        self.text = text
    }
}

public final class LyricsService: ObservableObject {
    public static let shared = LyricsService()
    
    @Published public var lyrics: [LyricLine] = []
    @Published public var currentLineIndex: Int = 0
    @Published public var isLyricsExpanded: Bool = false
    @Published public var isLoading: Bool = false
    @Published public var statusMessage: String? = nil
    
    private var cancellables = Set<AnyCancellable>()
    private var lastFetchedTrack: String = ""
    private var cache: [String: [LyricLine]] = [:]
    
    private init() {
        setupMediaObserver()
    }
    
    private func setupMediaObserver() {
        MediaRemoteService.shared.$title
            .combineLatest(MediaRemoteService.shared.$artist)
            .receive(on: RunLoop.main)
            .sink { [weak self] title, artist in
                self?.handleTrackChanged(title: title, artist: artist)
            }
            .store(in: &cancellables)
            
        MediaRemoteService.shared.$elapsedTime
            .receive(on: RunLoop.main)
            .sink { [weak self] elapsed in
                self?.updateCurrentLine(for: elapsed)
            }
            .store(in: &cancellables)
    }
    
    public func toggleLyrics() {
        withAnimation(.spring(response: 0.36, dampingFraction: 0.78)) {
            isLyricsExpanded.toggle()
        }
        if isLyricsExpanded && lyrics.isEmpty && !isLoading {
            fetchLyrics(title: MediaRemoteService.shared.title, artist: MediaRemoteService.shared.artist)
        }
    }
    
    public func handleTrackChanged(title: String, artist: String) {
        guard !title.isEmpty else {
            lyrics = []
            statusMessage = "No track playing"
            return
        }
        
        let key = "\(title) - \(artist)".lowercased()
        guard key != lastFetchedTrack else { return }
        lastFetchedTrack = key
        
        if let cached = cache[key] {
            self.lyrics = cached
            self.statusMessage = cached.isEmpty ? "No lyrics found" : nil
            return
        }
        
        if isLyricsExpanded {
            fetchLyrics(title: title, artist: artist)
        } else {
            lyrics = []
        }
    }
    
    public func fetchLyrics(title: String, artist: String) {
        guard !title.isEmpty else { return }
        
        let cleanedTitle = cleanTrackTitle(title)
        let cleanedArtist = cleanTrackTitle(artist)
        let key = "\(cleanedTitle) - \(cleanedArtist)".lowercased()
        
        if let cached = cache[key] {
            self.lyrics = cached
            self.statusMessage = cached.isEmpty ? "No lyrics found" : nil
            return
        }
        
        isLoading = true
        statusMessage = "Fetching synchronized lyrics..."
        
        // Build candidate combinations for YouTube and standard audio
        var candidates: [(track: String, artist: String)] = []
        candidates.append((track: cleanedTitle, artist: cleanedArtist))
        
        for sep in [" - ", " – ", " — "] {
            if title.contains(sep) {
                let parts = title.components(separatedBy: sep)
                if parts.count >= 2 {
                    let p0 = cleanTrackTitle(parts[0])
                    let p1 = cleanTrackTitle(parts[1...].joined(separator: sep))
                    candidates.append((track: p0, artist: p1))
                    candidates.append((track: p1, artist: p0))
                }
            }
        }
        
        tryCandidate(candidates, at: 0, cacheKey: key, fallbackQuery: cleanedTitle)
    }
    
    private func tryCandidate(_ candidates: [(track: String, artist: String)], at index: Int, cacheKey: String, fallbackQuery: String) {
        guard index < candidates.count else {
            // All direct gets exhausted; search via query
            fallbackSearchLyrics(query: fallbackQuery, cacheKey: cacheKey)
            return
        }
        
        let c = candidates[index]
        guard let encodedTrack = c.track.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedArtist = c.artist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://lrclib.net/api/get?track_name=\(encodedTrack)&artist_name=\(encodedArtist)") else {
            tryCandidate(candidates, at: index + 1, cacheKey: cacheKey, fallbackQuery: fallbackQuery)
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("KeyNotch Dynamic Island App (macOS)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 4.0
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200, let data = data {
                    if let parsed = self.parseLRCLIBResponse(data: data), !parsed.isEmpty {
                        self.cache[cacheKey] = parsed
                        self.lyrics = parsed
                        self.isLoading = false
                        self.statusMessage = nil
                        self.updateCurrentLine(for: MediaRemoteService.shared.elapsedTime)
                        return
                    }
                }
                
                // Try next candidate
                self.tryCandidate(candidates, at: index + 1, cacheKey: cacheKey, fallbackQuery: fallbackQuery)
            }
        }.resume()
    }
    
    private func fallbackSearchLyrics(query: String, cacheKey: String) {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://lrclib.net/api/search?q=\(encoded)") else {
            self.isLoading = false
            self.statusMessage = "No lyrics found"
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("KeyNotch Dynamic Island App (macOS)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 5.0
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                if let data = data,
                   let items = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    for item in items {
                        if let synced = item["syncedLyrics"] as? String, !synced.isEmpty {
                            let parsed = self.parseLRC(content: synced)
                            if !parsed.isEmpty {
                                self.cache[cacheKey] = parsed
                                self.lyrics = parsed
                                self.statusMessage = nil
                                self.updateCurrentLine(for: MediaRemoteService.shared.elapsedTime)
                                return
                            }
                        }
                    }
                    
                    // Plain lyrics fallback if no synced version
                    for item in items {
                        if let plain = item["plainLyrics"] as? String, !plain.isEmpty {
                            let lines = plain.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                            let parsed = lines.enumerated().map { i, text in
                                LyricLine(id: i, time: Double(i * 4), text: text)
                            }
                            if !parsed.isEmpty {
                                self.cache[cacheKey] = parsed
                                self.lyrics = parsed
                                self.statusMessage = nil
                                self.updateCurrentLine(for: MediaRemoteService.shared.elapsedTime)
                                return
                            }
                        }
                    }
                }
                
                self.cache[cacheKey] = []
                self.lyrics = []
                self.statusMessage = "No synchronized lyrics found"
            }
        }.resume()
    }
    
    private func parseLRCLIBResponse(data: Data) -> [LyricLine]? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        if let synced = json["syncedLyrics"] as? String, !synced.isEmpty {
            return parseLRC(content: synced)
        }
        
        if let plain = json["plainLyrics"] as? String, !plain.isEmpty {
            // Unsynced fallback
            let lines = plain.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            return lines.enumerated().map { index, line in
                LyricLine(id: index, time: Double(index * 4), text: line)
            }
        }
        
        return []
    }
    
    public func parseLRC(content: String) -> [LyricLine] {
        var result: [LyricLine] = []
        let rawLines = content.components(separatedBy: "\n")
        var idCounter = 0
        
        for rawLine in rawLines {
            let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("[") else { continue }
            
            // Format: [mm:ss.xx] or [mm:ss]
            if let closingBracket = trimmed.firstIndex(of: "]") {
                let timeString = String(trimmed[trimmed.index(after: trimmed.startIndex)..<closingBracket])
                let lyricText = String(trimmed[trimmed.index(after: closingBracket)...]).trimmingCharacters(in: .whitespaces)
                
                let parts = timeString.components(separatedBy: ":")
                if parts.count == 2,
                   let minutes = Double(parts[0]),
                   let seconds = Double(parts[1]) {
                    let totalSeconds = (minutes * 60.0) + seconds
                    if !lyricText.isEmpty {
                        result.append(LyricLine(id: idCounter, time: totalSeconds, text: lyricText))
                        idCounter += 1
                    }
                }
            }
        }
        return result
    }
    
    private func updateCurrentLine(for elapsed: Double) {
        guard isLyricsExpanded, !lyrics.isEmpty else { return }
        
        var foundIndex = 0
        for (i, line) in lyrics.enumerated() {
            if line.time <= elapsed {
                foundIndex = i
            } else {
                break
            }
        }
        
        if foundIndex != currentLineIndex {
            currentLineIndex = foundIndex
        }
    }
    
    private func cleanTrackTitle(_ title: String) -> String {
        var cleaned = title
        let patterns = [
            "(feat.", "[feat.", "(with ", "[with ",
            "(official video", "[official video",
            "(official music video", "[official music video",
            "(official audio", "[official audio",
            "(lyric video", "[lyric video",
            "(video)", "(audio)",
            "(live", "[live",
            " - remastered", " [remastered]"
        ]
        
        for pat in patterns {
            if let range = cleaned.range(of: pat, options: .caseInsensitive) {
                cleaned = String(cleaned[..<range.lowerBound])
            }
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

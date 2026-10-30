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
    @Published public var isLyricsExpanded: Bool = true
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
            .combineLatest(MediaRemoteService.shared.$artist, MediaRemoteService.shared.$duration)
            .receive(on: RunLoop.main)
            .sink { [weak self] title, artist, duration in
                self?.handleTrackChanged(title: title, artist: artist, duration: duration)
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
            fetchLyrics(
                title: MediaRemoteService.shared.title,
                artist: MediaRemoteService.shared.artist,
                duration: MediaRemoteService.shared.duration
            )
        }
    }
    
    public func handleTrackChanged(title: String, artist: String, duration: Double = 0) {
        guard !title.isEmpty else {
            lyrics = []
            statusMessage = "No track playing"
            lastFetchedTrack = ""
            return
        }
        
        let cleanedTitle = cleanTrackTitle(title)
        let cleanedArtist = cleanTrackTitle(artist)
        let effectiveDuration = duration > 0 ? duration : MediaRemoteService.shared.duration
        let durationBucket = Int(effectiveDuration / 4.0) * 4
        let key = "\(cleanedTitle) - \(cleanedArtist) - \(durationBucket)".lowercased()
        
        guard key != lastFetchedTrack else { return }
        lastFetchedTrack = key
        
        if let cached = cache[key] {
            self.lyrics = cached
            self.statusMessage = cached.isEmpty ? "No lyrics found" : nil
            self.updateCurrentLine(for: MediaRemoteService.shared.elapsedTime)
            return
        }
        
        if isLyricsExpanded {
            fetchLyrics(title: title, artist: artist, duration: effectiveDuration)
        } else {
            lyrics = []
        }
    }
    
    public func fetchLyrics(title: String, artist: String, duration: Double = 0) {
        guard !title.isEmpty else { return }
        
        let cleanedTitle = cleanTrackTitle(title)
        let cleanedArtist = cleanTrackTitle(artist)
        let effectiveDuration = duration > 0 ? duration : MediaRemoteService.shared.duration
        let durationBucket = Int(effectiveDuration / 4.0) * 4
        let key = "\(cleanedTitle) - \(cleanedArtist) - \(durationBucket)".lowercased()
        
        if let cached = cache[key] {
            self.lyrics = cached
            self.statusMessage = cached.isEmpty ? "No lyrics found" : nil
            self.updateCurrentLine(for: MediaRemoteService.shared.elapsedTime)
            return
        }
        
        isLoading = true
        statusMessage = "Fetching synchronized lyrics..."
        
        // Build candidate search queries
        var searchQueries: [String] = []
        if !cleanedArtist.isEmpty && cleanedArtist.lowercased() != "unknown artist" {
            searchQueries.append("\(cleanedTitle) \(cleanedArtist)")
            searchQueries.append("\(cleanedArtist) \(cleanedTitle)")
        }
        
        for sep in [" - ", " – ", " — ", " | "] {
            if title.contains(sep) {
                let parts = title.components(separatedBy: sep)
                if parts.count >= 2 {
                    let p0 = cleanTrackTitle(parts[0])
                    let p1 = cleanTrackTitle(parts[1...].joined(separator: sep))
                    searchQueries.append("\(p0) \(p1)")
                    searchQueries.append("\(p1) \(p0)")
                    searchQueries.append(p0)
                    searchQueries.append(p1)
                }
            }
        }
        searchQueries.append(cleanedTitle)
        if !cleanedArtist.isEmpty && cleanedArtist.lowercased() != "unknown artist" {
            searchQueries.append(cleanedArtist)
        }
        
        var uniqueQueries: [String] = []
        for q in searchQueries {
            let trimmed = q.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && !uniqueQueries.contains(trimmed) {
                uniqueQueries.append(trimmed)
            }
        }
        
        trySearchQueries(
            queries: uniqueQueries,
            at: 0,
            targetArtist: cleanedArtist,
            targetDuration: effectiveDuration,
            cacheKey: key,
            rawTitle: cleanedTitle
        )
    }
    
    private func trySearchQueries(
        queries: [String],
        at index: Int,
        targetArtist: String,
        targetDuration: Double,
        cacheKey: String,
        rawTitle: String
    ) {
        guard index < queries.count else {
            // All search queries exhausted; try direct api/get as fallback
            tryDirectAPIGet(title: rawTitle, artist: targetArtist, duration: targetDuration, cacheKey: cacheKey)
            return
        }
        
        let query = queries[index]
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://lrclib.net/api/search?q=\(encoded)") else {
            trySearchQueries(
                queries: queries,
                at: index + 1,
                targetArtist: targetArtist,
                targetDuration: targetDuration,
                cacheKey: cacheKey,
                rawTitle: rawTitle
            )
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("KeyNotch Dynamic Island App (macOS)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 4.5
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let data = data,
                   let items = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                   !items.isEmpty {
                    
                    let scored = items.map { item -> (item: [String: Any], score: Double) in
                        let sc = self.calculateCandidateScore(
                            item: item,
                            targetArtist: targetArtist,
                            targetDuration: targetDuration,
                            targetTitle: rawTitle
                        )
                        return (item: item, score: sc)
                    }.sorted { $0.score < $1.score }
                    
                    if let best = scored.first, best.score < 500.0 {
                        if let synced = best.item["syncedLyrics"] as? String, !synced.isEmpty {
                            let parsed = self.parseLRC(content: synced)
                            if !parsed.isEmpty {
                                self.cache[cacheKey] = parsed
                                self.lyrics = parsed
                                self.isLoading = false
                                self.statusMessage = nil
                                self.updateCurrentLine(for: MediaRemoteService.shared.elapsedTime)
                                return
                            }
                        } else if let plain = best.item["plainLyrics"] as? String, !plain.isEmpty {
                            let lines = plain.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                            let lineInterval = targetDuration > 0 ? (targetDuration / Double(max(1, lines.count))) : 4.0
                            let parsed = lines.enumerated().map { idx, line in
                                LyricLine(id: idx, time: Double(idx) * lineInterval, text: line)
                            }
                            if !parsed.isEmpty {
                                self.cache[cacheKey] = parsed
                                self.lyrics = parsed
                                self.isLoading = false
                                self.statusMessage = nil
                                self.updateCurrentLine(for: MediaRemoteService.shared.elapsedTime)
                                return
                            }
                        }
                    }
                }
                
                // Fallback to next query
                self.trySearchQueries(
                    queries: queries,
                    at: index + 1,
                    targetArtist: targetArtist,
                    targetDuration: targetDuration,
                    cacheKey: cacheKey,
                    rawTitle: rawTitle
                )
            }
        }.resume()
    }
    
    private func tryDirectAPIGet(title: String, artist: String, duration: Double, cacheKey: String) {
        guard let encodedTrack = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            finishWithNoLyrics(cacheKey: cacheKey)
            return
        }
        
        var urlString = "https://lrclib.net/api/get?track_name=\(encodedTrack)"
        if !artist.isEmpty && artist.lowercased() != "unknown artist",
           let encodedArtist = artist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            urlString += "&artist_name=\(encodedArtist)"
        }
        if duration > 0 {
            urlString += "&duration=\(Int(duration))"
        }
        
        guard let url = URL(string: urlString) else {
            finishWithNoLyrics(cacheKey: cacheKey)
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
                
                self.finishWithNoLyrics(cacheKey: cacheKey)
            }
        }.resume()
    }
    
    private func finishWithNoLyrics(cacheKey: String) {
        self.cache[cacheKey] = []
        self.lyrics = []
        self.isLoading = false
        self.statusMessage = "No synchronized lyrics found"
    }
    
    private func calculateCandidateScore(
        item: [String: Any],
        targetArtist: String,
        targetDuration: Double,
        targetTitle: String
    ) -> Double {
        let synced = item["syncedLyrics"] as? String
        let plain = item["plainLyrics"] as? String
        
        var score: Double = 0.0
        
        // Prefer syncedLyrics; if only plainLyrics exists, add modest penalty
        if let syncedLyrics = synced, !syncedLyrics.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            score += 0.0
        } else if let plainLyrics = plain, !plainLyrics.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            score += 25.0
        } else {
            return 999999.0
        }
        
        let candidateArtist = (item["artistName"] as? String ?? "").lowercased()
        let candidateTrack = (item["trackName"] as? String ?? "").lowercased()
        let candidateDuration = item["duration"] as? Double ?? 0.0
        
        let targetArt = targetArtist.lowercased()
        let targetTit = targetTitle.lowercased()
        
        // 1. Artist & Title matching (supports swapped metadata)
        var artistMatched = false
        if !targetArt.isEmpty && targetArt != "unknown artist" {
            if candidateArtist == targetArt || candidateArtist.contains(targetArt) || targetArt.contains(candidateArtist) {
                artistMatched = true
            } else if candidateTrack == targetArt || candidateTrack.contains(targetArt) || targetArt.contains(candidateTrack) {
                // Inverted match: candidateTrack matches targetArtist
                artistMatched = true
                score += 15.0
            }
        }
        
        if !targetTit.isEmpty {
            if candidateTrack == targetTit || candidateTrack.contains(targetTit) || targetTit.contains(candidateTrack) {
                score += 0.0
            } else if candidateArtist == targetTit || candidateArtist.contains(targetTit) || targetTit.contains(candidateArtist) {
                // Inverted match: candidateArtist matches targetTitle
                artistMatched = true
                score += 15.0
            }
        }
        
        if !artistMatched && !targetArt.isEmpty && targetArt != "unknown artist" {
            score += 140.0
        }
        
        // 2. Duration matching (capped to handle music video versions)
        if targetDuration > 0 && candidateDuration > 0 {
            let diff = abs(candidateDuration - targetDuration)
            if diff <= 3.0 {
                score += 0.0
            } else if diff <= 8.0 {
                score += diff * 1.2
            } else {
                score += min(75.0, 10.0 + (diff * 0.5))
            }
        }
        
        // 3. Unwanted versions penalty
        for unwanted in ["live", "acoustic", "remix", "tribute", "karaoke", "instrumental", "cover"] {
            if candidateTrack.contains(unwanted) && !targetArt.contains(unwanted) {
                score += 60.0
            }
        }
        
        return score
    }
    
    private func parseLRCLIBResponse(data: Data) -> [LyricLine]? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        if let synced = json["syncedLyrics"] as? String, !synced.isEmpty {
            return parseLRC(content: synced)
        }
        
        if let plain = json["plainLyrics"] as? String, !plain.isEmpty {
            let lines = plain.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            return lines.enumerated().map { index, line in
                LyricLine(id: index, time: Double(index * 4), text: line)
            }
        }
        
        return []
    }
    
    public func parseLRC(content: String) -> [LyricLine] {
        var rawParsed: [(time: Double, text: String)] = []
        let rawLines = content.components(separatedBy: "\n")
        
        for rawLine in rawLines {
            let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("[") else { continue }
            
            // Format: [mm:ss.xx] or [mm:ss]
            if let closingBracket = trimmed.firstIndex(of: "]") {
                let timeString = String(trimmed[trimmed.index(after: trimmed.startIndex)..<closingBracket])
                var lyricText = String(trimmed[trimmed.index(after: closingBracket)...]).trimmingCharacters(in: .whitespaces)
                
                let parts = timeString.components(separatedBy: ":")
                if parts.count == 2,
                   let minutes = Double(parts[0]),
                   let seconds = Double(parts[1]) {
                    let totalSeconds = (minutes * 60.0) + seconds
                    
                    let lower = lyricText.lowercased()
                    if lyricText.isEmpty || lower.contains("break and solo") || lower.contains("guitar solo") || lower == "(solo)" || lower == "[solo]" || lower == "(instrumental)" || lower == "[instrumental]" {
                        lyricText = "♪ ♪ ♪"
                    }
                    
                    // Avoid duplicate consecutive musical note lines
                    if lyricText == "♪ ♪ ♪" && rawParsed.last?.text == "♪ ♪ ♪" {
                        continue
                    }
                    
                    rawParsed.append((time: totalSeconds, text: lyricText))
                }
            }
        }
        
        rawParsed.sort { $0.time < $1.time }
        
        // Insert intro indicator if first vocal line starts > 6.0 seconds in
        if let first = rawParsed.first, first.time > 6.0, first.text != "♪ ♪ ♪" {
            rawParsed.insert((time: 0.0, text: "♪ ♪ ♪"), at: 0)
        }
        
        var result: [LyricLine] = []
        for (i, item) in rawParsed.enumerated() {
            result.append(LyricLine(id: i, time: item.time, text: item.text))
        }
        
        return result
    }
    
    private func updateCurrentLine(for elapsed: Double) {
        guard isLyricsExpanded, !lyrics.isEmpty else { return }
        
        // 0.22s anticipation offset compensates for Bluetooth buffer latency & vocal onset
        let adjustedElapsed = elapsed + 0.22
        var foundIndex = 0
        for (i, line) in lyrics.enumerated() {
            if line.time <= adjustedElapsed {
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
            "(visualizer", "[visualizer",
            "(video)", "(audio)",
            "[mv]", "(mv)",
            "(lyrics)", "[lyrics]",
            "(official)", "[official]",
            "(hd)", "[hd]", "(4k", "[4k",
            "(live", "[live",
            " - remastered", " [remastered]", "(remastered",
            " - single version", "(single version",
            " - album version", "(album version",
            " - radio edit", "(radio edit"
        ]
        
        for pat in patterns {
            if let range = cleaned.range(of: pat, options: .caseInsensitive) {
                cleaned = String(cleaned[..<range.lowerBound])
            }
        }
        
        cleaned = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: " -–—\"'"))
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

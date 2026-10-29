import SwiftUI

public struct MusicTabView: View {
    @ObservedObject var media = MediaRemoteService.shared
    @ObservedObject var lyrics = LyricsService.shared
    @State private var isDraggingScrubber: Bool = false
    @State private var dragProgress: Double = 0.0
    
    public init() {}
    
    private var progress: Double {
        if isDraggingScrubber {
            return dragProgress
        }
        guard media.duration > 0 else { return 0 }
        return max(0.0, min(1.0, media.elapsedTime / media.duration))
    }
    
    private var elapsedString: String {
        let sec = isDraggingScrubber ? Int(dragProgress * media.duration) : Int(media.elapsedTime)
        let m = sec / 60
        let s = sec % 60
        return String(format: "%d:%02d", m, s)
    }
    
    private var remainingString: String {
        guard media.duration > 0 else { return "-0:00" }
        let currentSec = isDraggingScrubber ? (dragProgress * media.duration) : media.elapsedTime
        let remaining = max(0, Int(media.duration - currentSec))
        let m = remaining / 60
        let s = remaining % 60
        return String(format: "-%d:%02d", m, s)
    }
    
    public var body: some View {
        Group {
            if lyrics.isLyricsExpanded {
                splitLyricsView
            } else {
                compactSinglePlayerView
            }
        }
        .onAppear {
            media.refreshNowPlaying()
            if lyrics.lyrics.isEmpty && !lyrics.isLoading && !media.title.isEmpty {
                lyrics.fetchLyrics(title: media.title, artist: media.artist)
            }
        }
    }
    
    // MARK: - Side-by-Side Split View (Matching User Screenshot)
    
    private var splitLyricsView: some View {
        HStack(spacing: 0) {
            // LEFT: Track Info, Scrubber, & Controls (~290px)
            leftPlayerColumn
                .frame(width: 290)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            
            // Vertical Subtle Divider
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 1)
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
            
            // RIGHT: Clean Synced Lyrics View (~360px)
            rightLyricsColumn
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Left Player Column
    
    private var leftPlayerColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 1. Artwork & Track Metadata
            HStack(spacing: 12) {
                artworkView(size: 48, cornerRadius: 10)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(media.title.isEmpty ? "No Media Playing" : media.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(media.artist.isEmpty ? "Audio playback will appear here" : media.artist)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(.white.opacity(0.65))
                        .lineLimit(1)
                }
                
                Spacer(minLength: 0)
            }
            
            // 2. Scrubber with Timestamps
            scrubberView
                .padding(.top, 2)
            
            // 3. Playback Controls Row (Backward, Play/Pause, Forward, Pink Lyrics Pill, AirPlay)
            HStack(spacing: 16) {
                // Backward
                Button(action: { media.previousTrack() }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Play / Pause
                Button(action: { media.togglePlayPause() }) {
                    Image(systemName: media.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Forward
                Button(action: { media.nextTrack() }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer(minLength: 0)
                
                // Red/Pink Lyrics Pill Button (Screenshot Match!)
                Button(action: {
                    lyrics.toggleLyrics()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "quote.bubble.fill")
                            .font(.system(size: 10.5, weight: .bold))
                        Text("Lyrics")
                            .font(.system(size: 11.5, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(lyrics.isLyricsExpanded ? Color(red: 0.95, green: 0.22, blue: 0.38) : Color.white.opacity(0.12))
                    )
                    .shadow(color: lyrics.isLyricsExpanded ? Color(red: 0.95, green: 0.22, blue: 0.38).opacity(0.4) : Color.clear, radius: 4)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Buka / Tutup Lirik Tersinkron")
                
                // AirPlay / Audio Output Button
                Button(action: {
                    openAudioOutputSelector()
                }) {
                    Image(systemName: "airplayaudio")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                }
                .buttonStyle(PlainButtonStyle())
                .help("Pilih Output Audio")
            }
            .padding(.top, 2)
            
            Spacer(minLength: 0)
        }
    }
    
    // MARK: - Right Synced Lyrics Column
    
    private var rightLyricsColumn: some View {
        Group {
            if lyrics.isLoading && lyrics.lyrics.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.65)
                    Text("Memuat lirik tersinkron...")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(.white.opacity(0.45))
                    Spacer()
                }
            } else if lyrics.lyrics.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "music.mic")
                        .font(.system(size: 22))
                        .foregroundColor(.white.opacity(0.25))
                    Text(lyrics.statusMessage ?? "Tidak ada lirik tersinkron")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.55))
                    Button(action: {
                        lyrics.fetchLyrics(title: media.title, artist: media.artist)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 9, weight: .bold))
                            Text("Coba Lagi")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3.5)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                    Spacer()
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(lyrics.lyrics.enumerated()), id: \.element.id) { index, line in
                                let isActive = index == lyrics.currentLineIndex
                                let isPast = index < lyrics.currentLineIndex
                                
                                Text(line.text)
                                    .font(.system(
                                        size: isActive ? 16.5 : (isPast ? 13.5 : 14),
                                        weight: isActive ? .bold : (isPast ? .medium : .regular),
                                        design: .rounded
                                    ))
                                    .foregroundColor(
                                        isActive ? Color.white : (isPast ? Color.white.opacity(0.38) : Color.white.opacity(0.55))
                                    )
                                    .shadow(color: isActive ? Color.white.opacity(0.35) : Color.clear, radius: 4)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.vertical, 2)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        media.seek(to: line.time)
                                    }
                                    .id(line.id)
                            }
                        }
                        .padding(.vertical, 32)
                    }
                    .mask(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .black, location: 0.16),
                                .init(color: .black, location: 0.84),
                                .init(color: .clear, location: 1.0)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .onChange(of: lyrics.currentLineIndex) { newIndex in
                        if newIndex >= 0 && newIndex < lyrics.lyrics.count {
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) {
                                proxy.scrollTo(lyrics.lyrics[newIndex].id, anchor: .center)
                            }
                        }
                    }
                    .onAppear {
                        if lyrics.currentLineIndex >= 0 && lyrics.currentLineIndex < lyrics.lyrics.count {
                            proxy.scrollTo(lyrics.lyrics[lyrics.currentLineIndex].id, anchor: .center)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Single Column Mode (When lyrics is toggled off)
    
    private var compactSinglePlayerView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                artworkView(size: 52, cornerRadius: 11)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(media.title.isEmpty ? "No Media Playing" : media.title)
                        .font(.system(size: 15.5, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(media.artist.isEmpty ? "Audio playback will appear here" : media.artist)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.65))
                        .lineLimit(1)
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            scrubberView
                .padding(.horizontal, 20)
            
            HStack(spacing: 24) {
                Button(action: { lyrics.toggleLyrics() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "quote.bubble.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("Lyrics")
                            .font(.system(size: 11.5, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                Button(action: { media.previousTrack() }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: { media.togglePlayPause() }) {
                    Image(systemName: media.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: { media.nextTrack() }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                Button(action: { openAudioOutputSelector() }) {
                    Image(systemName: "airplayaudio")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Reusable Artwork View
    
    private func artworkView(size: CGFloat, cornerRadius: CGFloat) -> some View {
        ZStack {
            if let artwork = media.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: size, height: size)
                
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.42))
                    .foregroundColor(.white.opacity(0.45))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 0.6)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 6, x: 0, y: 2)
    }
    
    // MARK: - Reusable Scrubber View
    
    private var scrubberView: some View {
        HStack(spacing: 8) {
            Text(elapsedString)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 32, alignment: .leading)
            
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.22))
                        .frame(height: 3.5)
                    
                    Capsule()
                        .fill(Color.white)
                        .frame(width: max(0, min(w, w * CGFloat(progress))), height: 3.5)
                    
                    Circle()
                        .fill(Color.white)
                        .frame(width: 8.5, height: 8.5)
                        .offset(x: max(0, min(w - 8.5, (w * CGFloat(progress)) - 4.25)))
                        .shadow(color: Color.black.opacity(0.5), radius: 2)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { g in
                            isDraggingScrubber = true
                            dragProgress = max(0.0, min(1.0, Double(g.location.x / w)))
                        }
                        .onEnded { g in
                            let finalProgress = max(0.0, min(1.0, Double(g.location.x / w)))
                            media.seek(to: finalProgress * media.duration)
                            isDraggingScrubber = false
                        }
                )
            }
            .frame(height: 9)
            
            Text(remainingString)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 38, alignment: .trailing)
        }
    }
    
    private func openAudioOutputSelector() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Sound-Settings.extension") {
            NSWorkspace.shared.open(url)
        } else if let url = URL(string: "x-apple.systempreferences:com.apple.preference.sound") {
            NSWorkspace.shared.open(url)
        }
    }
}

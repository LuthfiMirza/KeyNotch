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
        return String(format: "%02d:%02d", m, s)
    }
    
    private var remainingString: String {
        guard media.duration > 0 else { return "-00:00" }
        let currentSec = isDraggingScrubber ? (dragProgress * media.duration) : media.elapsedTime
        let remaining = max(0, Int(media.duration - currentSec))
        let m = remaining / 60
        let s = remaining % 60
        return String(format: "-%02d:%02d", m, s)
    }
    
    public var body: some View {
        Group {
            if lyrics.isLyricsExpanded {
                splitLyricsView
            } else {
                standardPlayerView
            }
        }
        .onAppear {
            media.refreshNowPlaying()
            if lyrics.isLyricsExpanded && lyrics.lyrics.isEmpty && !lyrics.isLoading {
                lyrics.fetchLyrics(title: media.title, artist: media.artist)
            }
        }
    }
    
    // MARK: - Standard Player View (520px)
    
    private var standardPlayerView: some View {
        VStack(spacing: 12) {
            // Top Status Row
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(media.isPlaying ? Color.green : Color.white.opacity(0.3))
                        .frame(width: 6, height: 6)
                    Text(media.isPlaying ? "NOW PLAYING" : "AUDIO READY")
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .tracking(0.8)
                }
                
                Spacer()
                
                WaveformView(
                    isPlaying: media.isPlaying,
                    color: .white,
                    barCount: 5,
                    maxHeight: 13
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            
            // Center Media Info Card
            HStack(spacing: 14) {
                // Album Artwork
                artworkView(size: 58, cornerRadius: 12)
                
                // Track Info
                VStack(alignment: .leading, spacing: 3) {
                    Text(media.title.isEmpty ? "No Media Playing" : media.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(media.artist.isEmpty ? "Audio playback will appear here" : media.artist)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.65))
                        .lineLimit(1)
                    
                    if !media.album.isEmpty {
                        Text(media.album)
                            .font(.system(size: 10, weight: .regular))
                            .foregroundColor(.white.opacity(0.45))
                            .lineLimit(1)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            
            // Scrubber & Timestamps
            scrubberView
                .padding(.horizontal, 16)
            
            // Playback Controls & Lyrics Toggle
            HStack(spacing: 24) {
                // Lyrics Button
                Button(action: {
                    lyrics.toggleLyrics()
                }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: "quote.bubble")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .help("Buka Lirik Tersinkron (Split-View)")
                
                Spacer()
                
                // Previous Track
                Button(action: {
                    media.previousTrack()
                }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Play / Pause Circle
                Button(action: {
                    media.togglePlayPause()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: media.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.black)
                            .offset(x: media.isPlaying ? 0 : 1)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                // Next Track
                Button(action: {
                    media.nextTrack()
                }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                Color.clear
                    .frame(width: 32, height: 32)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 6)
        }
    }
    
    // MARK: - Split-View Synced Lyrics (680px)
    
    private var splitLyricsView: some View {
        HStack(spacing: 0) {
            // LEFT COLUMN: Compact Player (~270px)
            VStack(alignment: .leading, spacing: 10) {
                // Status Header
                HStack {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(media.isPlaying ? Color.green : Color.white.opacity(0.3))
                            .frame(width: 5, height: 5)
                        Text(media.isPlaying ? "PLAYING" : "READY")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                            .tracking(0.6)
                    }
                    
                    Spacer()
                    
                    WaveformView(
                        isPlaying: media.isPlaying,
                        color: .white,
                        barCount: 4,
                        maxHeight: 11
                    )
                }
                
                // Artwork & Title
                HStack(spacing: 10) {
                    artworkView(size: 46, cornerRadius: 10)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(media.title.isEmpty ? "No Track Playing" : media.title)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text(media.artist.isEmpty ? "—" : media.artist)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.65))
                            .lineLimit(1)
                        
                        if !media.album.isEmpty {
                            Text(media.album)
                                .font(.system(size: 9, weight: .regular))
                                .foregroundColor(.white.opacity(0.4))
                                .lineLimit(1)
                        }
                    }
                }
                
                // Compact Scrubber
                scrubberView
                
                // Controls Row
                HStack(spacing: 14) {
                    // Active Lyrics Toggle (highlighted in karaoke mode)
                    Button(action: {
                        lyrics.toggleLyrics()
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.white)
                                .frame(width: 28, height: 28)
                            
                            Image(systemName: "quote.bubble.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.black)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Tutup Tampilan Lirik")
                    
                    Spacer()
                    
                    Button(action: { media.previousTrack() }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: { media.togglePlayPause() }) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: media.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.black)
                                .offset(x: media.isPlaying ? 0 : 1)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: { media.nextTrack() }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                }
                .padding(.top, 2)
                
                Spacer(minLength: 0)
            }
            .frame(width: 260)
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 6)
            
            // VERTICAL DIVIDER
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 1)
                .padding(.vertical, 8)
            
            // RIGHT COLUMN: Synchronized Lyrics Stream
            VStack(alignment: .leading, spacing: 6) {
                // Header Bar
                HStack {
                    Text("LIVE LYRICS")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                        .tracking(1.0)
                    
                    Spacer()
                    
                    if lyrics.isLoading {
                        HStack(spacing: 5) {
                            ProgressView()
                                .scaleEffect(0.4)
                                .frame(width: 12, height: 12)
                            Text("LRCLIB...")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.white.opacity(0.45))
                        }
                    } else {
                        Button(action: {
                            lyrics.fetchLyrics(title: media.title, artist: media.artist)
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 8.5, weight: .semibold))
                                Text("Sync")
                                    .font(.system(size: 9, weight: .semibold))
                            }
                            .foregroundColor(.white.opacity(0.65))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2.5)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Muat ulang lirik")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                
                // Lyrics Content Stream
                if lyrics.isLoading && lyrics.lyrics.isEmpty {
                    VStack(spacing: 8) {
                        Spacer()
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Menghubungkan ke LRCLIB...")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if lyrics.lyrics.isEmpty {
                    VStack(spacing: 6) {
                        Spacer()
                        Image(systemName: "music.mic")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.25))
                        Text(lyrics.statusMessage ?? "Tidak ada lirik tersinkron")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.6))
                        Text("Klik 'Sync' atau putar lagu lain")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundColor(.white.opacity(0.35))
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(alignment: .leading, spacing: 12) {
                                ForEach(Array(lyrics.lyrics.enumerated()), id: \.element.id) { index, line in
                                    let isActive = index == lyrics.currentLineIndex
                                    
                                    HStack(alignment: .center, spacing: 8) {
                                        if isActive {
                                            Capsule()
                                                .fill(Color.white)
                                                .frame(width: 3, height: 16)
                                                .shadow(color: Color.white.opacity(0.8), radius: 4)
                                        }
                                        
                                        Text(line.text)
                                            .font(.system(size: isActive ? 15 : 13, weight: isActive ? .bold : .medium, design: .rounded))
                                            .foregroundColor(isActive ? .white : .white.opacity(0.36))
                                            .shadow(color: isActive ? Color.white.opacity(0.4) : Color.clear, radius: 6)
                                            .multilineTextAlignment(.leading)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .padding(.vertical, 2)
                                    .padding(.horizontal, 4)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        media.seek(to: line.time)
                                    }
                                    .id(line.id)
                                }
                            }
                            .padding(.vertical, 28)
                            .padding(.horizontal, 12)
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 6)
        }
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
                .stroke(Color.white.opacity(0.14), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 2)
    }
    
    // MARK: - Reusable Scrubber View
    
    private var scrubberView: some View {
        VStack(spacing: 3) {
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    // Track background
                    Capsule()
                        .fill(Color.white.opacity(0.18))
                        .frame(height: 3.5)
                    
                    // Active Progress Fill
                    Capsule()
                        .fill(Color.white)
                        .frame(width: max(0, min(w, w * CGFloat(progress))), height: 3.5)
                    
                    // Scrubber Handle
                    Circle()
                        .fill(Color.white)
                        .frame(width: 9, height: 9)
                        .offset(x: max(0, min(w - 9, (w * CGFloat(progress)) - 4.5)))
                        .shadow(color: Color.black.opacity(0.4), radius: 2)
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
            
            HStack {
                Text(elapsedString)
                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.55))
                
                Spacer()
                
                Text(remainingString)
                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.55))
            }
        }
    }
}


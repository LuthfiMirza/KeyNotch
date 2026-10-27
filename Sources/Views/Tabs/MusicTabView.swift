import SwiftUI

public struct MusicTabView: View {
    @ObservedObject var media = MediaRemoteService.shared
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
        VStack(spacing: 12) {
            // MARK: - Top Status Row
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
            
            // MARK: - Center Media Info Card
            HStack(spacing: 14) {
                // Album Artwork
                ZStack {
                    if let artwork = media.artwork {
                        Image(nsImage: artwork)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 58, height: 58)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 58, height: 58)
                        
                        Image(systemName: "music.note")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.45))
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 3)
                
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
            
            // MARK: - Scrubber & Timestamps
            VStack(spacing: 4) {
                GeometryReader { geo in
                    let w = geo.size.width
                    ZStack(alignment: .leading) {
                        // Track background
                        Capsule()
                            .fill(Color.white.opacity(0.18))
                            .frame(height: 4)
                        
                        // Active Progress Fill
                        Capsule()
                            .fill(Color.white)
                            .frame(width: max(0, min(w, w * CGFloat(progress))), height: 4)
                        
                        // Scrubber Handle
                        Circle()
                            .fill(Color.white)
                            .frame(width: 10, height: 10)
                            .offset(x: max(0, min(w - 10, (w * CGFloat(progress)) - 5)))
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
                .frame(height: 10)
                
                HStack {
                    Text(elapsedString)
                        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.55))
                    
                    Spacer()
                    
                    Text(remainingString)
                        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.55))
                }
            }
            .padding(.horizontal, 16)
            
            // MARK: - Playback Controls & Lyrics Toggle
            HStack(spacing: 24) {
                // Lyrics Button (Prepared for Phase C)
                Button(action: {
                    // Phase C: Toggle Synced Lyrics Split-View
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
                .help("Synced Lyrics (Phase C)")
                
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
                
                // Waveform or Spacer balance
                Color.clear
                    .frame(width: 32, height: 32)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 6)
        }
        .onAppear {
            media.refreshNowPlaying()
        }
    }
}

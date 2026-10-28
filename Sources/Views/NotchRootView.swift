import SwiftUI

public struct NotchRootView: View {
    @ObservedObject var state = IslandState.shared
    @ObservedObject var lyrics = LyricsService.shared
    
    public init() {}
    
    private var isHiddenOrFullScreen: Bool {
        state.isHidden || state.shouldHideForFullScreen
    }
    
    private var isMicroLip: Bool {
        state.isHoverPeekMode && !state.isPeeking && !state.isExpanded && state.activeHUD == nil && !isHiddenOrFullScreen
    }
    
    private var currentWidth: CGFloat {
        if isHiddenOrFullScreen { return 0 }
        if state.isExpanded {
            return (state.selectedTab == .music && lyrics.isLyricsExpanded) ? 680 : 540
        }
        if let hud = state.activeHUD {
            if hud.type == .battery {
                return 370
            } else if hud.type == .bluetooth {
                return 360
            }
            return 280
        }
        if state.isHoverPeekMode {
            return state.isPeeking ? state.notchWidth : 180
        }
        return state.notchWidth
    }
    
    private var currentHeight: CGFloat {
        if isHiddenOrFullScreen { return 0 }
        if state.isExpanded { return 282 }
        if let hud = state.activeHUD {
            if hud.type == .battery {
                return 52
            } else if hud.type == .bluetooth {
                return 48
            }
            return 46
        }
        if state.isHoverPeekMode {
            return state.isPeeking ? state.notchHeight : 4
        }
        return state.notchHeight
    }
    
    private var currentCornerRadius: CGFloat {
        if state.isExpanded { return 24 }
        if let hud = state.activeHUD {
            if hud.type == .battery {
                return 22
            } else if hud.type == .bluetooth {
                return 21
            }
            return 20
        }
        if isMicroLip { return 2 }
        return 18
    }
    
    private var currentShoulderRadius: CGFloat {
        if isMicroLip { return 0 }
        if state.isExpanded { return 9 }
        if let hud = state.activeHUD {
            if hud.type == .battery {
                return 8
            } else if hud.type == .bluetooth {
                return 7.5
            }
            return 7
        }
        return 7
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            if !isHiddenOrFullScreen {
                ZStack(alignment: .top) {
                    // Background Notch Shape with refined smooth concave shoulders & squircle corners
                    NotchShape(
                        cornerRadius: currentCornerRadius,
                        topShoulderRadius: currentShoulderRadius
                    )
                    .fill(Color.black)
                    .overlay(
                        NotchShape(
                            cornerRadius: currentCornerRadius,
                            topShoulderRadius: currentShoulderRadius
                        )
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
                        .shadow(
                            color: Color.black.opacity(state.isExpanded ? 0.5 : 0.25),
                            radius: state.isExpanded ? 18 : 6,
                            x: 0,
                            y: state.isExpanded ? 8 : 2
                        )
                    
                    // Dynamic Island Content
                    Group {
                        if isMicroLip {
                            // Empty micro lip for 0-obstruction hover peek mode
                            Color.clear
                        } else if let hud = state.activeHUD {
                            // Transient HUD Toast View
                            HUDToastView(payload: hud)
                        } else if state.isExpanded {
                            // Full Expanded State
                            expandedView
                        } else {
                            // Compact Balanced Notch View
                            CompactNotchView()
                        }
                    }
                    .frame(width: currentWidth, height: currentHeight, alignment: .top)
                    .clipped()
                }
                .frame(width: currentWidth, height: currentHeight)
                .animation(.spring(response: 0.35, dampingFraction: 0.78), value: state.isExpanded)
                .animation(.spring(response: 0.36, dampingFraction: 0.78), value: lyrics.isLyricsExpanded)
                .animation(.spring(response: 0.35, dampingFraction: 0.78), value: state.isPeeking)
                .animation(.spring(response: 0.38, dampingFraction: 0.72), value: state.activeHUD)
                .animation(.spring(response: 0.35, dampingFraction: 0.78), value: state.shouldHideForFullScreen)
            }
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    
    // MARK: - Expanded Island View
    
    private var pendingRemindersCount: Int {
        if let data = UserDefaults.standard.data(forKey: "keynotch_quick_notes"),
           let notes = try? JSONDecoder().decode([NoteItem].self, from: data) {
            let pending = notes.filter { !$0.isCompleted }.count
            return max(1, pending)
        }
        return 2
    }
    
    private var expandedView: some View {
        VStack(spacing: 12) {
            // Header Bar: Navigation Tabs + Collapse Button
            HStack(spacing: 6) {
                ForEach(IslandTab.allCases) { tab in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            state.selectedTab = tab
                        }
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: tab.iconName)
                                .font(.system(size: 10.5, weight: .semibold))
                            
                            Text(tab.rawValue)
                                .font(.system(size: 11, weight: .semibold))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                            
                            // Badge for Reminders & Shelf (Matching Reference Design)
                            if tab == .notes {
                                Text("\(pendingRemindersCount)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 4.5)
                                    .padding(.vertical, 1)
                                    .background(Color.white.opacity(0.2))
                                    .clipShape(Capsule())
                                    .fixedSize(horizontal: true, vertical: false)
                            } else if tab == .shelf {
                                Text("1")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 4.5)
                                    .padding(.vertical, 1)
                                    .background(Color.white.opacity(0.2))
                                    .clipShape(Capsule())
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                        }
                        .foregroundColor(state.selectedTab == tab ? .white : .white.opacity(0.45))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            state.selectedTab == tab
                            ? Color.white.opacity(0.15)
                            : Color.clear
                        )
                        .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Spacer(minLength: 4)
                
                // Collapse Button
                Button(action: {
                    state.collapse()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.12))
                            .frame(width: 24, height: 24)
                        
                        Image(systemName: "chevron.up")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            
            // Tab Content Container
            ZStack {
                switch state.selectedTab {
                case .controls:
                    ControlsMediaTabView()
                case .music:
                    MusicTabView()
                case .notes:
                    NotesTimerTabView()
                case .devices:
                    DevicesTabView()
                case .shelf:
                    ShelfClipboardTabView()
                }
            }
            .transition(.opacity)
            
            Spacer(minLength: 0)
        }
    }
}

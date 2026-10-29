import SwiftUI

public struct NotchRootView: View {
    @ObservedObject var state = IslandState.shared
    @ObservedObject var lyrics = LyricsService.shared
    @ObservedObject var transfer = DownloadTransferService.shared
    @ObservedObject var shelf = FileShelfService.shared
    @State private var dragOffset: CGFloat = 0
    
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
            } else if hud.type == .whatsapp {
                return 390
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
            } else if hud.type == .whatsapp {
                return 54
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
            } else if hud.type == .whatsapp {
                return 23
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
            } else if hud.type == .whatsapp {
                return 8.5
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
                    .overlay(
                        Group {
                            if let dl = transfer.primaryTransfer {
                                NotchShape(
                                    cornerRadius: currentCornerRadius,
                                    topShoulderRadius: currentShoulderRadius
                                )
                                .trim(from: 0, to: CGFloat(dl.progress))
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.18, green: 0.65, blue: 1.0),
                                            Color(red: 0.35, green: 0.85, blue: 0.95)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    style: StrokeStyle(lineWidth: 1.8, lineCap: .round)
                                )
                                .shadow(color: Color(red: 0.18, green: 0.65, blue: 1.0).opacity(0.7), radius: 3)
                                .animation(.linear(duration: 0.5), value: dl.progress)
                            }
                        }
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
                    .clipShape(
                        NotchShape(
                            cornerRadius: currentCornerRadius,
                            topShoulderRadius: currentShoulderRadius
                        )
                    )
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
    
    private var currentTabIndex: Int {
        IslandTab.allCases.firstIndex(of: state.selectedTab) ?? 0
    }
    
    private func selectTab(at index: Int) {
        state.selectTab(at: index)
    }
    
    private var inNotchTransition: AnyTransition {
        let isForward = state.slideDirection == .forward
        let delta: CGFloat = 28
        return .asymmetric(
            insertion: .modifier(
                active: TabPageTransitionModifier(offset: isForward ? delta : -delta, opacity: 0, scale: 0.98),
                identity: TabPageTransitionModifier(offset: 0, opacity: 1, scale: 1.0)
            ),
            removal: .modifier(
                active: TabPageTransitionModifier(offset: isForward ? -delta : delta, opacity: 0, scale: 0.98),
                identity: TabPageTransitionModifier(offset: 0, opacity: 1, scale: 1.0)
            )
        )
    }
    
    private var pendingRemindersCount: Int {
        if let data = UserDefaults.standard.data(forKey: "keynotch_quick_notes"),
           let notes = try? JSONDecoder().decode([NoteItem].self, from: data) {
            let pending = notes.filter { !$0.isCompleted }.count
            return max(1, pending)
        }
        return 2
    }
    
    private var expandedView: some View {
        VStack(spacing: 8) {
            // MARK: - Minimal Top Header (Tab Title, Badges, Collapse)
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: state.selectedTab.iconName)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.85))
                    
                    Text(state.selectedTab.rawValue)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                    
                    // Badges for Reminders or Active Download
                    if state.selectedTab == .notes && pendingRemindersCount > 0 {
                        Text("\(pendingRemindersCount)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.yellow)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.yellow.opacity(0.18))
                            .clipShape(Capsule())
                    } else if state.selectedTab == .shelf {
                        if let primary = transfer.primaryTransfer {
                            Text("\(primary.percentageString)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.cyan)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.cyan.opacity(0.18))
                                .clipShape(Capsule())
                        } else if !shelf.stagedFiles.isEmpty {
                            Text("\(shelf.stagedFiles.count) files")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.cyan)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.cyan.opacity(0.18))
                                .clipShape(Capsule())
                        }
                    }
                }
                
                Spacer()
                
                // Subtle Prev/Next Chevrons & Collapse Button
                HStack(spacing: 6) {
                    Button(action: {
                        if currentTabIndex > 0 {
                            selectTab(at: currentTabIndex - 1)
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundColor(currentTabIndex > 0 ? .white.opacity(0.7) : .white.opacity(0.2))
                            .frame(width: 22, height: 22)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(currentTabIndex == 0)
                    
                    Button(action: {
                        if currentTabIndex < IslandTab.allCases.count - 1 {
                            selectTab(at: currentTabIndex + 1)
                        }
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundColor(currentTabIndex < IslandTab.allCases.count - 1 ? .white.opacity(0.7) : .white.opacity(0.2))
                            .frame(width: 22, height: 22)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(currentTabIndex == IslandTab.allCases.count - 1)
                    
                    // Collapse Button
                    Button(action: {
                        state.collapse()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.12))
                                .frame(width: 22, height: 22)
                            
                            Image(systemName: "chevron.up")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 9)
            
            // MARK: - Apple In-Notch Directional Slide & Fade (100% Inside Notch)
            ZStack {
                switch state.selectedTab {
                case .controls:
                    ControlsMediaTabView()
                        .transition(inNotchTransition)
                        .id(IslandTab.controls)
                case .music:
                    MusicTabView()
                        .transition(inNotchTransition)
                        .id(IslandTab.music)
                case .notes:
                    NotesTimerTabView()
                        .transition(inNotchTransition)
                        .id(IslandTab.notes)
                case .devices:
                    DevicesTabView()
                        .transition(inNotchTransition)
                        .id(IslandTab.devices)
                case .shelf:
                    ShelfClipboardTabView()
                        .transition(inNotchTransition)
                        .id(IslandTab.shelf)
                }
            }
            .frame(height: 212, alignment: .top)
            .offset(x: dragOffset * 0.25)
            .gesture(
                DragGesture(minimumDistance: 15)
                    .onChanged { value in
                        let translation = value.translation.width
                        if (currentTabIndex == 0 && translation > 0) ||
                           (currentTabIndex == IslandTab.allCases.count - 1 && translation < 0) {
                            dragOffset = translation * 0.15
                        } else {
                            dragOffset = translation
                        }
                    }
                    .onEnded { value in
                        let threshold: CGFloat = 35
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            if value.translation.width < -threshold {
                                state.selectNextTab()
                            } else if value.translation.width > threshold {
                                state.selectPreviousTab()
                            }
                            dragOffset = 0
                        }
                    }
            )
            
            // MARK: - Bottom Dot Page Indicator (Interactive & Centered with Bottom Padding)
            HStack(spacing: 7) {
                ForEach(0..<IslandTab.allCases.count, id: \.self) { index in
                    let isSelected = currentTabIndex == index
                    Button(action: {
                        selectTab(at: index)
                    }) {
                        ZStack {
                            if isSelected {
                                Capsule()
                                    .fill(Color.white)
                                    .frame(width: 18, height: 5.5)
                                    .shadow(color: Color.white.opacity(0.4), radius: 2)
                            } else {
                                Circle()
                                    .fill(Color.white.opacity(0.28))
                                    .frame(width: 5.5, height: 5.5)
                            }
                        }
                        .contentShape(Rectangle().size(width: 22, height: 16))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(IslandTab.allCases[index].rawValue)
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 10)
        }
    }
}

// MARK: - In-Notch Fluid Transition Modifier
public struct TabPageTransitionModifier: ViewModifier {
    public let offset: CGFloat
    public let opacity: Double
    public let scale: CGFloat
    
    public init(offset: CGFloat, opacity: Double, scale: CGFloat) {
        self.offset = offset
        self.opacity = opacity
        self.scale = scale
    }
    
    public func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .opacity(opacity)
            .scaleEffect(scale)
    }
}


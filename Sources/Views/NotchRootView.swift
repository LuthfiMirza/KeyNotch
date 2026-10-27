import SwiftUI

public struct NotchRootView: View {
    @ObservedObject var state = IslandState.shared
    
    public init() {}
    
    private var isHiddenOrFullScreen: Bool {
        state.isHidden || state.shouldHideForFullScreen
    }
    
    private var isMicroLip: Bool {
        state.isHoverPeekMode && !state.isPeeking && !state.isExpanded && state.activeHUD == nil && !isHiddenOrFullScreen
    }
    
    private var currentWidth: CGFloat {
        if isHiddenOrFullScreen { return 0 }
        if state.isExpanded { return 520 }
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
        if state.isExpanded { return 240 }
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
                .animation(.spring(response: 0.35, dampingFraction: 0.78), value: state.isPeeking)
                .animation(.spring(response: 0.38, dampingFraction: 0.72), value: state.activeHUD)
                .animation(.spring(response: 0.35, dampingFraction: 0.78), value: state.shouldHideForFullScreen)
            }
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    
    // MARK: - Expanded Island View
    
    private var expandedView: some View {
        VStack(spacing: 12) {
            // Header Bar: Navigation Tabs + Collapse Button
            HStack(spacing: 8) {
                ForEach(IslandTab.allCases) { tab in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            state.selectedTab = tab
                        }
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: tab.iconName)
                                .font(.system(size: 11, weight: .semibold))
                            Text(tab.rawValue)
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(state.selectedTab == tab ? .white : .white.opacity(0.45))
                        .padding(.horizontal, 10)
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
                
                Spacer()
                
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
            .padding(.horizontal, 16)
            .padding(.top, 10)
            
            // Tab Content Container
            ZStack {
                switch state.selectedTab {
                case .controls:
                    ControlsMediaTabView()
                case .shelf:
                    ShelfClipboardTabView()
                case .notes:
                    NotesTimerTabView()
                case .market:
                    MarketTabView()
                }
            }
            .transition(.opacity)
            
            Spacer(minLength: 0)
        }
    }
}

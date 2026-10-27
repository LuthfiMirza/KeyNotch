# PRD: KeyNotch — Native All-in-One Dynamic Island for macOS

## 1. Product Vision & Goals
Build a super-lightweight (~2 MB binary, ~0.0% idle CPU), native macOS Dynamic Island application written purely in Swift, AppKit, and SwiftUI. It compiles directly via Apple Command Line Tools (`swiftc`) without requiring a full Xcode installation.

## 2. Target Technical Specifications
- **Minimum OS**: macOS 12.0 Monterey (compatible up to Sonoma & Sequoia).
- **Architecture**: Universal (`arm64` & `x86_64`).
- **Build System**: Shell script (`build.sh`) + VS Code / AG IDE `tasks.json`.
- **App Bundle Type**: Agent App (`LSUIElement = YES` in `Info.plist`, hides Dock icon, lives in Notch + Menu Bar Tray `🏝️`).

## 3. Window Geometry & States
1. **Flush Bezel Alignment (0-Pixel Gap) & Tangential Concave Fillet**:
   - Pinned to the exact top-center of `NSScreen.main`.
   - Top edge is flat (`0px` gap from top screen bezel); top shoulder transitions use cubic Bézier concave fillets with tangential continuity ($dy/dx = 0$ at bezel, $dx/dy = 0$ at side wall) to eliminate sharp horn creases.
   - Bottom corners use continuous squircle curvature (`NotchShape`).
2. **Interactive States**:
   - **Micro-Lip State (Hover Peek Mode - Idle)**: `180px × 4px` subtle lip flush to top bezel. Zero obstruction to browser tabs or window title bars.
   - **Compact Notch State (Always Visible - Idle)**: `210px × 36px` sleek pill displaying Dead-Center Clock, mini status glyph, or active audio mini-waveform.
   - **Full Screen Auto-Hide State**: Notch collapses to `0px × 0px` when a native macOS Full Screen app is active, allowing full video immersion. Hovering within 4px of the top edge temporarily reveals the island with spring animation.
   - **Expanded Island State (Active)**: `520px × 278px` (animated with iOS spring physics) featuring navigation tabs:
     - **Tab 1: Media & Controls** (Now Playing, System Stats, iOS Control Center, Caffeinate, Dev Ports, Color Picker).
     - **Tab 2: Shelf & Clipboard** (File Drop Zone, Quick Image Converter/OCR, Clipboard History).
     - **Tab 3: Focus & Notes** (Quick Notes/Reminders with checkboxes, Pomodoro Timer).
     - **Tab 4: Market & Crypto** (Live USD/IDR, BTC, ETH, BBCA, AAPL, NVDA with category filters, live quotes & pin to compact notch).
   - **HUD Toast State (Transient Morphing Capsules)**:
     - **⚡ MagSafe / Charging Capsule**: Expands into an enlarged `370px × 52px` morphing capsule with glowing neon green battery ring, pulsing lightning bolt, bold status typography, and crisp `22pt` battery percentage.
     - **🎧 Bluetooth Connect Capsule**: Expands into an elegant `360px × 48px` capsule with glowing blue ring, Bluetooth rune, device name, and animated audio badge.
     - **Standard Capsule**: `280px × 46px` for Volume, Brightness, Caps Lock, and Quick Toast notifications.

## 4. Functional Requirements (18 Core Modules)
1. **Notch Geometry & Multi-Monitor**: Auto-center on main display, handle screen resolution/space changes (`NSApplication.didChangeScreenParametersNotification`).
2. **Smart Hover Peek & Click Pass-Through**: Dynamic tracking area; transparent padding around the notch passes mouse clicks to underlying windows (`ignoresMouseEvents` toggling based on cursor path within `NotchShape`).
3. **Universal Media Controller**: Dynamic `dlopen` interface to `MediaRemote.framework` for Title, Artist, Album Art, Playback State, and Play/Pause/Next/Prev commands + reactive animated waveform.
4. **Battery & MagSafe HUD**: `IOKit.ps` observer triggering charging animation when AC power state changes.
5. **Global Hotkey (`Option + Space`)**: Carbon `RegisterEventHotKey` to toggle expand/collapse globally.
6. **Mach Kernel CPU & RAM Monitor & Network Radar**: `host_statistics64` for live CPU % and RAM GB/percentage, plus BSD socket `getifaddrs` for real-time Download/Upload speeds and zero-overhead TCP socket ping latency radar (active only when expanded or enabled in compact notch).
7. **Caffeinate Toggle**: `IOPMAssertionCreateWithName` (`kIOPMAssertionTypePreventUserIdleDisplaySleep`) toggleable with 1 click.
8. **Floating Caps Lock HUD**: `NSEvent.flagsChanged` monitor detecting `.capsLock` state toggles.
9. **System Volume HUD**: Intercept or monitor media keys / system output volume (`AudioToolbox` / `NSSound`) to display sleek iOS volume capsule.
10. **iOS Control Center**: Wi-Fi status + SSID (`CoreWLAN`), Bluetooth status, Focus indicator, and interactive volume capsule slider.
11. **Plain-Text Sanitizer & Sequential Paste Queue**: Track copied snippets with zero CPU polling (Cmd+C/Cmd+X event monitor). Auto-sanitize rich-text and HTML formatting into pure text. Support multi-snippet staging via **Sequential Paste Queue (Stack)** with global hotkey `Option + Shift + V` to sequentially pop and prime each snippet into pasteboard.
12. **File Shelf (Drag & Drop)**: Accept file URLs dragged to the top screen edge, store in temporary staging shelf, support dragging back out to any app.
13. **Quick Action File Converter & OCR**: Inside File Shelf, provide 1-click buttons on staged images to Convert (`PNG`/`JPG`/`WebP`), Compress, or Copy OCR Text (`Vision`).
14. **Quick Notes & Reminders**: Add/check/delete tasks persisted in `UserDefaults` with full keyboard focus inside `NSPanel`.
15. **Focus / Pomodoro Timer**: `25m` / `5m` / `15m` countdown timer with `SF Pro Rounded` digits and compact progress indicator.
16. **Dev Port Monitor & Color Picker**: Scan common dev ports (`3000`, `5173`, `8000`, `8080`) with `lsof` / socket check (on-demand when tab opens) + 1-click Open/Kill, plus `NSColorSampler` screen color picker that copies HEX to clipboard.
17. **Full Screen Auto-Hide & Hover Reveal**: Event-driven workspace space changes monitor (`NSWorkspace.activeSpaceDidChangeNotification`) and frontmost window bounds detector to auto-hide in full-screen games/media with zero CPU overhead.
18. **Menu Bar Tray Icon (`🏝️`)**: Left-click toggles expand/collapse; Right-click opens context menu (Toggle Hover Peek Mode, Full Screen Auto-Hide, Caffeinate, Hide/Show, Test HUDs, Quit).

## 5. Directory Structure
```text
KeyNotch/
├── PRD.md
├── README.md
├── build.sh
├── .vscode/
│   └── tasks.json
└── Sources/
    ├── main.swift
    ├── AppDelegate.swift
    ├── Window/
    │   ├── NotchPanel.swift
    │   ├── NotchWindowController.swift
    │   └── NotchShape.swift
    ├── State/
    │   └── IslandState.swift
    ├── Services/
    │   ├── MediaRemoteService.swift
    │   ├── SystemTelemetryService.swift
    │   ├── BatteryService.swift
    │   ├── HotKeyService.swift
    │   ├── CaffeinateService.swift
    │   ├── ClipboardService.swift
    │   ├── HUDInterceptorService.swift
    │   ├── MicrophoneService.swift
    │   ├── NetworkMonitorService.swift
    │   ├── MarketTickerService.swift
    │   ├── FileConverterService.swift
    │   └── DevToolsService.swift
    └── Views/
        ├── NotchRootView.swift
        ├── CompactNotchView.swift
        ├── HUDToastView.swift
        ├── Tabs/
        │   ├── ControlsMediaTabView.swift
        │   ├── ShelfClipboardTabView.swift
        │   ├── NotesTimerTabView.swift
        │   └── MarketTabView.swift
        └── Components/
            ├── WaveformView.swift
            └── CapsuleSliderView.swift
# PRD: KeyNotch — Native All-in-One Dynamic Island for macOS

## 1. Product Vision & Goals
Build a super-lightweight (~2 MB binary, ~0.0% idle CPU), native macOS Dynamic Island application written purely in Swift, AppKit, and SwiftUI. It compiles directly via Apple Command Line Tools (`swiftc`) without requiring a full Xcode installation.

## 2. Target Technical Specifications
- **Minimum OS**: macOS 12.0 Monterey (compatible up to Sonoma & Sequoia).
- **Architecture**: Universal (`arm64` & `x86_64`).
- **Build System**: Shell script (`build.sh`) + VS Code / AG IDE `tasks.json`.
- **App Bundle Type**: Agent App (`LSUIElement = YES` in `Info.plist`, hides Dock icon, lives in Notch + Menu Bar Tray `🏝️`).

## 3. Window Geometry & States
1. **Flush Bezel Alignment (0-Pixel Gap)**:
   - Pinned to the exact top-center of `NSScreen.main`.
   - Top edge is flat (`0px` gap from top screen bezel); bottom corners use continuous squircle curvature (`NotchShape`).
2. **Three Interactive States**:
   - **Micro-Lip State (Hover Peek Mode - Idle)**: `180px × 4px` subtle lip flush to top bezel. Zero obstruction to browser tabs or window title bars.
   - **Compact Notch State (Always Visible - Idle)**: `210px × 32px` sleek pill displaying Dead-Center Clock, mini status glyph, or active audio mini-waveform.
   - **Expanded Island State (Active)**: `520px × 230px` (animated with iOS spring physics) featuring navigation tabs:
     - **Tab 1: Media & Controls** (Now Playing, System Stats, iOS Control Center, Caffeinate, Dev Ports, Color Picker).
     - **Tab 2: Shelf & Clipboard** (File Drop Zone, Quick Image Converter/OCR, Clipboard History).
     - **Tab 3: Focus & Notes** (Quick Notes/Reminders with checkboxes, Pomodoro Timer).
   - **HUD Toast State (Transient)**: `280px × 46px` floating capsule for Volume, Brightness, Caps Lock (`1.4s` auto-dismiss), and MagSafe Charging.

## 4. Functional Requirements (17 Core Modules)
1. **Notch Geometry & Multi-Monitor**: Auto-center on main display, handle screen resolution/space changes (`NSApplication.didChangeScreenParametersNotification`).
2. **Smart Hover Peek & Click Pass-Through**: Dynamic tracking area; transparent padding around the notch passes mouse clicks to underlying windows (`ignoresMouseEvents` toggling based on cursor path within `NotchShape`).
3. **Universal Media Controller**: Dynamic `dlopen` interface to `MediaRemote.framework` for Title, Artist, Album Art, Playback State, and Play/Pause/Next/Prev commands + reactive animated waveform.
4. **Battery & MagSafe HUD**: `IOKit.ps` observer triggering charging animation when AC power state changes.
5. **Global Hotkey (`Option + Space`)**: Carbon `RegisterEventHotKey` to toggle expand/collapse globally.
6. **Mach Kernel CPU & RAM Monitor**: `host_statistics64` for live CPU % and RAM GB/percentage (active only when expanded).
7. **Caffeinate Toggle**: `IOPMAssertionCreateWithName` (`kIOPMAssertionTypePreventUserIdleDisplaySleep`) toggleable with 1 click.
8. **Floating Caps Lock HUD**: `NSEvent.flagsChanged` monitor detecting `.capsLock` state toggles.
9. **System Volume HUD**: Intercept or monitor media keys / system output volume (`AudioToolbox` / `NSSound`) to display sleek iOS volume capsule.
10. **iOS Control Center**: Wi-Fi status + SSID (`CoreWLAN`), Bluetooth status, Focus indicator, and interactive volume capsule slider.
11. **Clipboard History**: Track text/hex/URL strings from `NSPasteboard.general` (up to 15 items) with 1-click re-copy and checkmark feedback.
12. **File Shelf (Drag & Drop)**: Accept file URLs dragged to the top screen edge, store in temporary staging shelf, support dragging back out to any app.
13. **Quick Action File Converter & OCR**: Inside File Shelf, provide 1-click buttons on staged images to Convert (`PNG`/`JPG`/`WebP`), Compress, or Copy OCR Text (`Vision`).
14. **Quick Notes & Reminders**: Add/check/delete tasks persisted in `UserDefaults` with full keyboard focus inside `NSPanel`.
15. **Focus / Pomodoro Timer**: `25m` / `5m` / `15m` countdown timer with `SF Pro Rounded` digits and compact progress indicator.
16. **Dev Port Monitor & Color Picker**: Scan common dev ports (`3000`, `5173`, `8000`, `8080`) with `lsof` / socket check (on-demand when tab opens) + 1-click Open/Kill, plus `NSColorSampler` screen color picker that copies HEX to clipboard.
17. **Menu Bar Tray Icon (`🏝️`)**: Left-click toggles expand/collapse; Right-click opens context menu (Toggle Hover Peek Mode, Expand/Collapse, Hide/Show, Quit).

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
    │   ├── FileConverterService.swift
    │   └── DevToolsService.swift
    └── Views/
        ├── NotchRootView.swift
        ├── CompactNotchView.swift
        ├── HUDToastView.swift
        ├── Tabs/
        │   ├── ControlsMediaTabView.swift
        │   ├── ShelfClipboardTabView.swift
        │   └── NotesTimerTabView.swift
        └── Components/
            ├── WaveformView.swift
            └── CapsuleSliderView.swift
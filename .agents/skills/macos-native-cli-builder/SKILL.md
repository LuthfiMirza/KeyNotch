---
name: macos-native-cli-builder
description: Expert in building standalone, zero-dependency macOS native apps (Swift + AppKit + SwiftUI) compiled purely via Command Line Tools (swiftc) and bash scripts without Xcode. Use this whenever developing, compiling, or optimizing macOS menu bar, notch, dynamic island, or system utility applications without xcodeproj.
---

# Rules for macOS Native CLI Development:
1. **NO XCODEPROJ**: Never generate `.xcodeproj` or `.xcworkspace`. All code must live in modular `.swift` files inside `Sources/` and compile into a valid `.app` bundle via `build.sh` using `swiftc`.
2. **PRIVATE FRAMEWORKS**: Always access `MediaRemote.framework` dynamically at runtime using `dlopen` and `dlsym` (`@convention(c)` function pointers) so `swiftc` compiles cleanly with standard Command Line Tools.
3. **ZERO-OBSTRUCTION WINDOW**: Use a custom `NSPanel` subclass with `.borderless` and `.nonactivatingPanel`. Override `canBecomeKey` and `canBecomeMain` to return `true` only when text input (Notes) is active. Implement custom hit-testing (`ignoresMouseEvents`) so transparent areas around the notch pass clicks straight through to Chrome/Safari/Arc tabs below.
4. **PERFORMANCE**: Idle CPU usage must remain ~0.0%. Pause timers, waveform animations, and Mach kernel telemetry polling (`host_statistics64`) whenever the Dynamic Island is collapsed or in Hover Peek micro-lip state.
5. **MACOS COMPATIBILITY**: Target macOS 12.0+ (`-target arm64-apple-macos12.0` / `-target x86_64-apple-macos12.0`). Avoid macOS 14/15-only SwiftUI APIs without `@available` fallbacks.

---

## Technical Stack & Framework Guidelines

### 1. AppKit (Cocoa) — Window & Event Foundation
- **Window Management**: `NSPanel` with `.borderless`, `.nonactivatingPanel`, and level `.mainMenu + 1` (or `CGWindowLevelForKey(.statusWindow)`).
- **Screen Geometry**: `NSScreen` to read coordinates, screen dimensions, and detect physical camera notch (`safeAreaInsets`, `auxiliaryTopLeftArea`, `auxiliaryTopRightArea`) or virtual notch fallback for external displays / Intel Macs.
- **Event Monitoring**:
  - `NSEvent.addGlobalMonitorForEvents` & `NSEvent.addLocalMonitorForEvents` to detect hover, clicks outside notch, file drag-and-drop, F11/F12 key presses, and Caps Lock toggle.
- **Pasteboard & Color Picker**:
  - `NSPasteboard` event-driven polling (`changeCount` check only on focus/interval when active).
  - `NSColorSampler` for native macOS screen color picking.

### 2. SwiftUI — Visual & Animation Layer
- **Hosting**: `NSHostingView` hosted cleanly inside the custom `NSPanel`.
- **Notch Shape**: Custom `Shape` (`NotchShape`) with squircle curves on bottom corners and 0px gap at the top screen edge.
- **Fluid Animation**: `.spring(response: 0.35, dampingFraction: 0.78)` for authentic iOS Dynamic Island transitions.

### 3. Low-Level C / Darwin & Dynamic Linking (dlopen)
- **MediaRemote via dlopen**:
  ```swift
  let handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW)
  // Resolve Now Playing & playback controls via dlsym + @convention(c)
  ```
  *Never link via `-framework MediaRemote` directly in CLI builds.*
- **Power & Battery (IOKit)**:
  - Event-driven battery and MagSafe monitoring with `IOPSNotificationCreateRunLoopSource`.
  - Caffeinate / keep-awake assertions using `IOPMAssertionCreateWithName`.
- **Mach Kernel Telemetry**:
  - Use `host_statistics64` (`HOST_CPU_LOAD_INFO` and `HOST_VM_INFO64`) for instant CPU user/system/idle ticks and RAM calculation (Wired + Active + Compressed) with near 0% CPU overhead.
- **Carbon Global Hotkeys**:
  - Global shortcut `Option + Space` via `RegisterEventHotKey` without requiring Accessibility/Screen Recording permissions.

### 4. Vision & ImageIO Framework
- **Fast Image Conversion**: `CGImageSource` and `CGImageDestination` for rapid lossless/lossy conversions (PNG, JPG, WebP, HEIC).
- **Quick OCR**: `VNRecognizeTextRequest` (`Vision.framework`) for text recognition on images dropped into the shelf.

---

## Standard Project Structure
```text
KeyNotch/
├── .agents/
│   └── skills/
│       └── macos-native-cli-builder/
│           └── SKILL.md
├── AGENTS.md
├── build.sh
├── Sources/
│   ├── App/
│   ├── Core/
│   ├── UI/
│   └── Utils/
└── Resources/
```

# Rules for macOS Native CLI Development (KeyNotch)

## Mandatory Constraints:
1. **NO XCODEPROJ**: Never generate `.xcodeproj` or `.xcworkspace`. All code must live in modular `.swift` files inside `Sources/` and compile into a valid `.app` bundle via `build.sh` using `swiftc`.
2. **PRIVATE FRAMEWORKS**: Always access `MediaRemote.framework` dynamically at runtime using `dlopen` and `dlsym` (`@convention(c)` function pointers) so `swiftc` compiles cleanly with standard Command Line Tools. Never link statically via `-framework MediaRemote`.
3. **ZERO-OBSTRUCTION WINDOW**: Use a custom `NSPanel` subclass with `.borderless` and `.nonactivatingPanel`. Level `.mainMenu + 1` or `CGWindowLevelForKey(.statusWindow)`. Override `canBecomeKey` and `canBecomeMain` to return `true` only when text input (Notes) is active. Implement custom hit-testing (`ignoresMouseEvents`) so transparent areas around the notch pass clicks straight through to Chrome/Safari/Arc tabs below.
4. **PERFORMANCE**: Idle CPU usage must remain ~0.0%. Pause timers, waveform animations, and Mach kernel telemetry polling (`host_statistics64`) whenever the Dynamic Island is collapsed or in Hover Peek micro-lip state.
5. **MACOS COMPATIBILITY**: Target macOS 12.0+ (`-target arm64-apple-macos12.0` / `-target x86_64-apple-macos12.0`). Avoid macOS 14/15-only SwiftUI APIs without `@available` fallbacks.

## Architecture & Framework Stack:
- **AppKit (Cocoa)**:
  - `NSPanel` (.borderless, .nonactivatingPanel, .mainMenu + 1).
  - `NSScreen` for physical notch & virtual notch coordinates on external/Intel displays.
  - `NSEvent.addGlobalMonitorForEvents` & `addLocalMonitorForEvents` for hover, outside clicks, file drag, F11/F12, Caps Lock.
  - `NSPasteboard` (event-driven changeCount check) & `NSColorSampler` (native color picker).
- **SwiftUI**:
  - `NSHostingView` inside `NSPanel`.
  - `NotchShape` with squircle bottom corners and 0px top gap.
  - Fluid spring animation `.spring(response: 0.35, dampingFraction: 0.78)`.
- **Low-Level Darwin / C**:
  - `MediaRemote` via `dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW)` & `dlsym`.
  - `IOKit.ps` & `IOPMLib` for battery/MagSafe notifications & Caffeinate assertion.
  - `host_statistics64` (Mach kernel) for 0% CPU & physical RAM metrics.
  - Carbon `RegisterEventHotKey` for global Option + Space hotkey without Accessibility permission dialogs.
- **Vision & ImageIO**:
  - `CGImageSource` & `CGImageDestination` for instant conversion (PNG, JPG, WebP, HEIC).
  - `VNRecognizeTextRequest` (`Vision.framework`) for Quick OCR from dropped images.

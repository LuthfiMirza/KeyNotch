---
name: macos-native-cli
description: Expert in building standalone, zero-dependency macOS native apps (Swift + AppKit + SwiftUI) compiled purely via Command Line Tools (swiftc) and bash scripts without Xcode.
---

# Rules for macOS Native CLI Development:
1. NO XCODEPROJ: Never generate `.xcodeproj` or `.xcworkspace`. All code must live in modular `.swift` files inside `Sources/` and compile into a valid `.app` bundle via `build.sh` using `swiftc`.
2. PRIVATE FRAMEWORKS: Always access `MediaRemote.framework` dynamically at runtime using `dlopen` and `dlsym` (`@convention(c)` function pointers) so `swiftc` compiles cleanly with standard Command Line Tools.
3. ZERO-OBSTRUCTION WINDOW: Use a custom `NSPanel` subclass with `.borderless` and `.nonactivatingPanel`. Override `canBecomeKey` and `canBecomeMain` to return `true` only when text input (Notes) is active. Implement custom hit-testing (`ignoresMouseEvents`) so transparent areas around the notch pass clicks straight through to Chrome/Safari/Arc tabs below.
4. PERFORMANCE: Idle CPU usage must remain ~0.0%. Pause timers, waveform animations, and Mach kernel telemetry polling (`host_statistics64`) whenever the Dynamic Island is collapsed or in Hover Peek micro-lip state.
5. MACOS COMPATIBILITY: Target macOS 12.0+ (`-target arm64-apple-macos12.0` / `-target x86_64-apple-macos12.0`). Avoid macOS 14/15-only SwiftUI APIs without `@available` fallbacks.

## Technical Foundation & Framework Requirements:
- **AppKit**: NSPanel (.borderless, .nonactivatingPanel, level .mainMenu + 1), NSScreen (notch & virtual notch coordinate reading), NSEvent monitors (global & local), NSPasteboard, NSColorSampler.
- **SwiftUI**: NSHostingView inside NSPanel, NotchShape with squircle bottom corners and 0px top gap, .spring(response: 0.35, dampingFraction: 0.78) animation.
- **Low-Level C / Darwin**: dlopen for MediaRemote.framework, IOKit.ps & IOPMLib for power/caffeinate, Mach Kernel host_statistics64 for 0% CPU & RAM metrics, Carbon RegisterEventHotKey for Option + Space global hotkey.
- **Vision & ImageIO**: CGImageSource/CGImageDestination for conversion/compression, VNRecognizeTextRequest for OCR.

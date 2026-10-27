# 🏝️ KeyNotch — Native All-in-One Dynamic Island for macOS (Monterey 12+)

A lightweight, battery-friendly (idle CPU ~0.0%) native Dynamic Island & living notch powerhouse for macOS. Built entirely with **Swift, AppKit, and SwiftUI** — no bloated Xcode installation required (~700 MB Command Line Tools is all you need).

Designed as a zero-obstruction command center that blends hardware telemetry, media controls, file staging, and developer utilities directly into your MacBook bezel.

---

## ✨ Key Features

### 🖥️ Core Notch & Display Engine
1. **📱 MacBook Hardware Notch Design (Flush to Bezel):**
   - **0-Pixel Gap & Tangential Concave Fillet**: Sits seamlessly flush against the top physical bezel of your display. Features mathematically continuous ($C^1$) cubic Bézier concave shoulders entering tangentially into the bezel without sharp creases or winged horns.
   - Squircles with continuous curvature at the bottom corners.
   - Specular bottom and side rim outline while merging natively into the black screen bezel at the top.

2. **🎬 Auto-Hide in Full Screen Apps:**
   - Automatically hides the notch when an application enters macOS native Full Screen mode (e.g. YouTube, VLC, Netflix, full-screen games, or browser full-screen spaces) so videos and content remain 100% immersive.
   - **Hover Reveal**: Move the cursor to the top screen edge to peek and access the island at any time.
   - **HUD Toast Pass-Through**: Volume, Brightness, Charging, and Bluetooth HUD alerts smoothly slide down and auto-retract even in full-screen mode.
   - Toggleable directly from the menu bar tray context menu.

3. **👀 Smart Hover Peek Mode (Zero Screen Obstruction):**
   - Keeps your screen, window title bars, and browser tabs (Google Chrome, Safari, Arc) 100% clean and unobstructed.
   - In idle mode, tucks into a subtle micro-notch lip (`4px`) attached to the top bezel.
   - Moves down smoothly with iOS spring physics when you peek at the top ceiling of the screen, and auto-retracts when your cursor moves away.
   - Toggleable anytime via the menu bar icon (**Hover Peek Mode** vs **Always Visible**).

4. **🖥️ Multi-Monitor & Virtual Notch Adaptive:**
   - Automatically detects physical notch geometry on Apple Silicon MacBooks while gracefully rendering a virtual centered island on Intel MacBooks and external monitors (`NSScreen` dynamic geometry).

---

### 🎵 Media, System HUDs & Hardware Telemetry
4. **🎵 Universal Now Playing & Media Controller:**
   - Directly interfaces with macOS private `MediaRemote.framework`.
   - Automatically captures playback from **Spotify, Apple Music, YouTube (Chrome, Safari, Arc, Brave, Edge), Netflix, VLC, Podcasts**, and more.
   - Displays real-time album artwork, live playback status, seek bar, and animated reactive equalizer waveform.
   - Global media controls: Play/Pause, Next Track, and Previous Track.

5. **🔋 Battery & MagSafe Charging HUD:**
   - Real-time battery status monitoring directly via native `IOKit.ps` (0% CPU impact).
   - Instant animated charging HUD when connecting/disconnecting MagSafe or power adapter.
   - Displays exact battery percentage with color-coded battery health indicator.

6. **🔊 Modern System Volume & Brightness HUD:**
   - Replaces the bulky legacy macOS bezel overlays with a sleek, iOS-style animated capsule triggered by keyboard media keys (`F11`/`F12` & Brightness keys).

7. **⇪ Floating Caps Lock HUD Indicator:**
   - Clean, unobtrusive floating pill notification whenever Caps Lock is turned On or Off.
   - Auto-dismisses after 1.4 seconds with fluid spring animation.

8. **📊 Real-Time Mini System Stats (CPU & RAM Monitor):**
   - Real-time Mach kernel hardware telemetry (`host_statistics64`) integrated into the Controls tab.
   - Live CPU load percentage and physical RAM usage meter (e.g., `5.2 GB / 16.0 GB`).

---

### 🗂️ Productivity, Shelf & Quick Actions
9. **📁 File Shelf (Drag & Drop Staging Area):**
   - Auto-expands when dragging files toward the top edge of the screen.
   - Temporary staging area for files, images, and text from Desktop/Finder with native macOS preview icons and multi-file drag-out support across spaces.

10. **⚡ Instant Drop-Zone Actions (Image & File Converter):**
    - Built-in quick action pills inside the File Shelf: one-click image compression, instant format conversion (`PNG` ⇄ `WebP` / `JPG`), and quick text extraction (OCR) via macOS native `Vision.framework`.

11. **📋 Quick Clipboard History (Shelf Tab):**
    - Built-in clipboard manager seamlessly integrated into the Shelf tab (`Files Shelf` | `Clipboard`).
    - Automatically records copied text snippets, URLs, and Hex color codes without polling overhead.
    - Single-click to re-copy any previous snippet back to your pasteboard with instant visual checkmark feedback.

12. **📝 Quick Notes & Reminders:**
    - Instant task entry with a dedicated **"Add"** button or pressing `Enter` with full keyboard focus inside floating panels.
    - Interactive iOS Reminders-style circular checkboxes with strikethrough animations.
    - Persistent local storage using `UserDefaults`.

13. **⏱️ Focus / Pomodoro Timer:**
    - Digital countdown with **SF Pro Rounded** typography and persistent compact progress ring on the notch edge.
    - Instant presets: 25 minutes (Pomodoro), 5 minutes (Short Break), 15 minutes (Long Break).

---

### 🛠️ Developer & Power-User Utilities
14. **🌐 Localhost & Dev Port Monitor:**
    - Lightweight background socket scanner in the Controls/Dev tab that detects active local development servers (e.g., `:3000`, `:5173`, `:8000`, `:8080`).
    - One-click actions to open the running port in your browser or terminate stuck processes (`kill -9`).

15. **🎨 Quick Screen Color Picker & Camera Mirror:**
    - **Native Loupe**: Pick any pixel color on screen (`NSColorSampler`) and automatically copy its `HEX` / `RGB` / `Tailwind` value to the clipboard.
    - **Webcam Peek**: Instant 1-click camera mirror preview inside the notch to check framing before joining a video call.

16. **🎛️ iOS-Style Control Center & Caffeinate:**
    - **Caffeinate Toggle**: One-click native power management assertion (`IOPMAssertionCreateWithName`) to keep your Mac awake during builds, renders, or downloads.
    - Quick status and toggles for **Wi-Fi** (with SSID detection), **Bluetooth**, **Focus / DND**, and an interactive iOS capsule volume scrubber.

17. **⌨️ Global Keyboard Shortcut (`Option + Space`) & Smart Pass-Through:**
    - Toggle expand/collapse instantly from anywhere across macOS using Carbon `RegisterEventHotKey` without invasive accessibility permissions.
    - **Dead-Center Balanced Clock**: Mathematically and optically aligned time indicator.
    - **Smart Click Pass-Through**: Transparent areas around the notch let mouse clicks pass straight through to underlying windows.
    - **Menu Bar Tray Icon (🏝️)**: Left-click to toggle Island; Right-click for quick preferences (**Hover Peek Mode**, Hide Island, Quit).

---

## 🛠️ System Requirements & Build Specs

- **Operating System**: macOS 12 Monterey or later (Ventura, Sonoma, Sequoia supported).
- **Architecture**: Universal — Intel (`x86_64`) & Apple Silicon (`arm64`).
- **Binary Footprint**: Standalone **~2.0 MB** (Zero third-party dependencies / No Electron / Pure Native).
- **Toolchain**: Apple Command Line Tools (`xcode-select --install`).

---

## 🚀 Getting Started

1. Clone the repository:
   ```bash
   git clone [https://github.com/LuthfiMirza/KeyNotch.git](https://github.com/LuthfiMirza/KeyNotch.git)
   cd KeyNotch
# 🏝️ KeyNotch — Native All-in-One Dynamic Island for macOS (Monterey 12+)

A hyper-optimized, battery-friendly (idle CPU **0.0%**, RAM **~24 MB**, binary footprint **752 KB**) native Dynamic Island & living notch powerhouse for macOS. Built entirely with **Swift, AppKit, SwiftUI, and Metal** — compiled purely via Command Line Tools (`swiftc -Osize -dead_strip`) without requiring an Xcode installation.

Engineered with a **True Zero-Draw** architecture: WindowServer compositing cuts to zero when hidden, clock ticks sync to exact minute boundaries (1x/min wakeups), audio waveforms are rendered directly on the Metal GPU layer without CPU polling, and media artwork bitmaps are automatically purged when inactive.

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

5. **🔋 Battery & MagSafe Charging HUD (Enlarged Morphing Capsule):**
   - Real-time battery status monitoring directly via native `IOKit.ps` (0% CPU impact).
   - **Enlarged Morphing Capsule (`370px × 52px`)**: Plugs into charger and expands dynamically from the notch with signature Apple fluid spring bounce (`response: 0.38, dampingFraction: 0.72`), featuring a vibrant neon green progress ring, bold status typography, and crisp `22pt` battery percentage before auto-retracting.
   - Also supports **🎧 Bluetooth Connect Capsule (`360px × 48px`)** for AirPods, Bluetooth headphones, and peripheral connection alerts.

6. **🔊 Modern System Volume & Brightness HUD:**
   - Replaces the bulky legacy macOS bezel overlays with a sleek, iOS-style animated capsule triggered by keyboard media keys (`F11`/`F12` & Brightness keys).

7. **⇪ Floating Caps Lock HUD Indicator:**
   - Clean, unobtrusive floating pill notification whenever Caps Lock is turned On or Off.
   - Auto-dismisses after 1.4 seconds with fluid spring animation.

8. **🎙️ Privacy Meeting Radar & Global Mic Mute:**
   - Real-time CoreAudio monitoring (`AudioObjectAddPropertyListener`) that detects when any app (Google Meet, Zoom, Slack, browser calls) accesses the microphone.
   - Shows an amber privacy dot/badge on the compact notch.
   - **1-Click Global Mute**: Tap the mic badge in the notch or Control Center pill (or press `Option + Shift + M`) to instantly mute/unmute the system input device with animated HUD feedback.

9. **📊 Real-Time Mini System Stats (CPU & RAM Monitor):**
   - Real-time Mach kernel hardware telemetry (`host_statistics64`) integrated into the Controls tab.
   - Live CPU load percentage and physical RAM usage meter (e.g., `5.2 GB / 16.0 GB`).

10. **🌐 Real-Time Internet Speedometer & Ping Latency Radar:**
    - Real-time BSD socket network interface monitoring (`getifaddrs`) measuring live Download (⬇️) and Upload (⬆️) speeds with counter wrap-around handling.
    - **Native TCP Ping Radar**: Measures latency to DNS servers (`1.1.1.1` / `8.8.8.8`) via lightweight socket connect with color-coded signal quality (🟢 `<45ms`, 🟡 `45-160ms`, 🔴 `>160ms`).
    - **Zero-CPU Pausing**: Network polling strictly halts when the island is collapsed to preserve battery life.
    - **Compact Notch Mode**: Toggleable from the menu bar or Controls tab to display live download speed and ping status directly inside the collapsed notch pill when audio is idle.

---

### 🗂️ Productivity, Shelf & Quick Actions
9. **📁 File Shelf (Drag & Drop Staging Area):**
   - Auto-expands when dragging files toward the top edge of the screen.
   - Temporary staging area for files, images, and text from Desktop/Finder with native macOS preview icons and multi-file drag-out support across spaces.

10. **⚡ Instant Drop-Zone Actions (Image & File Converter):**
    - Built-in quick action pills inside the File Shelf: one-click image compression, instant format conversion (`PNG` ⇄ `WebP` / `JPG`), and quick text extraction (OCR) via macOS native `Vision.framework`.

11. **📋 Plain-Text Sanitizer & Clipboard History:**
    - Built-in clipboard manager seamlessly integrated into the Shelf tab (`Files Shelf` | `Clipboard` | `Paste Queue`).
    - **Plain-Text Cleaner Toggle**: Automatically strips messy rich-text fonts, colors, and HTML background formatting from copied text, keeping your pasted text native to your destination.
    - Records copied text snippets, URLs, and Hex color codes without polling overhead (zero-CPU event monitor).
    - Single-click to re-copy any snippet with instant visual checkmark feedback.

12. **🔢 Sequential Paste Queue (Stack) & Global Hotkey (`Option + Shift + V`):**
    - Click **"+ Queue"** on any snippet to stage them into an ordered paste list.
    - Press **`Option + Shift + V`** anywhere across macOS to sequentially pop the next snippet, copy it to the system pasteboard, and trigger a sleek HUD capsule displaying remaining items (`3 left`, `2 left`, `Done!`).
    - Perfect for transferring multi-column forms, spreadsheets, credentials, and data entry workflows in seconds without app switching.

13. **📝 Quick Notes & Reminders:**
    - Instant task entry with a dedicated **"Add"** button or pressing `Enter` with full keyboard focus inside floating panels.
    - Interactive iOS Reminders-style circular checkboxes with strikethrough animations.
    - Persistent local storage using `UserDefaults`.

14. **⏱️ Focus / Pomodoro Timer:**
    - Digital countdown with **SF Pro Rounded** typography and persistent compact progress ring on the notch edge.
    - Instant presets: 25 minutes (Pomodoro), 5 minutes (Short Break), 15 minutes (Long Break).

15. **📈 Live Saham, Forex & Crypto Watcher (Market Tab):**
    - Dedicated **Market Tab** (`Controls` | `Shelf` | `Notes` | `Market`) built directly into the Dynamic Island.
    - Real-time quotes for **USD/IDR (Forex)**, **BTC/USD & ETH/USD (Crypto)**, and **BBCA.JK, AAPL, NVDA (Stocks)** with zero API keys required.
    - Instant category filtering (`All` | `Forex` | `Crypto` | `Stocks`) with color-coded 24h change capsules.
    - **📌 Pin to Notch**: 1-click pin any currency, crypto, or stock ticker to display live prices directly inside the collapsed notch pill when media is idle.
    - **Zero-CPU Architecture**: Requests only trigger on-demand via the 🔄 Refresh button or when opening the tab if data is older than 5 minutes.

---

### 🛠️ Developer & Power-User Utilities
16. **🌐 Localhost & Dev Port Monitor:**
    - Lightweight background socket scanner in the Controls/Dev tab that detects active local development servers (e.g., `:3000`, `:5173`, `:8000`, `:8080`).
    - One-click actions to open the running port in your browser or terminate stuck processes (`kill -9`).

17. **🎨 Quick Screen Color Picker & Camera Mirror:**
    - **Native Loupe**: Pick any pixel color on screen (`NSColorSampler`) and automatically copy its `HEX` / `RGB` / `Tailwind` value to the clipboard.
    - **Webcam Peek**: Instant 1-click camera mirror preview inside the notch to check framing before joining a video call.

18. **🎛️ iOS-Style Control Center & Caffeinate:**
    - **Caffeinate Toggle**: One-click native power management assertion (`IOPMAssertionCreateWithName`) to keep your Mac awake during builds, renders, or downloads.
    - Quick status and toggles for **Wi-Fi** (with SSID detection), **Bluetooth**, **Focus / DND**, and an interactive iOS capsule volume scrubber.

19. **⌨️ Global Keyboard Shortcuts (Zero Accessibility Permissions):**
    - `Option + Space`: Toggle Expand / Collapse Dynamic Island instantly.
    - `Option + Shift + V`: Paste Next Snippet in Sequential Queue with HUD indicator.
    - `Option + Shift + M`: 1-Click Global Microphone Mute / Unmute.
    - `Option + Shift + C`: Instant Screen Color Picker Loupe.
    - **Dead-Center Balanced Clock**: Mathematically and optically aligned time indicator.
    - **Smart Click Pass-Through**: Transparent areas around the notch let mouse clicks pass straight through to underlying windows.
    - **Menu Bar Tray Icon (🏝️)**: Left-click to toggle Island; Right-click for quick preferences (**Hover Peek Mode**, Full-Screen Auto-Hide, Clean Plain-Text Sanitizer, Market Ticker in Notch, Quit).

---

## 🛠️ System Requirements & Build Specs

- **Operating System**: macOS 12 Monterey or later (Ventura, Sonoma, Sequoia supported).
- **Architecture**: Universal — Intel (`x86_64`) & Apple Silicon (`arm64`).
- **Binary Footprint**: Standalone **~964 KB** (Zero third-party dependencies / No Electron / Pure Native).
- **Toolchain**: Apple Command Line Tools (`xcode-select --install`).

---

## 🚀 Getting Started

1. Clone the repository:
   ```bash
   git clone [https://github.com/LuthfiMirza/KeyNotch.git](https://github.com/LuthfiMirza/KeyNotch.git)
   cd KeyNotch
# Snap OCR

A **macOS + Windows** desktop utility that lives in the system tray. Press a global hotkey, select a screen region, annotate it, run on-device OCR, and have the extracted text in your clipboard — all in a few seconds.

---

## Features

| Feature | Description |
|---|---|
| 🎯 **Global hotkey** | `Ctrl+Shift+S` triggers region capture from anywhere |
| 🖼 **Region capture** | OS-native crosshair selection (no full screenshot needed) |
| ✏️ **Annotation editor** | Arrow, Rectangle, Freehand, Marker/Highlight tools |
| 🎨 **Color palette** | 8 preset colors + 4 stroke widths + undo/redo |
| 🔍 **On-device OCR** | macOS: Vision framework · Windows: Windows.Media.Ocr |
| 📋 **Auto clipboard** | OCR text copied automatically after done |
| 🗃 **SQLite history** | All captures saved; searchable; re-copy with one click |
| 🖥 **Tray-only mode** | No Dock/taskbar icon — purely tray-driven |

---

## Quick Start (macOS)

```bash
# 1. Install dependencies
flutter pub get

# 2. Debug run
flutter run -d macos

# 3. Release build
flutter build macos
# App: build/macos/Build/Products/Release/snap_ocr.app
```

### macOS Permissions

On first launch, macOS will prompt for **Screen Recording** permission. Go to:

> **System Settings → Privacy & Security → Screen Recording → Enable for Snap OCR**

Also grant **Accessibility** if global hotkeys don't work:

> **System Settings → Privacy & Security → Accessibility → Enable for Snap OCR**

---

## Quick Start (Windows)

> **Requirements:** Windows 10 version 1803+ · Visual Studio 2022 · C++/WinRT SDK component

```bash
# 1. Install dependencies
flutter pub get

# 2. Run
flutter run -d windows

# 3. Release build
flutter build windows
```

> **Note:** The `windows/runner/ocr_channel.cpp` uses C++/WinRT `Windows.Media.Ocr`. If you get CMake or linker errors:
> - Make sure you have the **Windows SDK** (10.0.19041+) installed in VS
> - The `WindowsApp.lib` umbrella library must be available (it is by default with the SDK)
> - If `/await` causes issues, try replacing with `/std:c++17` and WinRT headers from nuget `Microsoft.Windows.CppWinRT`

---

## Project Structure

```
snap_ocr/
├── lib/
│   ├── main.dart                    # Tray + hotkey + window manager
│   ├── models/
│   │   └── capture_item.dart        # SQLite row model
│   ├── services/
│   │   ├── screenshot_service.dart  # screen_capturer wrapper
│   │   ├── ocr_service.dart         # MethodChannel → native OCR
│   │   ├── clipboard_service.dart   # super_clipboard wrapper
│   │   └── db_service.dart          # sqflite_common_ffi persistence
│   ├── screens/
│   │   ├── annotation_editor.dart   # Draw + OCR + save
│   │   └── history_panel.dart       # Browse past captures
│   └── widgets/
│       └── annotation_painter.dart  # CustomPainter for annotations
├── macos/Runner/
│   ├── OcrHandler.swift             # Vision framework OCR (on-device)
│   ├── MainFlutterWindow.swift      # Registers OcrHandler
│   ├── Info.plist                   # LSUIElement=YES, usage descriptions
│   ├── DebugProfile.entitlements    # Screen recording entitlement
│   └── Release.entitlements         # Screen recording entitlement
├── windows/runner/
│   ├── ocr_channel.cpp              # Windows.Media.Ocr C++/WinRT
│   ├── ocr_channel.h
│   ├── flutter_window.cpp           # Calls RegisterOcrChannel
│   └── CMakeLists.txt               # Includes ocr_channel + WindowsApp.lib
└── assets/
    └── tray_icon.png                # System tray icon
```

---

## Key Dependencies

| Package | Purpose |
|---|---|
| `window_manager` | Window hide/show/focus control |
| `tray_manager` | System tray icon + context menu |
| `hotkey_manager` | Global hotkey registration |
| `screen_capturer` | OS-native region select + capture |
| `super_clipboard` | Cross-platform clipboard write |
| `sqflite_common_ffi` | SQLite on desktop |
| `path_provider` | App support/temp directory paths |

---

## How It Works

```
Hotkey (Ctrl+Shift+S)
       ↓
ScreenshotService.captureRegion()   ← OS region selector
       ↓
AnnotationEditor opens               ← draw arrows/rects/highlights
       ↓
[Done & OCR] pressed
       ↓
Export annotated PNG → save to disk
       ↓
OcrService.recognizeText(originalPngBytes)
       ↓  macOS: Vision VNRecognizeTextRequest
       ↓  Windows: Windows.Media.OcrEngine
       ↓
ClipboardService.copyText(text)
       ↓
DbService.insert(CaptureItem)
       ↓
Show OCR result sheet (close → window hides to tray)
```

---

## Troubleshooting

### macOS: "Screen Recording not allowed"
Add the app to **System Settings → Privacy → Screen Recording**.

### macOS: Global hotkey not working
Add to **System Settings → Privacy → Accessibility**.

### macOS: App not appearing in Dock (by design)
`LSUIElement = YES` in Info.plist makes it a tray-only agent app.
To debug, you can temporarily remove `LSUIElement` from Info.plist.

### Windows: OCR always returns empty string
`Windows.Media.Ocr` requires the language pack for the text you're recognizing.
Install it via: **Settings → Time & Language → Language → Add a language**.

### Windows: Build error "WindowsApp.lib not found"
Make sure **Windows SDK** is installed in Visual Studio installer under
**Individual Components → Windows 10 SDK**.

---

## License

MIT — see LICENSE file.
# clip_shot

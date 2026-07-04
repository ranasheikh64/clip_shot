#ifndef OCR_CHANNEL_H_
#define OCR_CHANNEL_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

// Registers the "com.snapocr/ocr" MethodChannel and handles
// "recognizeText" calls using Windows.Media.Ocr (built into Windows 10+,
// fully on-device, no extra downloads needed).
//
// Wiring instructions (see README.md "Windows setup"):
// 1. Drop ocr_channel.h and ocr_channel.cpp into windows/runner/
// 2. Add both files to windows/runner/CMakeLists.txt under add_executable(...)
// 3. Call RegisterOcrChannel(registrar) from flutter_window.cpp,
//    inside FlutterWindow::OnCreate(), after the Flutter engine starts.
void RegisterOcrChannel(flutter::PluginRegistrarWindows* registrar);

#endif  // OCR_CHANNEL_H_

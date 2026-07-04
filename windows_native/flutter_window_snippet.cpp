// Add this inside windows/runner/flutter_window.cpp, in
// FlutterWindow::OnCreate(), right after flutter_controller_->engine()
// is confirmed running (after RegisterPlugins(...) call).

#include "ocr_channel.h"

bool FlutterWindow::OnCreate() {
  // ... existing engine setup code above ...

  RegisterPlugins(flutter_controller_->engine());

  // <-- ADD THIS -->
  RegisterOcrChannel(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(
              flutter_controller_->engine()->GetRegistrar(
                  "OcrChannelPlugin")));

  // ... rest of existing OnCreate() ...
  return true;
}

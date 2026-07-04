#include "ocr_channel.h"

#include <flutter/standard_method_codec.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Globalization.h>
#include <winrt/Windows.Graphics.Imaging.h>
#include <winrt/Windows.Media.Ocr.h>
#include <winrt/Windows.Storage.Streams.h>

#include <memory>
#include <sstream>
#include <vector>

using namespace winrt;
using namespace winrt::Windows::Globalization;
using namespace winrt::Windows::Graphics::Imaging;
using namespace winrt::Windows::Media::Ocr;
using namespace winrt::Windows::Storage::Streams;

namespace {

// Decodes PNG bytes -> SoftwareBitmap, runs OCR, returns joined text.
// Runs synchronously (.get()) for simplicity; channel call already
// happens off the platform thread's hot path since it's a single image.
std::string RunOcrOnPngBytes(const std::vector<uint8_t>& png_bytes) {
  InMemoryRandomAccessStream stream;
  DataWriter writer(stream);
  writer.WriteBytes(array_view<const uint8_t>(png_bytes.data(),
                                               png_bytes.data() + png_bytes.size()));
  writer.StoreAsync().get();
  writer.DetachStream();
  stream.Seek(0);

  BitmapDecoder decoder = BitmapDecoder::CreateAsync(stream).get();
  SoftwareBitmap bitmap = decoder.GetSoftwareBitmapAsync().get();

  // Use the system's default/installed language for OCR; falls back
  // gracefully if unavailable.
  OcrEngine engine = OcrEngine::TryCreateFromUserProfileLanguages();
  if (engine == nullptr) {
    engine = OcrEngine::TryCreateFromLanguage(Language(L"en"));
  }
  if (engine == nullptr) {
    return "";
  }

  OcrResult result = engine.RecognizeAsync(bitmap).get();

  std::wstringstream ws;
  bool first = true;
  for (const auto& line : result.Lines()) {
    if (!first) ws << L"\n";
    ws << line.Text().c_str();
    first = false;
  }

  std::wstring wide = ws.str();
  // Simple UTF-16 -> UTF-8 conversion.
  int size_needed = WideCharToMultiByte(CP_UTF8, 0, wide.c_str(), (int)wide.size(),
                                         nullptr, 0, nullptr, nullptr);
  std::string utf8(size_needed, 0);
  WideCharToMultiByte(CP_UTF8, 0, wide.c_str(), (int)wide.size(), &utf8[0], size_needed,
                       nullptr, nullptr);
  return utf8;
}

}  // namespace

void RegisterOcrChannel(flutter::PluginRegistrarWindows* registrar) {
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      registrar->messenger(), "com.snapocr/ocr",
      &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() != "recognizeText") {
          result->NotImplemented();
          return;
        }

        const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
        if (!args) {
          result->Error("BAD_ARGS", "imageBytes missing");
          return;
        }
        auto it = args->find(flutter::EncodableValue("imageBytes"));
        if (it == args->end()) {
          result->Error("BAD_ARGS", "imageBytes missing");
          return;
        }
        const auto* bytes = std::get_if<std::vector<uint8_t>>(&it->second);
        if (!bytes) {
          result->Error("BAD_ARGS", "imageBytes wrong type");
          return;
        }

        try {
          std::string text = RunOcrOnPngBytes(*bytes);
          result->Success(flutter::EncodableValue(text));
        } catch (const winrt::hresult_error& e) {
          result->Error("OCR_FAILED", winrt::to_string(e.message()));
        }
      });

  // Keep channel alive for the lifetime of the registrar.
  static auto retained_channel = std::move(channel);
}

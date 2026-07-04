import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Talks to native platform OCR engines through a MethodChannel.
///
/// macOS  → Vision framework (VNRecognizeTextRequest) — see macos/Runner/OcrHandler.swift
/// Windows → Windows.Media.Ocr — see windows/runner/ocr_channel.cpp
///
/// Both are fully on-device, no internet required.
class OcrService {
  static const MethodChannel _channel = MethodChannel('com.snapocr/ocr');

  /// Pass raw PNG bytes; returns recognized text.
  /// Returns empty string if nothing was recognized or native side errors out.
  static Future<String> recognizeText(Uint8List pngBytes) async {
    try {
      final String? result = await _channel.invokeMethod<String>(
        'recognizeText',
        {'imageBytes': pngBytes},
      );
      return result?.trim() ?? '';
    } on PlatformException catch (e) {
      debugPrint('OCR PlatformException: [${e.code}] ${e.message}');
      // Return empty — caller shows "no text found" message
      return '';
    } catch (e) {
      debugPrint('OCR error: $e');
      return '';
    }
  }
}

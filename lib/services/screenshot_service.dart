import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:screen_capturer/screen_capturer.dart';
import 'package:uuid/uuid.dart';

class ScreenshotService {
  static const _uuid = Uuid();

  /// Opens the OS-level region-selection overlay and saves the captured PNG.
  /// Returns the file path, or null if the user cancelled or capture failed.
  static Future<String?> captureRegion() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = 'capture_${_uuid.v4()}.png';
      final filePath = p.join(tempDir.path, fileName);

      final CapturedData? data = await screenCapturer.capture(
        mode: CaptureMode.region,
        imagePath: filePath,
        copyToClipboard: false,
        silent: true,
      );

      if (data == null) return null;
      final path = data.imagePath ?? filePath;
      if (!File(path).existsSync()) return null;

      return path;
    } catch (e) {
      debugPrint('Screenshot capture error: $e');
      return null;
    }
  }

  /// Full-screen capture (entire screen, no selection UI)
  static Future<String?> captureFullScreen() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = 'capture_full_${_uuid.v4()}.png';
      final filePath = p.join(tempDir.path, fileName);

      final CapturedData? data = await screenCapturer.capture(
        mode: CaptureMode.screen,
        imagePath: filePath,
        copyToClipboard: false,
        silent: true,
      );

      if (data == null) return null;
      final path = data.imagePath ?? filePath;
      if (!File(path).existsSync()) return null;

      return path;
    } catch (e) {
      debugPrint('Full-screen capture error: $e');
      return null;
    }
  }
}

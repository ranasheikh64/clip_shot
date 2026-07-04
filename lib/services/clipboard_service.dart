import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:super_clipboard/super_clipboard.dart';

/// Writes plain text to the system clipboard.
/// Uses super_clipboard as primary; falls back to Flutter's built-in Clipboard.
class ClipboardService {
  static Future<void> copyText(String text) async {
    if (text.trim().isEmpty) return;

    try {
      await Clipboard.setData(ClipboardData(text: text));
    } catch (e) {
      debugPrint('Clipboard failed: $e');
    }
  }
}

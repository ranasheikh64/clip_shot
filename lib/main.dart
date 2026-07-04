import 'dart:io';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PhysicalKeyboardKey;
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'screens/annotation_editor.dart';
import 'screens/history_panel.dart';
import 'services/screenshot_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize sqflite FFI for desktop (must be done before any DB calls)
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Window manager setup
  await windowManager.ensureInitialized();
  const windowOptions = WindowOptions(
    size: Size(1200, 800),
    minimumSize: Size(800, 600),
    center: true,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    title: 'ClipShot',
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
    await windowManager.setPreventClose(true);
  });

  // Unregister any hotkeys from a previous session
  await hotKeyManager.unregisterAll();

  runApp(const SnapOcrApp());
}

class SnapOcrApp extends StatefulWidget {
  const SnapOcrApp({super.key});

  @override
  State<SnapOcrApp> createState() => _SnapOcrAppState();
}

class _SnapOcrAppState extends State<SnapOcrApp>
    with TrayListener, WindowListener {
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    trayManager.addListener(this);
    windowManager.addListener(this);
    _initTray();
    _registerHotkey();
  }

  @override
  void dispose() {
    trayManager.removeListener(this);
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _initTray() async {
    // macOS wants a template image (white icon), Windows wants .ico
    // We use the same PNG during development
    try {
      await trayManager.setIcon('assets/tray_icon.png');
      await trayManager.setContextMenu(
        Menu(
          items: [
            MenuItem(
              key: 'capture',
              label: 'Capture Screenshot  ⌃⇧S',
            ),
            MenuItem(
              key: 'history',
              label: 'Show History',
            ),
            MenuItem.separator(),
            MenuItem(
              key: 'quit',
              label: 'Quit Snap OCR',
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Tray init error: $e');
    }
  }

  Future<void> _registerHotkey() async {
    try {
      final hotKey = HotKey(
        key: PhysicalKeyboardKey.keyS,
        modifiers: [HotKeyModifier.control, HotKeyModifier.shift],
        scope: HotKeyScope.system,
      );
      await hotKeyManager.register(
        hotKey,
        keyDownHandler: (_) {
          if (!_isCapturing) _startCapture();
        },
      );
    } catch (e) {
      debugPrint('Hotkey registration error: $e');
    }
  }

  // ---- Tray callbacks ----

  @override
  void onTrayIconMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'capture':
        if (!_isCapturing) _startCapture();
        break;
      case 'history':
        _openHistory();
        break;
      case 'quit':
        windowManager.destroy();
        break;
    }
  }

  // ---- Window callbacks ----

  @override
  void onWindowClose() async {
    await windowManager.hide();
  }

  // ---- App actions ----

  Future<void> _startCapture() async {
    _isCapturing = true;
    try {
      final imagePath = await ScreenshotService.captureRegion();
      if (imagePath == null) return; // user cancelled

      // Show window before pushing route so the Navigator is ready
      await windowManager.show();
      await windowManager.focus();

      if (navigatorKey.currentState == null) {
        debugPrint('Navigator not ready yet');
        return;
      }

      await navigatorKey.currentState!.push(
        MaterialPageRoute(
          builder: (_) => AnnotationEditor(imagePath: imagePath),
          fullscreenDialog: true,
        ),
      );

      // Hide back to tray after editor is closed
      await windowManager.hide();
    } catch (e) {
      debugPrint('Capture error: $e');
    } finally {
      _isCapturing = false;
    }
  }

  Future<void> _openHistory() async {
    await windowManager.show();
    await windowManager.focus();
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => const HistoryPanel(),
        fullscreenDialog: true,
      ),
    );
  }

  // ---- Build ----

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Snap OCR',
      theme: _buildTheme(),
      home: const _TrayPlaceholderHome(),
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6C63FF),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF0F0F1A),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E1E30),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

/// Minimal hidden home widget (app lives in tray)
class _TrayPlaceholderHome extends StatelessWidget {
  const _TrayPlaceholderHome();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.camera_alt_rounded,
              size: 72,
              color: Color(0xFF6C63FF),
            ),
            const SizedBox(height: 24),
            Text(
              'Snap OCR',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Running in the system tray\nPress Ctrl+Shift+S to capture',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white54,
                  ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HistoryPanel()),
                );
              },
              icon: const Icon(Icons.history),
              label: const Text('Open History'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

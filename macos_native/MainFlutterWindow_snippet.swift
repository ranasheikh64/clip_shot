// Add this call inside macos/Runner/MainFlutterWindow.swift
// right after the FlutterViewController is created in awakeFromNib().
//
// Example (showing the relevant part only):

import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // <-- ADD THIS LINE -->
    OcrHandler.register(with: flutterViewController)

    super.awakeFromNib()
  }
}

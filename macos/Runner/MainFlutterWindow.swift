import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Register Flutter plugins
    RegisterGeneratedPlugins(registry: flutterViewController)

    // Register on-device OCR handler (Vision framework)
    OcrHandler.register(with: flutterViewController)

    super.awakeFromNib()
  }
}

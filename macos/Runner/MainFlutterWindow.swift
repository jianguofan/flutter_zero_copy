import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Register generated plugins (from pubspec.yaml)
    RegisterGeneratedPlugins(registry: flutterViewController)

    // Register our zero-copy texture plugin
    ZeroCopyTexturePlugin.register(
      with: flutterViewController.registrar(forPlugin: "ZeroCopyTexturePlugin")
    )

    super.awakeFromNib()
  }
}

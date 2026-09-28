import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // The display's corner radius (e.g. 62 pt on iPhone 17 Pro, far less on
    // iPad), which the zoom transition's page corners follow.
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "DisplayCornerRadius") else { return }
    FlutterMethodChannel(name: "zoom_page_route_example/display", binaryMessenger: registrar.messenger())
      .setMethodCallHandler { call, result in
        guard call.method == "cornerRadius" else { return result(FlutterMethodNotImplemented) }
        result(UIScreen.main.value(forKey: "_displayCornerRadius") as? Double ?? 0)
      }
  }
}

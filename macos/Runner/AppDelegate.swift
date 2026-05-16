import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)

    // C2 of the 1m-loop plan: macOS security-scoped bookmark persistence.
    //
    // Background: the macOS App Sandbox grants per-launch access to folders
    // the user picks via NSOpenPanel. Without a bookmark, that access is
    // gone after quit, and the vault auto-restore code at
    // lib/features/vault/presentation/bloc/vault_bloc.dart silently falls
    // back to the picker.
    //
    // This MethodChannel exposes two methods to Dart:
    //   save(path: String) -> Base64-encoded bookmark bytes (String)
    //   resolve(bookmark: String) -> path (String) after
    //     startAccessingSecurityScopedResource()
    //
    // The Dart side persists the Base64 bookmark in SharedPreferences in
    // place of the raw path, then resolves it on every launch.
    guard let controller = self.mainFlutterWindow?.contentViewController as? FlutterViewController else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "quill/bookmarks",
      binaryMessenger: controller.engine.binaryMessenger
    )
    channel.setMethodCallHandler { (call, result) in
      switch call.method {
      case "save":
        guard let args = call.arguments as? [String: Any],
              let path = args["path"] as? String else {
          result(FlutterError(code: "BAD_ARGS", message: "save requires {path: String}", details: nil))
          return
        }
        let url = URL(fileURLWithPath: path)
        do {
          let data = try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
          )
          result(data.base64EncodedString())
        } catch {
          result(FlutterError(code: "BOOKMARK_FAIL", message: "\(error)", details: nil))
        }

      case "resolve":
        guard let args = call.arguments as? [String: Any],
              let b64 = args["bookmark"] as? String,
              let data = Data(base64Encoded: b64) else {
          result(FlutterError(code: "BAD_ARGS", message: "resolve requires {bookmark: base64 String}", details: nil))
          return
        }
        do {
          var stale = false
          let url = try URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
          )
          _ = url.startAccessingSecurityScopedResource()
          // Note: we deliberately don't `stopAccessing…` here. The vault
          // is open for the entire app session; releasing access early
          // would re-enter the sandbox-deny path.
          result(url.path)
        } catch {
          result(FlutterError(code: "BOOKMARK_FAIL", message: "\(error)", details: nil))
        }

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

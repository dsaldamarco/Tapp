#if os(macOS)
import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    let networkServer = NetworkServer()
    let permissionManager = PermissionManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        checkPermissionsAndStart()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep running in menu bar when the main window is closed
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        networkServer.stop()
    }

    private func checkPermissionsAndStart() {
        if permissionManager.isAccessibilityGranted {
            networkServer.start()
        } else {
            permissionManager.requestAccessibility { [weak self] in
                DispatchQueue.main.async {
                    self?.networkServer.start()
                }
            }
        }
    }
}
#endif

import SwiftUI

// This is the single @main entry point for both iOS and macOS.
// - On iOS: shows RootView (connection + controller UI)
// - On macOS: shows status window + persistent MenuBarExtra

@main
struct TappApp: App {
#if os(iOS)
    @StateObject private var connectionManager = ConnectionManager()
#elseif os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
#endif

    var body: some Scene {
#if os(iOS)
        WindowGroup {
            RootView()
                .environmentObject(connectionManager)
        }
#elseif os(macOS)
        WindowGroup("Tapp") {
            MacStatusWindowView(
                server: appDelegate.networkServer,
                permissionManager: appDelegate.permissionManager
            )
        }
        .windowResizability(.contentSize)

        MenuBarExtra {
            MenuBarView(
                server: appDelegate.networkServer,
                permissionManager: appDelegate.permissionManager
            ) {
                NSApplication.shared.terminate(nil)
            }
        } label: {
            Image(systemName: "keyboard.fill")
        }
        .menuBarExtraStyle(.window)
#endif
    }
}

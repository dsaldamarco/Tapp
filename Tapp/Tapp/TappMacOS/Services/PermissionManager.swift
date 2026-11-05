#if os(macOS)
import AppKit
import ApplicationServices
import Combine

/// Manages macOS Accessibility permission required for CGEvent injection
final class PermissionManager: ObservableObject {

    @Published var manualOverride: Bool = UserDefaults.standard.bool(forKey: "kAccessibilityManualOverride")

    /// Returns true if the app has permission via macOS TCC or user manual confirmation
    var isAccessibilityGranted: Bool {
        AXIsProcessTrusted() || manualOverride
    }

    /// True if the system itself has recognized and cached the permission
    var isSystemTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Prompt the system to show the Accessibility permission dialog
    func requestAccessibility(completion: @escaping () -> Void) {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)

        if trusted || manualOverride {
            completion()
            return
        }

        // Poll until granted (up to 60 seconds)
        let deadline = Date().addingTimeInterval(60)
        DispatchQueue.global(qos: .utility).async {
            while Date() < deadline {
                Thread.sleep(forTimeInterval: 0.5)
                if AXIsProcessTrusted() || UserDefaults.standard.bool(forKey: "kAccessibilityManualOverride") {
                    completion()
                    return
                }
            }
        }
    }

    /// Open System Settings → Privacy & Security → Accessibility
    func openAccessibilityPrefs() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Mark permission as manually confirmed by user
    func confirmManually() {
        UserDefaults.standard.set(true, forKey: "kAccessibilityManualOverride")
        manualOverride = true
    }

    /// Relaunches the app so that macOS refreshes the TCC permission token
    func relaunchApp() {
        let url = URL(fileURLWithPath: Bundle.main.bundlePath)
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
        }
    }
}
#endif

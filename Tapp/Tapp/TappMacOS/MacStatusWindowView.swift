#if os(macOS)
import SwiftUI
import AppKit

struct MacStatusWindowView: View {
    @ObservedObject var server: NetworkServer
    @ObservedObject var permissionManager: PermissionManager

    var body: some View {
        VStack(spacing: 20) {
            // Icon & Title
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 72, height: 72)

                    Image(systemName: "keyboard.fill")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(.accentColor)
                }

                Text("Tapp Mac Companion")
                    .font(.system(size: 20, weight: .bold, design: .rounded))

                Text("Your Mac is ready to be controlled from your iPhone")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Divider()

            // Status Cards
            VStack(spacing: 12) {
                // Connection Status Card
                HStack(spacing: 14) {
                    Circle()
                        .fill(server.isClientConnected ? Color.green : Color.orange)
                        .frame(width: 12, height: 12)
                        .shadow(color: (server.isClientConnected ? Color.green : Color.orange).opacity(0.6), radius: 4)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(server.isClientConnected ? (server.connectedPeerName ?? "iPhone connected") : "Waiting for connection…")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))

                        Text(server.isClientConnected
                             ? "Connected: ready to receive input"
                             : "Open Tapp on your iPhone (Wi-Fi or Bluetooth on)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(14)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)

                // Accessibility Permission Card
                VStack(spacing: 10) {
                    HStack(spacing: 14) {
                        Image(systemName: permissionManager.isAccessibilityGranted ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(permissionManager.isAccessibilityGranted ? .green : .orange)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(permissionManager.isAccessibilityGranted ? "Accessibility permission granted" : "Accessibility required")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))

                            Text(permissionManager.isAccessibilityGranted
                                 ? "Your Mac can receive keyboard and mouse input"
                                 : "Enable Tapp in System Settings to allow mouse and keyboard control")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if permissionManager.isAccessibilityGranted {
                            HStack(spacing: 8) {
                                Button(action: {}) {
                                    Label("Granted", systemImage: "checkmark")
                                }
                                .buttonStyle(.bordered)
                                .tint(.green)
                                .controlSize(.small)
                                .disabled(true)

                                Button(action: {
                                    permissionManager.openAccessibilityPrefs()
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "gearshape")
                                        Text("Settings")
                                    }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .help("Open Privacy & Security → Accessibility")
                            }
                        } else {
                            Button("Open Settings") {
                                permissionManager.openAccessibilityPrefs()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                            .controlSize(.small)
                        }
                    }

                    if !permissionManager.isAccessibilityGranted {
                        HStack(spacing: 12) {
                            Text("Already enabled it in Settings?")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)

                            Spacer()

                            Button("I've enabled it") {
                                permissionManager.confirmManually()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)

                            Button("Relaunch App") {
                                permissionManager.relaunchApp()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(14)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
            }

            Spacer()

            // Footer note
            HStack {
                Image(systemName: "menubar.rectangle")
                    .foregroundColor(.secondary)
                Text("Tapp keeps running in the menu bar, top right.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            HStack {
                Button("Close Window (keep in Menu Bar)") {
                    NSApp.keyWindow?.close()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Quit Tapp") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .font(.system(size: 12))
            }
        }
        .padding(20)
        .frame(width: 470, height: 410)
    }
}
#endif

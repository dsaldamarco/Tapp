#if os(macOS)
import SwiftUI
import AppKit

struct MenuBarView: View {
    @ObservedObject var server: NetworkServer
    @ObservedObject var permissionManager: PermissionManager
    let onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "keyboard.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)

                Text("Tapp")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))

                Spacer()

                // Connection dot
                Circle()
                    .fill(server.isClientConnected ? Color.green : Color.gray.opacity(0.5))
                    .frame(width: 8, height: 8)
                    .shadow(color: server.isClientConnected ? .green.opacity(0.6) : .clear, radius: 3)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider().padding(.horizontal, 12)

            // Status
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: server.isClientConnected ? "iphone" : "iphone.slash")
                        .font(.system(size: 13))
                        .foregroundColor(server.isClientConnected ? .primary : .secondary)

                    Text(server.isClientConnected ? (server.connectedPeerName ?? "iPhone connected") : "Waiting for iPhone...")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(server.isClientConnected ? .primary : .secondary)
                }

                if permissionManager.isAccessibilityGranted {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                        Text("Accessibilità concessa")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)

                        Spacer()

                        Button(action: {
                            permissionManager.openAccessibilityPrefs()
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "gearshape")
                                Text("Apri")
                            }
                            .font(.system(size: 10))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        .help("Apri Impostazioni Privacy e Accessibilità")
                    }
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.orange)
                            Button("Concedi Accessibilità") {
                                permissionManager.openAccessibilityPrefs()
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.orange)
                        }

                        HStack(spacing: 8) {
                            Button("Ho già attivato") {
                                permissionManager.confirmManually()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)

                            Button("Riavvia App") {
                                permissionManager.relaunchApp()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider().padding(.horizontal, 12)

            // Quit
            Button(action: onQuit) {
                HStack {
                    Image(systemName: "power")
                        .font(.system(size: 12))
                    Text("Quit Tapp")
                        .font(.system(size: 13))
                }
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: 280)
        .background(Color(NSColor.windowBackgroundColor))
    }
}
#endif

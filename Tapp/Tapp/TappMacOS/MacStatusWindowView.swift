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

                Text("Il tuo Mac è pronto per essere controllato dall'iPhone")
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
                        Text(server.isClientConnected ? (server.connectedPeerName ?? "iPhone Connesso") : "In attesa di connessione...")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))

                        Text(server.isClientConnected
                             ? "Connessione attiva: pronto a ricevere comandi"
                             : "Apri Tapp sull'iPhone (Bluetooth o Wi-Fi attivo)")
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
                            Text(permissionManager.isAccessibilityGranted ? "Permesso Accessibilità: Concesso" : "Accessibilità richiesta")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))

                            Text(permissionManager.isAccessibilityGranted
                                 ? "Il Mac può ricevere input di tastiera e mouse"
                                 : "Abilita Tapp in Impostazioni di Sistema per consentire mouse e tastiera")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if permissionManager.isAccessibilityGranted {
                            HStack(spacing: 8) {
                                Button(action: {}) {
                                    Label("Concesso", systemImage: "checkmark")
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
                                        Text("Impostazioni")
                                    }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .help("Apri Impostazioni Privacy e Accessibilità del Mac")
                            }
                        } else {
                            Button("Apri Impostazioni") {
                                permissionManager.openAccessibilityPrefs()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                            .controlSize(.small)
                        }
                    }

                    if !permissionManager.isAccessibilityGranted {
                        HStack(spacing: 12) {
                            Text("Se l'hai già attivato nelle Impostazioni:")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)

                            Spacer()

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
                Text("Tapp è sempre attivo anche nella barra dei menu in alto a destra.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            HStack {
                Button("Chiudi finestra (resta nella Menu Bar)") {
                    NSApp.keyWindow?.close()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Esci da Tapp") {
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

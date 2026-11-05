#if os(iOS)
import SwiftUI

struct ConnectionView: View {
    @EnvironmentObject var connectionManager: ConnectionManager
    @State private var pulseAnimation = false
    @State private var dotCount = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.06))
                            .frame(width: 100, height: 100)
                            .scaleEffect(pulseAnimation ? 1.15 : 1.0)
                            .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                                       value: pulseAnimation)
                        Image(systemName: "keyboard.fill")
                            .font(.system(size: 40, weight: .light))
                            .foregroundColor(.white)
                    }
                    Text("Tapp")
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Keyboard & trackpad for your Mac")
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.45))
                }
                Spacer()
                VStack(spacing: 24) {
                    statusIndicator
                    statusMessage
                    actionButton
                }
                .padding(.horizontal, 32)
                Spacer().frame(height: 60)
            }
        }
        .onAppear {
            pulseAnimation = true
            if connectionManager.state == .idle && !connectionManager.manuallyDisconnected {
                connectionManager.startSearching()
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 400_000_000)
                dotCount = (dotCount + 1) % 4
            }
        }
    }

    @ViewBuilder private var statusIndicator: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(indicatorColor)
                .frame(width: 8, height: 8)
                .shadow(color: indicatorColor.opacity(0.8), radius: 4)
            Text(statusTitle)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Capsule().fill(Color.white.opacity(0.08)))
    }

    @ViewBuilder private var statusMessage: some View {
        VStack(spacing: 8) {
            Text(mainMessage)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(.white).multilineTextAlignment(.center)
            Text(subMessage)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.5)).multilineTextAlignment(.center)
        }
    }

    @ViewBuilder private var actionButton: some View {
        if connectionManager.state == .failed || connectionManager.state == .idle {
            Button(action: { connectionManager.startSearching() }) {
                HStack(spacing: 10) {
                    Image(systemName: connectionManager.state == .idle ? "link" : "arrow.clockwise")
                    Text(connectionManager.state == .idle ? "Connect" : "Try Again").fontWeight(.semibold)
                }
                .font(.system(size: 16, design: .rounded))
                .foregroundColor(.black).frame(maxWidth: .infinity)
                .padding(.vertical, 16).background(Color.white).cornerRadius(16)
            }
        }
    }

    private var indicatorColor: Color {
        switch connectionManager.state {
        case .idle: return .gray
        case .searching, .connecting: return .orange
        case .connected: return .green
        case .failed: return .red
        }
    }
    private var statusTitle: String {
        switch connectionManager.state {
        case .idle: return "Ready"
        case .searching: return "Searching" + String(repeating: ".", count: dotCount)
        case .connecting: return "Connecting" + String(repeating: ".", count: dotCount)
        case .connected: return "Connected"
        case .failed: return "Not Found"
        }
    }
    private var mainMessage: String {
        switch connectionManager.state {
        case .idle: return "Disconnected"
        case .searching: return "Looking for your Mac"
        case .connecting: return "Found your Mac"
        case .connected: return "Connected"
        case .failed: return "Mac not found"
        }
    }
    private var subMessage: String {
        switch connectionManager.state {
        case .idle: return "Tap Connect to search for your Mac again"
        case .searching: return "Make sure Tapp is running on your Mac\nand Wi-Fi or Bluetooth is on"
        case .connecting: return "Establishing connection…"
        case .connected: return ""
        case .failed: return "Make sure Tapp is running on your Mac\nand Wi-Fi or Bluetooth is on"
        }
    }
}
#endif

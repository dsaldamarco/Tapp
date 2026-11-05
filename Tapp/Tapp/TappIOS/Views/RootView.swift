#if os(iOS)
import SwiftUI

struct RootView: View {
    @EnvironmentObject var connectionManager: ConnectionManager

    var body: some View {
        Group {
            switch connectionManager.state {
            case .idle, .searching, .connecting, .failed:
                ConnectionView()
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            case .connected:
                ControllerView()
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: connectionManager.state)
        .preferredColorScheme(.dark)
    }
}
#endif

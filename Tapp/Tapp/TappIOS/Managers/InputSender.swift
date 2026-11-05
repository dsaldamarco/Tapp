#if os(iOS)
import Foundation
import Combine

/// Sends TappPackets over the active connection to the Mac
final class InputSender: ObservableObject {
    weak var connectionManager: ConnectionManager?

    func send(_ packet: TappPacket) {
        guard let cm = connectionManager else {
            print("[Tapp] Warning: inputSender.connectionManager is nil — packet dropped")
            return
        }
        cm.sendPacket(packet)
    }
}
#endif

#if os(macOS)
import Foundation
import MultipeerConnectivity
import Combine

/// MultipeerConnectivity server on Mac: advertises the service and injects received input events
final class NetworkServer: NSObject, ObservableObject {
    @Published var isClientConnected: Bool = false
    @Published var connectedPeerName: String?

    private let myPeerID: MCPeerID
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var eventInjector = EventInjector()

    override init() {
        let name = Host.current().localizedName ?? "Mac"
        self.myPeerID = MCPeerID(displayName: name)
        super.init()
    }

    // MARK: - Start / Stop

    func start() {
        stop()

        let newSession = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .none)
        newSession.delegate = self
        self.session = newSession

        // Mac advertises so iPhone can discover and invite it
        let newAdvertiser = MCNearbyServiceAdvertiser(
            peer: myPeerID,
            discoveryInfo: nil,
            serviceType: TappService.multipeerServiceType
        )
        newAdvertiser.delegate = self
        self.advertiser = newAdvertiser
        newAdvertiser.startAdvertisingPeer()

        print("[TappMac] Multipeer advertising started as: '\(myPeerID.displayName)' on '\(TappService.multipeerServiceType)'")
    }

    func stop() {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        session?.disconnect()
        session = nil
        DispatchQueue.main.async { [weak self] in
            self?.isClientConnected = false
            self?.connectedPeerName = nil
        }
    }

    // MARK: - Packet dispatch

    private func dispatchPacket(_ packet: TappPacket) {
        switch packet.type {
        case .keyDown:
            if let p = packet.keyPayload {
                eventInjector.keyDown(keyCode: p.keyCode,
                                      modifiers: KeyModifiers(rawValue: p.modifiers))
            }
        case .keyUp:
            if let p = packet.keyPayload {
                eventInjector.keyUp(keyCode: p.keyCode,
                                    modifiers: KeyModifiers(rawValue: p.modifiers))
            }
        case .mouseMove:
            if let p = packet.mouseMovePayload {
                eventInjector.mouseMove(deltaX: CGFloat(p.deltaX), deltaY: CGFloat(p.deltaY))
            }
        case .leftClick:
            eventInjector.leftClick()
        case .rightClick:
            eventInjector.rightClick()
        case .scroll:
            if let p = packet.mouseMovePayload {
                eventInjector.scroll(deltaX: CGFloat(p.deltaX), deltaY: CGFloat(p.deltaY))
            }
        case .text:
            if let text = packet.text {
                eventInjector.typeText(text)
            }
        case .leftDown:
            eventInjector.leftDown()
        case .leftUp:
            eventInjector.leftUp()
        case .ping:
            sendPong()
        case .pong:
            break
        }
    }

    private func sendPong() {
        guard let session = session, !session.connectedPeers.isEmpty else { return }
        guard let data = try? TappProtocol.encode(.pong()) else { return }
        try? session.send(data, toPeers: session.connectedPeers, with: .unreliable)
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension NetworkServer: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        print("[TappMac] Received invitation from iPhone: '\(peerID.displayName)' — accepting")
        invitationHandler(true, self.session)
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print("[TappMac] Failed to advertise: \(error)")
    }
}

// MARK: - MCSessionDelegate

extension NetworkServer: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            switch state {
            case .connected:
                print("[TappMac] iPhone connected successfully: '\(peerID.displayName)'")
                self.isClientConnected = true
                self.connectedPeerName = peerID.displayName
            case .connecting:
                print("[TappMac] iPhone connecting: '\(peerID.displayName)'")
            case .notConnected:
                print("[TappMac] iPhone disconnected: '\(peerID.displayName)'")
                self.isClientConnected = false
                self.connectedPeerName = nil
                self.eventInjector.releaseAll()
            @unknown default:
                break
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        do {
            let packet = try TappProtocol.decode(data)
            DispatchQueue.main.async { [weak self] in
                self?.dispatchPacket(packet)
            }
        } catch {
            print("[TappMac] Failed to decode packet: \(error)")
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}

    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}

    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}
#endif

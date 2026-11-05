#if os(iOS)
import Foundation
import MultipeerConnectivity
import UIKit
import Combine

// MARK: - Connection State

enum ConnectionState: Equatable {
    case idle
    case searching
    case connecting
    case connected
    case failed
}

// MARK: - Connection Manager

@MainActor
final class ConnectionManager: NSObject, ObservableObject {
    @Published var state: ConnectionState = .idle
    @Published var connectedPeerName: String?
    /// True after the user tapped "Disconnect" — suppresses auto-search.
    @Published var manuallyDisconnected = false

    private let myPeerID = MCPeerID(displayName: UIDevice.current.name)
    private var session: MCSession?
    private var browser: MCNearbyServiceBrowser?
    private var invitedPeerID: MCPeerID?

    override init() {
        super.init()
#if DEBUG
        // `-TappDemo` launch argument: pretend to be connected (UI previews / screenshots)
        if ProcessInfo.processInfo.arguments.contains("-TappDemo") {
            state = .connected
            connectedPeerName = "MacBook Pro"
        }
#endif
    }

    // MARK: - Public API

    func startSearching() {
        guard state != .searching && state != .connecting else { return }
        manuallyDisconnected = false
        state = .searching
        stopAll()

        let newSession = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .none)
        newSession.delegate = self
        self.session = newSession

        let newBrowser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: TappService.multipeerServiceType)
        newBrowser.delegate = self
        self.browser = newBrowser

        newBrowser.startBrowsingForPeers()
        print("[Tapp] Started browsing for Mac on service '\(TappService.multipeerServiceType)'")

        // Timeout check after 20 seconds
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 20_000_000_000)
            guard let self = self else { return }
            if self.state == .searching {
                self.state = .failed
            }
        }
    }

    func disconnect() {
        manuallyDisconnected = true
        stopAll()
        state = .idle
    }

    func sendPacket(_ packet: TappPacket) {
        guard let session = session, !session.connectedPeers.isEmpty else {
            return
        }
        guard let data = try? TappProtocol.encode(packet) else { return }

        // Mouse movement uses unreliable (immediate, lowest latency)
        // Clicks and keys use reliable (guaranteed in-order delivery)
        let mode: MCSessionSendDataMode = packet.isLossTolerant ? .unreliable : .reliable
        do {
            try session.send(data, toPeers: session.connectedPeers, with: mode)
        } catch {
            print("[Tapp] Send error: \(error.localizedDescription)")
        }
    }

    // MARK: - Teardown

    private func stopAll() {
        browser?.stopBrowsingForPeers()
        browser = nil
        invitedPeerID = nil
        session?.disconnect()
        session = nil
        connectedPeerName = nil
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension ConnectionManager: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        print("[Tapp] Found peer: '\(peerID.displayName)'")
        Task { @MainActor in
            guard let session = self.session else { return }
            guard session.connectedPeers.isEmpty else { return }
            guard self.invitedPeerID != peerID else { return }

            self.invitedPeerID = peerID
            self.state = .connecting
            print("[Tapp] Inviting peer: '\(peerID.displayName)'")
            browser.invitePeer(peerID, to: session, withContext: nil, timeout: 15)
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        print("[Tapp] Lost peer: '\(peerID.displayName)'")
        Task { @MainActor in
            if self.invitedPeerID == peerID {
                self.invitedPeerID = nil
            }
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        print("[Tapp] Browser error: \(error)")
        Task { @MainActor in
            self.state = .failed
        }
    }
}

// MARK: - MCSessionDelegate

extension ConnectionManager: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            switch state {
            case .connected:
                print("[Tapp] Successfully connected to: '\(peerID.displayName)'!")
                self.connectedPeerName = peerID.displayName
                self.state = .connected
                self.invitedPeerID = nil
                // DO NOT stop the browser here! Stopping the browser while the session
                // channel is finalizing tears down the underlying Multipeer data channels (0..6).

            case .connecting:
                print("[Tapp] Handshake in progress with: '\(peerID.displayName)'...")
                self.state = .connecting

            case .notConnected:
                print("[Tapp] Peer '\(peerID.displayName)' is not connected")
                let wasConnected = (self.state == .connected)
                self.connectedPeerName = nil
                self.invitedPeerID = nil
                guard !self.manuallyDisconnected else { return }
                self.state = .failed

                // Auto-reconnect if unexpectedly disconnected
                if wasConnected {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    if self.state == .failed && !self.manuallyDisconnected {
                        self.startSearching()
                    }
                }

            @unknown default:
                break
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {}

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}

    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}

    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}
#endif

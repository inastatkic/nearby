//
//  MPCSession.swift
//  nearinteraction
//
//  Created by Ina Statkic on 2/8/21.
//

import Foundation
import MultipeerConnectivity

final class MPCSession: NSObject {
    var peerConnected: ((MCPeerID) -> Void)?
    var peerData: ((Data, MCPeerID) -> Void)?
    var peerDisconnected: ((MCPeerID) -> Void)?
    
    private let mcSession: MCSession
    private let mcAdvertiser: MCNearbyServiceAdvertiser
    private let mcBrowser: MCNearbyServiceBrowser
    private let peerID = MCPeerID(displayName: UIDevice.current.name)
    
    var invitee: ((MCPeerID) -> ())?
    
    private var informationToShare: String?
    
    // MARK: - Initialization
    
    init(service: String) {
        mcSession = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        mcAdvertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: service)
        mcBrowser = MCNearbyServiceBrowser(peer: peerID, serviceType: service)
        
        super.init()
        mcSession.delegate = self
        mcAdvertiser.delegate = self
        mcBrowser.delegate = self
    }
    
    // MARK: - Public methods
    
    func start() {
        mcAdvertiser.startAdvertisingPeer()
        mcBrowser.startBrowsingForPeers()
    }
    
    func stop() {
        mcAdvertiser.stopAdvertisingPeer()
        mcBrowser.stopBrowsingForPeers()
    }
    
    func disconnect() {
        stop()
        mcSession.disconnect()
    }
    
    // Invite specific peer
    func inviteWithInformation(_ peerID: MCPeerID, to share: String) {
        informationToShare = share
        let context = share.data(using: .utf8)
        mcBrowser.invitePeer(peerID, to: mcSession, withContext: context, timeout: 10)
    }
    
    func sendDataToAllPeers(data: Data) {
        sendData(data: data, peers: mcSession.connectedPeers, mode: .reliable)
    }
    
    func sendData(data: Data, peers: [MCPeerID], mode: MCSessionSendDataMode) {
        do {
            try mcSession.send(data, toPeers: peers, with: mode)
        } catch let error {
            NSLog("Error sending data: \(error)")
        }
    }
    
    // MARK: - Private methods
    
    private func peerConnected(peerID: MCPeerID) {
        if let connected = peerConnected {
            DispatchQueue.main.async {
                connected(peerID)
            }
        }
    }
    
    private func peerDisconnected(peerID: MCPeerID) {
        if let disconnected = peerDisconnected {
            DispatchQueue.main.async {
                disconnected(peerID)
            }
        }
        start()
    }
}

// MARK: - MCSessionDelegate

extension MPCSession: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state {
        case .connected:
            peerConnected(peerID: peerID)
            print("Connected")
        case .notConnected: peerDisconnected(peerID: peerID)
        case .connecting: break
        @unknown default: fatalError()
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        if let peer = peerData {
            DispatchQueue.main.async {
                peer(data, peerID)
            }
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension MPCSession: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        // Invite specific peer
//        browser.invitePeer(peerID, to: mcSession, withContext: nil, timeout: 10)
        invitee?(peerID)
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension MPCSession: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Accepts invitation from specific peer and listen to specific information
        guard
          let window = UIApplication.shared.windows.first,
          let context = context,
          let information = String(data: context, encoding: .utf8)
        else { return }
        let alertController = UIAlertController(title: peerID.displayName, message: "Would you like to accept: \(information)", preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "No", style: .cancel, handler: nil))
        alertController.addAction(UIAlertAction(title: "Yes", style: .default) { _ in
            // Call the handler to accept the peer's invitation to accept information
            invitationHandler(true, self.mcSession)
        })
        window.rootViewController?.present(alertController, animated: true)
    }
}

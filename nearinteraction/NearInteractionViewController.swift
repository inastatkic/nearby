//
//  ViewController.swift
//  nearinteraction
//
//  Created by Ina Statkic on 2/8/21.
//

import UIKit
import NearbyInteraction
import MultipeerConnectivity

final class NearInteractionViewController: UIViewController {
    
    // MARK: - Outlets
    
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var textField: UITextField!
    
    // MARK: - Properties
    
    var session: NISession?
    var peerDiscoveryToken: NIDiscoveryToken?
    var mpc: MPCSession?
    var connectedPeer: MCPeerID?
    var sharedTokenWithPeer = false
    var peerDisplayName: String?
    
    var invitee: MCPeerID? {
        didSet {
            label.text = invitee?.displayName
        }
    }
    
    // MARK: - LifeCycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        startNISession()
        mpc?.invitee = { [weak self] in
            self?.invitee = $0
        }
        set()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        textField.becomeFirstResponder()
    }
    
    // MARK: - Private methods
    
    private func set() {
        textField.addTarget(self, action: #selector(editingChanged), for: .editingChanged)
        textField.addTarget(self, action: #selector(done(_:)), for: .editingDidEndOnExit)
    }
    
    // MARK: - Actions
    
    @objc func editingChanged(_ sender: UITextField) {
//        label.text = sender.text
    }
    
    @objc func done(_ sender: UITextField) {
        textField.resignFirstResponder()
    }
    
    @IBAction func sendInformation(_ sender: Any) {
        guard let invitee = invitee else { return }
        mpc?.inviteWithInformation(invitee, to: textField.text ?? "")
    }
    
    // MARK: - Connection

    func startNISession() {
        // Create a new session for each peer
        session = NISession()
        // Set the session's delegate
        session?.delegate = self
        
        sharedTokenWithPeer = false
        
        if connectedPeer != nil && mpc != nil {
            if let discoveryToken = session?.discoveryToken {
                if !sharedTokenWithPeer {
                    share(discoveryToken)
                }
            } else {
                fatalError("Unable to get self discovery token")
            }
        } else {
            startConnection()
        }
    }
    
    func startConnection() {
        if mpc == nil {
            mpc = MPCSession(service: "insights")
            mpc?.peerConnected = connectedToPeer
            mpc?.peerData = dataReceived
            mpc?.peerDisconnected = disconnectedFromPeer
        }
        mpc?.disconnect()
        mpc?.start()
    }
    
    func connectedToPeer(peer: MCPeerID) {
        guard let token = session?.discoveryToken else {
            fatalError("Unexpectedly failed to initialize nearby interaction session.")
        }
        if connectedPeer != nil {
            fatalError("Already connected to a peer.")
        }
        if !sharedTokenWithPeer {
            share(token)
        }
        connectedPeer = peer
        label.text = peer.displayName
    }
    
    func disconnectedFromPeer(peer: MCPeerID) {
        if connectedPeer == peer {
            connectedPeer = nil
            sharedTokenWithPeer = false
        }
    }
    
    // MARK: Share discovery token
    func share(_ discoveryToken: NIDiscoveryToken) {
        // Encode discovery token
        guard let encodedData = try?  NSKeyedArchiver.archivedData(withRootObject: discoveryToken, requiringSecureCoding: true) else {
            fatalError("Unexpectedly failed to encode discovery token.")
        }
        // Share encoded token using networking layer
        mpc?.sendDataToAllPeers(data: encodedData)
        sharedTokenWithPeer = true
    }
    
    // MARK: Receive a discovery token from the peer device
    func dataReceived(data: Data, peer: MCPeerID) {
        guard let discoveryToken = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: data) else {
            fatalError("Unexpectedly failed to decode discovery token.")
        }
        peerDidShareDiscoveryToken(peer: peer, token: discoveryToken)
    }
    
    func peerDidShareDiscoveryToken(peer: MCPeerID, token: NIDiscoveryToken) {
        if connectedPeer != peer {
            fatalError("Received token from unexpected peer.")
        }
        // Create an NI configuration
        peerDiscoveryToken = token
        let config = NINearbyPeerConfiguration(peerToken: token)

        // Run the session
        session?.run(config)
    }
}

// MARK: - NISessionDelegate

extension NearInteractionViewController: NISessionDelegate {
    
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        guard let peerToken = peerDiscoveryToken else { fatalError("don't have peer token") }
        // Find the peer
        if let peer = nearbyObjects.first(where: { $0.discoveryToken == peerToken }) {
//            print(peer.distance)
        }
    }
    
    func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
        guard let peerToken = peerDiscoveryToken else { fatalError("don't have peer token") }
        let peer = nearbyObjects.first { $0.discoveryToken == peerToken }
        if peer == nil { return }
        switch reason {
        case .peerEnded:
            // Peer stopped communicating, this session is finished, invalidate.
            session.invalidate()
            // Restart the sequence to see if the other side comes back.
            startNISession()
        case .timeout:
            // Peer timeout occurred, but the session is still valid.
            // Check the configuration is still valid and re-run the session.
            if let config = session.configuration {
                session.run(config)
            }
        default:
            fatalError("Unknown and unhandled NINearbyObject.RemovalReason")
        }
    }
    
    func session(_ session: NISession, didInvalidateWith error: Error) {
        // Session was invalidated, start session again
        startNISession()
    }
}


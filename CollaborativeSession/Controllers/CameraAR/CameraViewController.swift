/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Main view controller for the AR experience.
*/

import UIKit
import RealityKit
import ARKit
import MultipeerConnectivity

class ViewController: UIViewController, ARSessionDelegate {
    
    var text: NSString = "hello world"
    @IBOutlet var arView: ARView!
    @IBOutlet weak var messageLabel: MessageLabel!
    @IBOutlet weak var restartButton: UIButton!

    var commentTextField: UITextField?
    
    var multipeerSession: MultipeerSession?
    
    let coachingOverlay = ARCoachingOverlayView()
    
    // A dictionary to map MultiPeer IDs to ARSession ID's.
    // This is useful for keeping track of which peer created which ARAnchors.
    var peerSessionIDs = [MCPeerID: String]()
    
    var sessionIDObservation: NSKeyValueObservation?
    
    var configuration: ARWorldTrackingConfiguration?

    override func viewDidAppear(_ animated: Bool) {
        
        super.viewDidAppear(animated)

        arView.session.delegate = self

        // Turn off ARView's automatically-configured session
        // to create and set up your own configuration.
        arView.automaticallyConfigureSession = false
        
        configuration = ARWorldTrackingConfiguration()

        // Enable a collaborative session.
        configuration?.isCollaborationEnabled = true
        
        // Enable realistic reflections.
        configuration?.environmentTexturing = .automatic

        // Begin the session.
        arView.session.run(configuration!)
        
        // Use key-value observation to monitor your ARSession's identifier.
        sessionIDObservation = observe(\.arView.session.identifier, options: [.new]) { object, change in
            print("SessionID changed to: \(change.newValue!)")
            // Tell all other peers about your ARSession's changed ID, so
            // that they can keep track of which ARAnchors are yours.
            guard let multipeerSession = self.multipeerSession else { return }
            self.sendARSessionIDTo(peers: multipeerSession.connectedPeers)
        }
        
        setupCoachingOverlay()
        
        // Start looking for other players via MultiPeerConnectivity.
        multipeerSession = MultipeerSession(receivedDataHandler: receivedData, peerJoinedHandler:
                                            peerJoined, peerLeftHandler: peerLeft, peerDiscoveredHandler: peerDiscovered)
        
        // Prevent the screen from being dimmed to avoid interrupting the AR experience.
        UIApplication.shared.isIdleTimerDisabled = true

        arView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap(recognizer:))))
        
        messageLabel.displayMessage("Tap the screen to place comment.\nInvite others to launch this app to join you.", duration: 60.0)
    }
    
    @objc
    func handleTap(recognizer: UITapGestureRecognizer) {
        let location = recognizer.location(in: arView)
        
        // Attempt to find a 3D location on a horizontal surface underneath the user's touch location.
        let results = arView.raycast(from: location, allowing: .estimatedPlane, alignment: .any)
        if let firstResult = results.first {
            // Add an ARAnchor at the touch location with a special name you check later in `session(_:didAdd:)`.
            let anchor = ARAnchor(name: "Anchor for object placement", transform: firstResult.worldTransform)
            self.askInput(anchor : anchor)
            
            
        } else {
            messageLabel.displayMessage("Can't place object - no surface found.\nLook for flat surfaces.", duration: 2.0)
            print("Warning: Object placement failed.")
        }
    }
    func askInput(anchor: ARAnchor) {
        let alertController = UIAlertController(title: "Please enter your feedback below", message: nil, preferredStyle: .alert)
        alertController.addTextField { (textField) in
            textField.placeholder = "Enter text here"
        }
        
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak alertController] (_) in
            let textField = alertController?.textFields![0]
            self.text = textField!.text!
            guard let encodedText = try? NSKeyedArchiver.archivedData(withRootObject: self.text, requiringSecureCoding: true)
                else { fatalError("Unexpectedly failed to encode collaboration data.") }
            multipeerSession.sendToAllPeers(encodedText, reliably: .critital)
            self.arView.session.add(anchor: anchor)
            }))
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        self.present(alertController, animated: true, completion: nil)
        
    }
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors {
            if let participantAnchor = anchor as? ARParticipantAnchor {
                messageLabel.displayMessage("Established joint experience with a peer.")
                // ...
                let anchorEntity = AnchorEntity(anchor: participantAnchor)
                
                let coordinateSystem = MeshResource.generateCoordinateSystemAxes()
                anchorEntity.addChild(coordinateSystem)
                
                let color = participantAnchor.sessionIdentifier?.toRandomColor() ?? .white
                let coloredSphere = ModelEntity(mesh: MeshResource.generateSphere(radius: 0.03),
                                                materials: [SimpleMaterial(color: color, isMetallic: true)])
                anchorEntity.addChild(coloredSphere)
                
                arView.scene.addAnchor(anchorEntity)
            } else if anchor.name == "Anchor for object placement" {
                //request Input
                
                let sphereRadius: Float = 0.2
                let color = anchor.sessionIdentifier?.toRandomColor() ?? .orange
                let coloredSphere = ModelEntity(mesh: MeshResource.generateSphere(radius: sphereRadius),
                                                materials: [SimpleMaterial(color: color.withAlphaComponent(0.6), isMetallic: true)])
                //Generate Text
                
                let coloredText =  ModelEntity(mesh: MeshResource.generateText(self.text,
                                                                               extrusionDepth: 0.01,
                                                                               font: .systemFont(ofSize: 0.05),
                                                                               containerFrame: CGRect.init(x: Double(-sphereRadius), y: Double(-sphereRadius)/2, width: 0.4, height: 0.4),
                                                                               alignment: .center,
                                                                               lineBreakMode: .byWordWrapping),
                                               materials: [SimpleMaterial(color: UIColor.magenta, isMetallic: false)])
                
                // Offset the sphere by half if the bottom is not aligned with the real-world surface.
                coloredSphere.position = [0, sphereRadius, 0]
                coloredText.position = [0,0,0]
                
                // Attach the sphere to the ARAnchor via an AnchorEntity.
                //   World origin -> ARAnchor -> AnchorEntity -> ModelEntity
                let anchorEntity = AnchorEntity(anchor: anchor)
                anchorEntity.addChild(coloredSphere)
                anchorEntity.addChild(coloredText)
                self.arView.scene.addAnchor(anchorEntity)
            }
        }
    }
    
    /// - Tag: DidOutputCollaborationData
    func session(_ session: ARSession, didOutputCollaborationData data: ARSession.CollaborationData) {
        guard let multipeerSession = multipeerSession else { return }
        if !multipeerSession.connectedPeers.isEmpty {
            guard let encodedData = try? NSKeyedArchiver.archivedData(withRootObject: data, requiringSecureCoding: true)
            else { fatalError("Unexpectedly failed to encode collaboration data.") }
            // Use reliable mode if the data is critical, and unreliable mode if the data is optional.
            let dataIsCritical = data.priority == .critical
//            let dataToSend = NSKeyedArchiver.archivedData(withRootObject: text)
//            multipeerSession.sendToAllPeers(dataToSend, reliably: dataIsCritical)
            multipeerSession.sendToAllPeers(encodedData, reliably: dataIsCritical)
            
        } else {
            print("Deferred sending collaboration to later because there are no peers.")
        }
    }

    func receivedData(_ data: Data, from peer: MCPeerID) {
        if let collaborationData = try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARSession.CollaborationData.self, from: data) {
            arView.session.update(with: collaborationData!)
            return
        }
        if let collaborationText = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSString.self, from: data) {
            self.text = collaborationText
            return
        }
        // ...
        let sessionIDCommandString = "SessionID:"
        if let commandString = String(data: data, encoding: .utf8), commandString.starts(with: sessionIDCommandString) {
            let newSessionID = String(commandString[commandString.index(commandString.startIndex,
                                                                     offsetBy: sessionIDCommandString.count)...])
            // If this peer was using a different session ID before, remove all its associated anchors.
            // This will remove the old participant anchor and its geometry from the scene.
            if let oldSessionID = peerSessionIDs[peer] {
                removeAllAnchorsOriginatingFromARSessionWithID(oldSessionID)
            }
            
            peerSessionIDs[peer] = newSessionID
        }
    }
//    func session(session: MCSession!, didReceiveData data: NSData!, fromPeer peerID: MCPeerID!) {
//        self.text = NSKeyedUnarchiver.unarchiveObject(with: data! as Data) as! String
//    }
    
    func peerDiscovered(_ peer: MCPeerID) -> Bool {
        guard let multipeerSession = multipeerSession else { return false }
        
        if multipeerSession.connectedPeers.count > 3 {
            // Do not accept more than four users in the experience.
            messageLabel.displayMessage("A fifth peer wants to join the experience.\nThis app is limited to four users.", duration: 6.0)
            return false
        } else {
            return true
        }
    }
    /// - Tag: PeerJoined
    func peerJoined(_ peer: MCPeerID) {
        messageLabel.displayMessage("""
            A peer wants to join the experience.
            Hold the phones next to each other.
            """, duration: 6.0)
        // Provide your session ID to the new user so they can keep track of your anchors.
        sendARSessionIDTo(peers: [peer])
    }
        
    func peerLeft(_ peer: MCPeerID) {
        messageLabel.displayMessage("A peer has left the shared experience.")
        
        // Remove all ARAnchors associated with the peer that just left the experience.
        if let sessionID = peerSessionIDs[peer] {
            removeAllAnchorsOriginatingFromARSessionWithID(sessionID)
            peerSessionIDs.removeValue(forKey: peer)
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        guard error is ARError else { return }
        
        let errorWithInfo = error as NSError
        let messages = [
            errorWithInfo.localizedDescription,
            errorWithInfo.localizedFailureReason,
            errorWithInfo.localizedRecoverySuggestion
        ]
        
        // Remove optional error messages.
        let errorMessage = messages.compactMap({ $0 }).joined(separator: "\n")
        
        DispatchQueue.main.async {
            // Present the error that occurred.
            let alertController = UIAlertController(title: "The AR session failed.", message: errorMessage, preferredStyle: .alert)
            let restartAction = UIAlertAction(title: "Restart Session", style: .default) { _ in
                alertController.dismiss(animated: true, completion: nil)
                self.resetTracking()
            }
            alertController.addAction(restartAction)
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    @IBAction func resetTracking() {
        guard let configuration = arView.session.configuration else { print("A configuration is required"); return }
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    override var prefersStatusBarHidden: Bool {
        // Request that iOS hide the status bar to improve immersiveness of the AR experience.
        return true
    }
    
    override var prefersHomeIndicatorAutoHidden: Bool {
        // Request that iOS hide the home indicator to improve immersiveness of the AR experience.
        return true
    }
    
    private func removeAllAnchorsOriginatingFromARSessionWithID(_ identifier: String) {
        guard let frame = arView.session.currentFrame else { return }
        for anchor in frame.anchors {
            guard let anchorSessionID = anchor.sessionIdentifier else { continue }
            if anchorSessionID.uuidString == identifier {
                arView.session.remove(anchor: anchor)
            }
        }
    }
    
    private func sendARSessionIDTo(peers: [MCPeerID]) {
        guard let multipeerSession = multipeerSession else { return }
        let idString = arView.session.identifier.uuidString
        let command = "SessionID:" + idString
        if let commandData = command.data(using: .utf8) {
            multipeerSession.sendToPeers(commandData, reliably: true, peers: peers)
        }
    }
}

//
//  File.swift
//  MARS
//
//  Created by Danil Lugli on 16/10/24.
//

import Foundation
import ARKit

@available(iOS 16.0, *)
class ARSCNDelegate: NSObject, LocationSubject, @preconcurrency ARSCNViewDelegate {
    
    var positionObservers: [PositionObserver] = []
    private var sceneView: ARSCNView?
    private var trState: ARCamera.TrackingState?
    
    func setSceneView(_ scnV: ARSCNView) {
        sceneView = scnV
    }
    
    func addLocationObserver(positionObserver: PositionObserver) {
        if !self.positionObservers.contains(where: { $0.id == positionObserver.id}) {
            self.positionObservers.append(positionObserver)
        }
    }
    
    func removeLocationObserver(positionObserver: PositionObserver) {
        self.positionObservers = self.positionObservers.filter { $0.id != positionObserver.id }
    }
    
    func notifyLocationUpdate(newLocation: Position, newTrackingState: TrackingState) {
        for positionObserver in self.positionObservers {
            positionObserver.onLocationUpdate(newLocation, newTrackingState)
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        //didAdd - if needed
    }
    
    @MainActor func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        
        if let camera = self.sceneView?.session.currentFrame?.camera,
            let trState = self.sceneView?.session.currentFrame?.camera.trackingState {
            
            DispatchQueue.main.async {
                print("DELEGATE: Updated")
                let newPosition = Position(position: camera.transform)
                let newTrackingState = TrackingState(state: trState)
                self.notifyLocationUpdate(newLocation: newPosition, newTrackingState: newTrackingState)
            }
        }
    }
}

//
//  File.swift
//  MARS
//
//  Created by Danil Lugli on 16/10/24.
//

import Foundation
import ARKit
import SwiftUICore

@available(iOS 16.0, *)

class ARSCNDelegate: NSObject, LocationSubject, ARSCNViewDelegate {
    
    var positionObservers: [PositionObserver] = []
    private var sceneView: ARSCNView?
    private var trackingState: ARCamera.TrackingState?
    private var isFirstPosition = true 
    
    override init(){
        super.init()
    }
    
    func setSceneView(_ scnV: ARSCNView) {
        sceneView = scnV
    }
    
    func findRoomFromMarker(markerName: String) -> Room? {
        // Supponiamo che tu abbia accesso a una lista di stanze nel delegate
        guard let positionProvider = positionObservers.first as? PositionProvider else {
            print("PositionProvider non disponibile")
            return nil
        }
        
        // Cerca una stanza che contenga il marker corrispondente
        for floor in positionProvider.building.floors {
            for room in floor.rooms {
                if room.referenceMarkers.contains(where: { $0.name == markerName }) {
                    print("Trovata stanza: \(room.name) per il marker: \(markerName)")
                    return room
                }
            }
        }

        print("Nessuna stanza trovata per il marker: \(markerName)")
        return nil
    }
    
    nonisolated func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        //Manage Marker finded
        // TODO: what happen if two or more Markers are recognized?
        
//        if let imgId = imageAnchor.referenceImage.name {
//            let markerFound = findMarkByID(markerID: imgId)
//            if markerFound != nil {
//                print("Found: \(markerFound!.id) at Location <\(markerFound!.location)>")
//                //fixAROrigin(imageAnchor: imageAnchor, location: markerFound!.location)
//            }
//            else {
//                print("Nothing found")
//            }
//        }
    }
    
    public func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        guard let imageAnchor = anchors[0] as? ARImageAnchor else { return }
        
        if let markerName = imageAnchor.referenceImage.name{
            let markerFound = findRoomFromMarker(markerName: markerName)
            
        }
    }
    
    nonisolated func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        DispatchQueue.main.async {
            guard let currentFrame = self.sceneView?.session.currentFrame else {
                print("Frame non disponibile")
                return
            }
            
            let camera = currentFrame.camera
            
            let trackingState = camera.trackingState
            let newPosition = currentFrame.camera.transform

            self.notifyLocationUpdate(newLocation: newPosition, newTrackingState: trackingStateToString(trackingState))
        }
    }
    
    func addLocationObserver(positionObserver: PositionObserver) {

        if !self.positionObservers.contains(where: { $0.id == positionObserver.id}) {
            self.positionObservers.append(positionObserver)
        }
    }
    
    func removeLocationObserver(positionObserver: PositionObserver) {
        self.positionObservers = self.positionObservers.filter { $0.id != positionObserver.id }
    }
    
    func notifyLocationUpdate(newLocation: simd_float4x4, newTrackingState: String) {
        
        for positionObserver in self.positionObservers {
            positionObserver.onLocationUpdate(newLocation, newTrackingState)
        }
        
    }
    
    
}

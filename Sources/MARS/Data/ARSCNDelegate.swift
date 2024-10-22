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
    
//    func getSceneFromMarker(markerName: ARReferenceImage ) -> URL{
//        
//    }
    
    func notifyLocationUpdate(newLocation: Position, newTrackingState: TrackingState) {
        for positionObserver in self.positionObservers {
            positionObserver.onLocationUpdate(newLocation, newTrackingState)
        }
    }
    
    @MainActor func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        if let imageAnchor = anchor as? ARImageAnchor {
            // Estrai l'immagine riconosciuta direttamente dall'ARImageAnchor
            let recognizedImage = imageAnchor.referenceImage
            
            // Ad esempio, puoi confrontare l'immagine con altre immagini di riferimento, se necessario
            print("Riconosciuta immagine con dimensione fisica: \(recognizedImage.physicalSize)")
            
            // Invece di lavorare con il nome, puoi usare direttamente l'immagine
            // Qui puoi implementare una logica per ottenere la scena in base all'immagine
//            let sceneURL = getSceneFromMarker(markerName: recognizedImage)
            
//            do {
//                let scene = try SCNScene(url: sceneURL, options: nil)
//                
//                // Imposta la scena nell'ARSCNView
//                self.sceneView?.scene = scene
//                print("Caricata scena: \(sceneURL)")
//                
//                // Aggiungi un nuovo nodo alla scena, se necessario
//                let newNode = SCNNode(geometry: SCNSphere(radius: 0.1))
//                newNode.position = SCNVector3(0, 0, -1)
//                self.sceneView?.scene.rootNode.addChildNode(newNode)
//                
//            } catch {
//                print("Errore nel caricare la scena da URL: \(error)")
//            }
        }
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

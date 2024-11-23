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
    
    nonisolated func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        //
    }
    
    nonisolated func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        DispatchQueue.main.async {
            guard let currentFrame = self.sceneView?.session.currentFrame else {
                print("Frame non disponibile")
                return
            }
            
            let camera = currentFrame.camera
            let trackingState = camera.trackingState

//            switch trackingState {
//            case .notAvailable:
//                print("Tracking non disponibile")
//                return
//            case .limited(.relocalizing):
//                print("Relocalizing...")
//            default:
//                break
//            }

            // Ottieni la trasformazione corrente della fotocamera
            var newPosition = camera.transform
            
            // Se è la prima posizione, applica una traslazione in avanti
            if self.isFirstPosition {
                print("Imposta la prima posizione a 10 metri in avanti")
                let translationMatrix = simd_float4x4(
                    SIMD4<Float>(1, 0, 0, 10),
                    SIMD4<Float>(0, 1, 0, 0),
                    SIMD4<Float>(0, 0, 1, 0),
                    SIMD4<Float>(0, 0, 0, 1)
                )
                newPosition = simd_mul(newPosition, translationMatrix) // Applica la traslazione
                self.isFirstPosition = false // Disabilita la modifica per le prossime posizioni
            }

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

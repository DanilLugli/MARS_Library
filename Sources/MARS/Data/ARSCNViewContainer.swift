//
//  File.swift
//  MARS
//
//  Created by Danil Lugli on 16/10/24.
//

import SwiftUI
import ARKit
import RoomPlan
import Foundation
import Accelerate

@available(iOS 16.0, *)
struct ARSCNViewContainer: UIViewRepresentable{
    
    typealias UIViewType = ARSCNView
    
    private let arSCNView = ARSCNView(frame: .zero)
    private let configuration = ARWorldTrackingConfiguration()
    private let delegate = ARSCNDelegate()
  
    func makeUIView(context: Context) -> ARSCNView {
        
        //Delegate
        arSCNView.delegate = self.delegate as? any ARSCNViewDelegate
        delegate.setSceneView(arSCNView)

        //Scene
        arSCNView.autoenablesDefaultLighting = true
        arSCNView.automaticallyUpdatesLighting = true
        return arSCNView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {}
    
    func sceneFromURL(_ url: URL) {
        arSCNView.allowsCameraControl = true
        //TODO: Update URL
        arSCNView.scene = try! SCNScene(url: URL(fileURLWithPath: ""))
        arSCNView.session.run(configuration)
    }
    
    func planeDetectorRun() {
        configuration.planeDetection = [/*.horizontal,*/ .vertical]
        arSCNView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        arSCNView.debugOptions = [ARSCNDebugOptions.showWorldOrigin, ARSCNDebugOptions.showFeaturePoints]
    }
    
    public func startARSCNView(worldMap: ARWorldMap) {
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        
        let options: ARSession.RunOptions = [.resetTracking, .removeExistingAnchors]
        
        configuration.initialWorldMap = worldMap
        
        arSCNView.debugOptions = [.showFeaturePoints, .showWorldOrigin]
        arSCNView.session.run(configuration, options: options)
    }
    
}

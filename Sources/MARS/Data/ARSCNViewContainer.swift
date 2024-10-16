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
    
    private let sceneView = ARSCNView(frame: .zero)
    private let configuration = ARWorldTrackingConfiguration()
    private let delegate = ARSCNDelegate()
    private let onPositionChange: (Position) -> Void
    
    init(onPositionChange: @escaping (Position) -> Void) {
        self.onPositionChange = onPositionChange
    }
    
    func makeUIView(context: Context) -> ARSCNView {
        
        //Delegate
        sceneView.delegate = self.delegate as? any ARSCNViewDelegate
        delegate.setSceneView(sceneView)

        //Scene
        sceneView.autoenablesDefaultLighting = true
        sceneView.automaticallyUpdatesLighting = true
        return sceneView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {}
    
    func sceneFromURL(_ url: URL) {
        sceneView.allowsCameraControl = true
        //TODO: Update URL
        sceneView.scene = try! SCNScene(url: URL(fileURLWithPath: ""))
        sceneView.session.run(configuration)
    }
    
    func planeDetectorRun() {
        configuration.planeDetection = [/*.horizontal,*/ .vertical]
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        sceneView.debugOptions = [ARSCNDebugOptions.showWorldOrigin, ARSCNDebugOptions.showFeaturePoints]
    }
    
    func loadWorldMap(worldMap: ARWorldMap, _ filename: String) {
        
        let startDate = Date()
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        
        let options: ARSession.RunOptions = [.resetTracking, .removeExistingAnchors]
        var id = 0
//        if let data = try? Data(contentsOf: Model.shared.directoryURL.appending(path: "JsonParametric").appending(path: filename)) {
//            if let room = try? JSONDecoder().decode(CapturedRoom.self, from: data) {
//                for e in room.doors {
//                    worldMap.anchors.append(ARAnchor(name: "door\(id)", transform: e.transform))
//                    id = id+1
//                }
//                for e in room.walls {
//                    worldMap.anchors.append(ARAnchor(name: "wall\(id)", transform: e.transform))
//                    id = id+1
//                    
//                }
//            }
//        }
        
        
        configuration.initialWorldMap = worldMap
        
        sceneView.debugOptions = [.showFeaturePoints, .showWorldOrigin]
        sceneView.session.run(configuration, options: options)
    }
    
    func getWorldMap(url: URL) -> ARWorldMap? {
        guard let mapData = try? Data(contentsOf: url), let worldMap = try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: mapData) else {
            return nil
        }
        return worldMap
    }
    
}

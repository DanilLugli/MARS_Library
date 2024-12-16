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

@available(iOS 16.0, *)

struct ARSCNViewContainer: UIViewRepresentable {
    
    typealias UIViewType = ARSCNView
    
    @State var roomActive: String = ""
    private let arSCNView = ARSCNView(frame: .zero)
    private let configuration: ARWorldTrackingConfiguration = ARWorldTrackingConfiguration()
    private let delegate: ARSCNDelegate
    
    init(delegate: ARSCNDelegate) {
        self.delegate = delegate
        setupConfiguration()
    }
    
    func makeUIView(context: Context) -> ARSCNView {
        arSCNView.delegate = delegate
        delegate.setSceneView(arSCNView)
        configureSceneView()
        return arSCNView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {
    }

    private func setupConfiguration() {
        configuration.planeDetection = [.horizontal, .vertical]
    }
    
    private func configureSceneView() {
        arSCNView.autoenablesDefaultLighting = true
        arSCNView.automaticallyUpdatesLighting = true
    }

    func startPlaneDetection() {
        arSCNView.debugOptions = [.showWorldOrigin, .showFeaturePoints]
        arSCNView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    mutating func startARSCNView(with room: Room, for start: Bool) {
        switch start {
        case true:
            configuration.maximumNumberOfTrackedImages = 1
            arSCNView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
            
            // Reimposta le opzioni di debug dopo l'avvio
            arSCNView.debugOptions = [.showWorldOrigin, .showFeaturePoints]

        case false:
            configuration.initialWorldMap = room.arWorldMap
            arSCNView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
            

            arSCNView.debugOptions = [.showWorldOrigin, .showFeaturePoints]
            
            self.roomActive = room.name
        }
    }
}

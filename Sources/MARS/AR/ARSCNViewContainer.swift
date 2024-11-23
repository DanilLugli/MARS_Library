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
    
    private let arSCNView = ARSCNView(frame: .zero)
    private let configuration: ARWorldTrackingConfiguration
    private let delegate: ARSCNDelegate
    
    init(delegate: ARSCNDelegate) {
        self.configuration = ARWorldTrackingConfiguration()
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

    func loadScene(from url: URL) throws {
        arSCNView.allowsCameraControl = true
        arSCNView.scene = try SCNScene(url: url)
        arSCNView.session.run(configuration)
    }
    
    func startPlaneDetection() {
        arSCNView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        arSCNView.debugOptions = [.showWorldOrigin, .showFeaturePoints]
    }
    
    func startARSCNView(with worldMap: ARWorldMap) {
        configuration.initialWorldMap = worldMap
        arSCNView.debugOptions = [.showWorldOrigin]
        arSCNView.session.run(configuration, options: [.removeExistingAnchors])
    }
}

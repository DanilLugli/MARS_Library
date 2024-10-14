//
//  Room.swift
//  
//
//  Created by Danil Lugli on 03/10/24.
//

import Foundation
import SceneKit
import SwiftUI
import UIKit
import ARKit

@available(iOS 16.0, *)
public class Room: @preconcurrency Decodable, Identifiable, ObservableObject, Equatable, Hashable {
    // MARK: - Properties

    public let id: UUID
    public var name: String
    public var referenceMarkers: [ReferenceMarker]
    public var transitionZones: [TransitionZone]
    public var scene: SCNScene // SceneKit properties will be excluded from decodable
    public var sceneObjects: [SCNNode] // SceneKit properties will be excluded from decodable
    public var planimetry: SCNViewContainer
    public var arWorldMap: ARWorldMap?
    public let roomURL: URL
    public weak var parentFloor: Floor?
    
    // MARK: - Initializer
    public init(id: UUID = UUID(), name: String, referenceMarkers: [ReferenceMarker], transitionZones: [TransitionZone], scene: SCNScene, sceneObjects: [SCNNode], planimetry: SCNViewContainer, arWorldMap: ARWorldMap?, roomURL: URL, parentFloor: Floor?) {
        self.id = id
        self.name = name
        self.referenceMarkers = referenceMarkers
        self.transitionZones = transitionZones
        self.scene = scene
        self.sceneObjects = sceneObjects
        self.planimetry = planimetry
        self.arWorldMap = arWorldMap
        self.roomURL = roomURL
        self.parentFloor = parentFloor
    }
    
    // MARK: - Equatable
    public static func == (lhs: Room, rhs: Room) -> Bool {
        return lhs.id == rhs.id
    }
    
    // MARK: - Hashable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(roomURL)
        // Exclude scene and sceneObjects because they are not hashable
    }
    
    // MARK: - Decodable Implementation
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case referenceMarkers
        case transitionZones
        case roomURL
        // Exclude scene and sceneObjects from decoding
    }
    
    @MainActor
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.transitionZones = try container.decode([TransitionZone].self, forKey: .transitionZones)
        self.roomURL = try container.decode(URL.self, forKey: .roomURL)
        
        // Set scene and sceneObjects as default values because they are not decodable
        self.referenceMarkers = []
        self.scene = SCNScene()  // Inizializza una scena vuota
        self.sceneObjects = []  // Inizializza un array vuoto per gli oggetti della scena
        self.planimetry = SCNViewContainer()
        self.parentFloor = nil  // La parentFloor non viene decodificata direttamente
        self.arWorldMap = nil
    }

    // MARK: - Utility Methods
    public static func randomColor() -> UIColor {
        return UIColor(
            red: CGFloat(arc4random_uniform(256)) / 255.0,
            green: CGFloat(arc4random_uniform(256)) / 255.0,
            blue: CGFloat(arc4random_uniform(256)) / 255.0,
            alpha: 1.0
        )
    }
    

}

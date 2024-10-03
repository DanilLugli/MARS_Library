//
//  Room.swift
//  
//
//  Created by Danil Lugli on 03/10/24.
//

import Foundation
import ARKit
import SceneKit
import SwiftUI

public class Room: NamedURL, Codable, Identifiable, ObservableObject, Equatable {
    // MARK: - Properties
    
    public let id: UUID
    public var name: String
    //public let lastUpdate: Date
    public var planimetry: SCNViewContainer?
    public var referenceMarkers: [ReferenceMarker]
    public var transitionZones: [TransitionZone]
    public var scene: SCNScene?
    public var sceneObjects: [SCNNode]?
    public let roomURL: URL
    public var color: UIColor
    
    public weak var parentFloor: Floor?
    
    // MARK: - Initializer
    
    public init(id: UUID = UUID(), name: String, /*lastUpdate: Date,*/ planimetry: SCNViewContainer? = nil, referenceMarkers: [ReferenceMarker], transitionZones: [TransitionZone], scene: SCNScene? = SCNScene(), sceneObjects: [SCNNode]? = nil, roomURL: URL, parentFloor: Floor? = nil) {
        self.id = id
        self.name = name
        self.lastUpdate = lastUpdate
        self.planimetry = planimetry
        self.referenceMarkers = referenceMarkers
        self.transitionZones = transitionZones
        self.scene = scene ?? SCNScene()
        self.sceneObjects = sceneObjects
        self.roomURL = roomURL
        self.color = Room.randomColor().withAlphaComponent(0.3)
        self.parentFloor = parentFloor
    }
    
    // MARK: - Equatable
    
    public static func == (lhs: Room, rhs: Room) -> Bool {
        return lhs.id == rhs.id
    }
    
    // MARK: - Utility Methods
    
    private static func randomColor() -> UIColor {
        return UIColor(
            red: CGFloat(arc4random_uniform(256)) / 255.0,
            green: CGFloat(arc4random_uniform(256)) / 255.0,
            blue: CGFloat(arc4random_uniform(256)) / 255.0,
            alpha: 1.0
        )
    }
}

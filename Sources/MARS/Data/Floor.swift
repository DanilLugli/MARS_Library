//
//  Floor.swift
//  
//
//  Created by Danil Lugli on 03/10/24.
//

import Foundation
import SceneKit
import simd
import SwiftUI

class Floor{
    
    public var id = UUID()
    public var name: String
    //public var lastUpdate: Date
    public var planimetry: SCNViewContainer
    public var planimetryRooms: SCNViewMapContainer
    var associationMatrix: [String: RotoTraslationMatrix]
    public var rooms: [Room]
    public var sceneObjects: [SCNNode]
    public var scene: SCNScene
    
    init(id: UUID = UUID(), name: String, planimetry: SCNViewContainer, planimetryRooms: SCNViewMapContainer, associationMatrix: [String : RotoTraslationMatrix], rooms: [Room], sceneObjects: [SCNNode], scene: SCNScene) {
        self.name = name
        //self.lastUpdate = lastUpdate
        self.planimetry = planimetry
        self.planimetryRooms = planimetryRooms
        self.associationMatrix = associationMatrix
        self.rooms = rooms
        self.sceneObjects = sceneObjects
        self.scene = scene
    }
}

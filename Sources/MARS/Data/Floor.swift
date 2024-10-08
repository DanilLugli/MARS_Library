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

class Floor: Equatable, Hashable, Decodable {

    public var id = UUID()
    public var name: String
    var associationMatrix: [String: RotoTraslationMatrix]
    public var rooms: [Room]
    public var sceneObjects: [SCNNode]
    public var scene: SCNScene

    init(id: UUID = UUID(), name: String, associationMatrix: [String: RotoTraslationMatrix], rooms: [Room], sceneObjects: [SCNNode], scene: SCNScene) {
        self.id = id
        self.name = name
        self.associationMatrix = associationMatrix
        self.rooms = rooms
        self.sceneObjects = sceneObjects
        self.scene = scene
    }

    // MARK: - Equatable
    static func == (lhs: Floor, rhs: Floor) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.rooms == rhs.rooms
    }

    // MARK: - Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(rooms)
    }

    // MARK: - Decodable
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case associationMatrix
        case rooms
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.associationMatrix = try container.decode([String: RotoTraslationMatrix].self, forKey: .associationMatrix)
        self.rooms = try container.decode([Room].self, forKey: .rooms)

        self.sceneObjects = []
        self.scene = SCNScene()
    }
}

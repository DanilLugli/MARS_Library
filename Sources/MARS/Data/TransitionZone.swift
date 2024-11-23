//
//  TransitionZone.swift
//  
//
//  Created by Danil Lugli on 03/10/24.
//

import Foundation
import SceneKit
import SwiftUI

@available(iOS 16.0, *)
public class TransitionZone: Codable, Identifiable, Equatable, ObservableObject {
    public var id: UUID = UUID()
    public var name: String
    public var connection: [Connection]?

    public static func == (lhs: TransitionZone, rhs: TransitionZone) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.connection == rhs.connection
    }

    public init(name: String, connection: [Connection]?) {
        self.name = name
        self.connection = connection
    }

    public enum CodingKeys: String, CodingKey {
        case id
        case name
        case connection
    }
}

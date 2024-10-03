//
//  TransitionZone.swift
//  
//
//  Created by Danil Lugli on 03/10/24.
//

import Foundation
import SceneKit
import SwiftUI

class TransitionZone: Codable, Identifiable, Equatable, ObservableObject {
    public var id: UUID = UUID()
    public var name: String
    public var connection: [Connection]?
    
    
    init(name: String, connection: [Connection]?) {
        self.name = name
        self.connection = connection
    }
}

//
//  Building.swift
//  
//
//  Created by Danil Lugli on 03/10/24.
//

import Foundation
import SwiftUI

class Building: Decodable, ObservableObject, Hashable {
    
    public var id: UUID
    public var name: String
    public var floors: [Floor]
    
    // MARK: - Initializer
    init(id: UUID = UUID(), name: String, floors: [Floor]) {
        self.id = id
        self.name = name
        self.floors = floors
    }
    
    // MARK: - Equatable
    static func == (lhs: Building, rhs: Building) -> Bool {
        return lhs.id == rhs.id && lhs.name == rhs.name && lhs.floors == rhs.floors
    }
    
    // MARK: - Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(floors)
    }
}

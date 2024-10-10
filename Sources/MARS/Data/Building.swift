//
//  Building.swift
//  
//
//  Created by Danil Lugli on 03/10/24.
//

import Foundation
import SwiftUI

public class Building: Decodable, ObservableObject, Hashable {
    
    public var id: UUID
    public var name: String
    public var floors: [Floor]
    
    // MARK: - Initializer
    public init(id: UUID = UUID(), name: String, floors: [Floor]) {
        self.id = id
        self.name = name
        self.floors = floors
    }
    
    // MARK: - Equatable
    public static func == (lhs: Building, rhs: Building) -> Bool {
        return lhs.id == rhs.id && lhs.name == rhs.name && lhs.floors == rhs.floors
    }
    
    // MARK: - Hashable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(floors)
    }
}

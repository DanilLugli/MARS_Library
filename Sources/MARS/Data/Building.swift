//
//  Building.swift
//  
//
//  Created by Danil Lugli on 03/10/24.
//

import Foundation
import SwiftUI


@available(iOS 16.0, *)
public final class Building: Decodable, ObservableObject, Hashable{
    
    public var id: UUID = UUID()
    public let name: String
    public let floors: [Floor]
    
    // MARK: - Initializer
    public init(name: String, floors: [Floor]) {
        self.name = name
        self.floors = floors
    }
    
    public init(){
        self.name = ""
        self.floors = []
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

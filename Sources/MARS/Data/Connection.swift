//
//  Connection.swift
//  
//
//  Created by Danil Lugli on 03/10/24.
//

import Foundation

class Connection: Codable, Equatable {
    public var id: UUID
    public var name: String
    
    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
    
    static func == (lhs: Connection, rhs: Connection) -> Bool {
        return lhs.id == rhs.id && lhs.name == rhs.name
    }
}

//
//  Connection.swift
//  
//
//  Created by Danil Lugli on 03/10/24.
//

import Foundation

class Connection: Codable{
    public var id = UUID()
    public var name: String
    
    init(id: UUID = UUID(), name: String) {
        self.name = name
    }

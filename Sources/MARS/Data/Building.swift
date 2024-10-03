//
//  Building.swift
//  
//
//  Created by Danil Lugli on 03/10/24.
//

import Foundation
import SwiftUICore

class Building: Encodable, ObservableObject, Hashable {
    public var id = UUID()
    public var name: String
    public var floors: [Floor]
    
    init(name: String, lastUpdate: Date, floors: [Floor]) {
        self.name = name
        //self.lastUpdate = lastUpdate
        self.floors = floors
    }
}

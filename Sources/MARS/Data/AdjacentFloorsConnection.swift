//
//  AdjacentFloorsConnection.swift
//  
//
//  Created by Danil Lugli on 03/10/24.
//

import Foundation

class AdjacentFloorsConnection: Connection {
    public var fromTransitionZone: String
    public var targetFloor: String
    public var targetRoom: String
    public var targetTransitionZone: String
    
    init(name: String, fromTransitionZone: String, targetFloor: String, targetRoom: String, targetTransitionZone: String) {
        self.fromTransitionZone = fromTransitionZone
        self.targetFloor = targetFloor
        self.targetRoom = targetRoom
        self.targetTransitionZone = targetTransitionZone
        super.init(name: name)
    }
    
    required init(from decoder: any Decoder) throws {
        fatalError("init(from:) has not been implemented")
    }
}

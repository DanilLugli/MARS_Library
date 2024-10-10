//
//  PositionObserver.swift
//  
//
//  Created by Danil Lugli on 03/10/24.
//

import Foundation

public protocol PositionObserver: AnyObject {
    func onLocationUpdate(_ newPosition: Position)
    func onRoomChanged(_ newRoom: Room)
    func onFloorChanged(_ newFloor: Floor)
    
}

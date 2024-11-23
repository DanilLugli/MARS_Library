//
//  File.swift
//  MARS
//
//  Created by Danil Lugli on 16/10/24.
//

import Foundation

@available(iOS 16.0, *)
@MainActor
protocol PositionSubject: LocationSubject{

    func notifyRoomChanged(newRoom: Room)
    func notifyFloorChanged(newFloor: Floor)
    
}

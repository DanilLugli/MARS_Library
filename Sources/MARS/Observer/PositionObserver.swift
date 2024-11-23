//
//  PositionObserver.swift
//  
//
//  Created by Danil Lugli on 03/10/24.
//

import Foundation

@available(iOS 16.0, *)
@MainActor
public protocol PositionObserver: LocationObserver {
    func onRoomChanged(_ newRoom: Room)
    func onFloorChanged(_ newFloor: Floor)
}

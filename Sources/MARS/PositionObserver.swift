//
//  PositionObserver.swift
//  
//
//  Created by Danil Lugli on 03/10/24.
//

import Foundation

@available(iOS 16.0, *)
public protocol PositionObserver: AnyObject {
    func onLocationUpdate(_ newPosition: Position)
    func onRoomChanged(_ newRoom: Room)
    func onFloorChanged(_ newFloor: Floor)
    func onTrackingStateChanged(_ trackingState: TrackingState)
}

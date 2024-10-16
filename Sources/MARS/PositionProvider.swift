//
//  File.swift
//  MARS
//
//  Created by Danil Lugli on 15/10/24.
//

import SwiftUI
import ARKit
import RoomPlan
import Foundation
import Accelerate

@available(iOS 16.0, *)
struct PositionProvider: PositionSubject, LocationObserver{
    var id: UUID = UUID()
    
    var positionObservers: [PositionObserver]
    var arSCNView: ARSCNView
    let building: Building
    
    public init(url: URL, arSCNView: ARSCNView){
        self.building = Building()
        self.positionObservers = []
        self.arSCNView = arSCNView
    }
   
    mutating func addLocationObserver(positionObserver: PositionObserver) {
        if !self.positionObservers.contains(where: { $0.id == positionObserver.id}) {
            self.positionObservers.append(positionObserver)
        }
    }
  
    mutating func removeLocationObserver(positionObserver: PositionObserver) {
        self.positionObservers = self.positionObservers.filter { $0.id != positionObserver.id }
    }
    
    public func notifyRoomChanged(newRoom: Room) {
        for positionObserver in self.positionObservers {
            positionObserver.onRoomChanged(newRoom)
        }
    }
    
    public func notifyFloorChanged(newFloor: Floor) {
        for positionObserver in self.positionObservers {
            positionObserver.onFloorChanged(newFloor)
        }
    }
    
    public func notifyLocationUpdate(newLocation: Position, newTrackingState: TrackingState) {
        for positionObserver in self.positionObservers {
            positionObserver.onLocationUpdate(newLocation, newTrackingState)
        }
    }
    
    func onLocationUpdate(_ newPosition: Position, _ trackingState: TrackingState) {
        //TODO: NEW LOCATION MANAGE FROM DELEGATE
    }
}

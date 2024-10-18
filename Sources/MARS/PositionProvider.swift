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
public class PositionProvider: PositionSubject, LocationObserver, Hashable, ObservableObject{
    
    public var id: UUID = UUID()
    var positionObservers: [PositionObserver]
    var arSCNView: ARSCNView
    public let building: Building
    let position = Position()
    
    @MainActor let arView = ARSCNViewContainer()
    @MainActor let scnView = SCNViewContainer()
    
    public init(data: URL, arSCNView: ARSCNView) async {
        self.positionObservers = []
        self.arSCNView = arSCNView
        self.arView = await ARSCNViewContainer()
        self.scnView = await SCNViewContainer()
        
        do {
            self.building = try await FileHandler.loadBuildings(from: data)
        } catch {
            self.building = Building()
        }
    }
    
    func addLocationObserver(positionObserver: PositionObserver) {
        if !self.positionObservers.contains(where: { $0.id == positionObserver.id}) {
            self.positionObservers.append(positionObserver)
        }
    }
    
    func removeLocationObserver(positionObserver: PositionObserver) {
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
    
    public static func == (lhs: PositionProvider, rhs: PositionProvider) -> Bool {
        return lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    @MainActor public func start(){
        
        arView.startARSCNView(worldMap: building.floors[0].rooms[0].arWorldMap!)
        scnView.loadPlanimetry(scene: building.floors[0].scene, borders: true)
        
    }

    @MainActor public func showMap() -> some View {
            return MapView(locationProvider: self)
        }
        
    public func onLocationUpdate(_ newPosition: Position, _ trackingState: TrackingState) {
        //TODO: NEW LOCATION MANAGE FROM DELEGATE
    }
}

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
public class PositionProvider: PositionSubject, LocationObserver, Hashable, ObservableObject, PositionObserver{
    public func onRoomChanged(_ newRoom: Room) {
        //
    }
    
    public func onFloorChanged(_ newFloor: Floor) {
        //
    }
    
    
    public var id: UUID = UUID()
    
    var positionObservers: [PositionObserver]
    var arSCNView: ARSCNView
    let delegate: ARSCNDelegate = ARSCNDelegate()
    
    public let building: Building
    var position = Position()
    var markers = [ReferenceMarker]()
    
    @MainActor let arView = ARSCNViewContainer()
    @MainActor let scnRoomView = SCNViewContainer()
    @MainActor let scnFloorView = SCNViewContainer()

    public init(data: URL, arSCNView: ARSCNView) async {
        self.positionObservers = []
        self.arSCNView = arSCNView
        self.arView = await ARSCNViewContainer()
        self.scnFloorView = await SCNViewContainer()
        self.scnRoomView = await SCNViewContainer()
        
        do {
            self.building = try await FileHandler.loadBuildings(from: data)
        } catch {
            self.building = Building()
        }
        
        self.delegate.addLocationObserver(positionObserver: self)
        
        self.markers = getAllMarkers()
    }
    
    @MainActor public func start(){
        
        //TODO: Riconoscimento ARReferenceImage - Da implementare
//        let configuration = ARWorldTrackingConfiguration()
//        configuration.planeDetection = [.horizontal, .vertical]
//        configuration.detectionImages = loadReferenceMarkers()
//        configuration.maximumNumberOfTrackedImages = 1
//        
//        let options: ARSession.RunOptions = [.removeExistingAnchors]
//        
//        arSCNView.delegate = delegate
//        arSCNView.session.run(configuration, options: options)
        
        //Inizio calcolo posizionamento
        arView.startARSCNView(worldMap: building.floors[0].rooms[0].arWorldMap!)
        scnFloorView.loadPlanimetry(scene: building.floors[0].scene, borders: true)
        scnFloorView.addLocationNode()
        
    }
    
    @MainActor public func showMap() -> some View {
        return MapView(locationProvider: self)
    }
    
    func addLocationObserver(positionObserver: PositionObserver) {
        if !self.positionObservers.contains(where: { $0.id == positionObserver.id}) {
            self.positionObservers.append(positionObserver)
        }
    }
    
    func removeLocationObserver(positionObserver: PositionObserver) {
        self.positionObservers = self.positionObservers.filter { $0.id != positionObserver.id }
    }
    
    func getAllMarkers() -> [ReferenceMarker] {
        self.building.floors.forEach{ floor in
            floor.rooms.forEach{ room in
                self.markers.append(contentsOf: room.referenceMarkers)
            }
        }
        return self.markers
    }
    
    func loadReferenceMarkers() -> Set<ARReferenceImage> {
        var references: Set<ARReferenceImage> = []
        for marker in markers {
            guard let image = marker.image.cgImage else { continue }
            let reference = ARReferenceImage(image, orientation: .up, physicalWidth: marker.physicalWidth)
            references.insert(reference)
        }
        return references
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
    
    //Metodo di protocollo che riceve la nuova posizione
    public func onLocationUpdate(_ newPosition: Position, _ trackingState: TrackingState) {
        // Aggiorna la posizione interna o fai altre operazioni necessarie
        self.position = newPosition
        
        // Se necessario, notifica altri componenti o aggiornare la UI
        print("Nuova posizione aggiornata nel PositionProvider: \(newPosition)")
    }
}

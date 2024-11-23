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
public class PositionProvider: PositionSubject, LocationObserver, @preconcurrency Hashable, ObservableObject, PositionObserver{
    
    public var id: UUID = UUID()
    
    public let building: Building
    
    let delegate: ARSCNDelegate = ARSCNDelegate()

    var markers: Set<ARReferenceImage>
    var firstPrint: Bool = false

    var positionObservers: [PositionObserver]
    
    @Published var position: simd_float4x4 = simd_float4x4(0)
    @Published var trackingState: String = ""
    @Published var nodeContainedIn: String = ""
    @Published var switchingRoom: Bool = false

    @Published var arView: ARSCNViewContainer
    @Published var scnRoomView: SCNViewContainer = SCNViewContainer()
    @Published var scnFloorView: SCNViewContainer = SCNViewContainer()
    @Published var activeRoomPlanimetry: SCNViewContainer? = nil
    
    @Published var activeRoom: Room = Room()
    @Published var prevRoom: Room = Room()
    @Published var activeFloor: Floor = Floor()
    
    var floorNodePosition: SCNNode = SCNNode()
    var lastFloorPosition: simd_float4x4 = simd_float4x4(0)
    
    public init(data: URL, arSCNView: ARSCNView) {
        self.positionObservers = []
        self.markers = []
        
        self.arView = ARSCNViewContainer(delegate: self.delegate)
        self.scnFloorView = SCNViewContainer()
        self.scnRoomView = SCNViewContainer()

        do {
            self.building = try FileHandler.loadBuildings(from: data)
        } catch {
            self.building = Building()
        }
        
        

        var defaultReferenceImage: ARReferenceImage? = nil
        if let placeholderImage = UIImage(named: "placeholderImage"),
           let cgImage = placeholderImage.cgImage {
            defaultReferenceImage = ARReferenceImage(cgImage, orientation: .up, physicalWidth: 0.1)
        }

        self.building.floors.forEach { floor in
            floor.rooms.forEach { room in
                room.referenceMarkers.forEach { marker in
                    if let image = marker.image ?? defaultReferenceImage {
                        print("Insert: \(image.name) with \(image.physicalSize)")
                        self.markers.insert(image)
                    }
                }
            }
        }
        
        self.delegate.addLocationObserver(positionObserver: self)
    }
    
    public func start() {
        
        self.activeFloor = self.building.floors[0]
        addRoomNodesToScene(floor: self.activeFloor)
        
        var roomNodes = [String]()
        self.activeFloor.rooms.forEach{ room in
            roomNodes.append(room.name)
        }
        
        self.activeRoom = self.activeFloor.rooms[1]
        self.activeRoomPlanimetry = self.activeRoom.planimetry
        self.prevRoom = self.activeRoom
        
        self.scnFloorView.loadPlanimetry(scene: activeFloor.scene, roomsNode: roomNodes  ,borders: true, nameCaller: activeFloor.name)
        self.scnRoomView.loadPlanimetry(scene: activeRoom.scene, roomsNode: nil, borders: true, nameCaller: activeRoom.name)
//
        self.arView.startARSCNView(with: self.activeRoom.arWorldMap!)
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
    
    func findPositionContainer(for positionVector: SCNVector3) -> SCNNode? {
        let roomNames = Set(activeFloor.rooms.map { $0.name })

        for roomNode in activeFloor.scene.rootNode.childNodes {
            guard let roomName = roomNode.name, roomNames.contains(roomName) else {
                continue
            }

            // Converti la posizione globale alla posizione locale rispetto al nodo
            let localPosition = roomNode.convertPosition(positionVector, from: nil)

            // Controlla se la posizione è contenuta nella geometria effettiva del nodo
            if isPositionContained(localPosition, in: roomNode) {
                print("Position is contained in room: \(roomName)")
                return roomNode
            }
        }

        print("ERROR: Position not contained in any room.")
        return nil
    }

    private func isPositionContained(_ position: SCNVector3, in node: SCNNode) -> Bool {
        guard let geometry = node.geometry else {
            return false
        }

        let hitTestOptions: [String: Any] = [
            SCNHitTestOption.backFaceCulling.rawValue: false,  // Ignora il culling delle facce posteriori
            SCNHitTestOption.boundingBoxOnly.rawValue: false, // Usa la geometria effettiva
            SCNHitTestOption.ignoreHiddenNodes.rawValue: false // Non ignora i nodi nascosti
        ]

        let rayOrigin = position
        let rayDirection = SCNVector3(0, 0, 1)
        let rayEnd = PositionProvider.sum(lhs: rayOrigin, rhs: rayDirection)


        // Esegui l'hit-test sul nodo stesso
        let hitResults = node.hitTestWithSegment(from: rayOrigin, to: rayEnd, options: hitTestOptions)

        return !hitResults.isEmpty
    }

    // Funzione di utilità per sommare due SCNVector3
    static private func sum(lhs: SCNVector3, rhs: SCNVector3) -> SCNVector3 {
        return SCNVector3(lhs.x + rhs.x, lhs.y + rhs.y, lhs.z + rhs.z)
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
    
    func notifyLocationUpdate(newLocation: simd_float4x4, newTrackingState: String) {
        DispatchQueue.main.async {
            for positionObserver in self.positionObservers {
                positionObserver.onLocationUpdate(newLocation, newTrackingState)
            }
        }
    }
    
    public func onLocationUpdate(_ newPosition: simd_float4x4, _ newTrackingState: String) {
        firstPrint = true

        self.position = newPosition
        self.trackingState = newTrackingState

        self.activeRoom.planimetry?.updatePosition(self.position, nil)
        scnFloorView.updatePosition(newPosition, activeFloor.associationMatrix["Corridoio"])
        
        print(printMatrix4x4( activeFloor.associationMatrix["Corridoio"]!.translation, label: "Corridoio"))
        print(printMatrix4x4( activeFloor.associationMatrix["Mascetti"]!.translation, label: "Mascetti"))
        print(printMatrix4x4( activeFloor.associationMatrix["Bettini"]!.translation, label: "Bettini"))
        

        if let posFloorNode = scnFloorView.scnView.scene?.rootNode.childNode(withName: "POS_FLOOR", recursively: true) {
            
            var lastPositionNormal = posFloorNode.simdWorldTransform

            var roomNodes = [String]()
            self.activeFloor.rooms.forEach { room in
                roomNodes.append(room.name)
            }

            let nextRoom = findPositionContainer(for: posFloorNode.worldPosition)
            self.nodeContainedIn = nextRoom?.name ?? "NO NEW ROOM"

            if roomNodes.contains(self.nodeContainedIn) {
                if self.nodeContainedIn != activeRoom.name {
                    
                    prevRoom = activeRoom
                    
                    self.activeRoom = activeFloor.getRoom(byName: self.nodeContainedIn) ?? prevRoom

                    if activeRoom.planimetry != nil {
                        print("CAMBIO MAPPA")

                        //self.scnRoomView.loadPlanimetry(scene: activeRoom.scene, roomsNode: [], borders: true, nameCaller: activeRoom.name)

                        if activeRoom.name == "Corridoio"{
                            self.scnRoomView.updateInversePosition(lastPositionNormal, activeFloor.associationMatrix["Corridoio"])
                        }
                        
                        if activeRoom.name == "Mascetti"{
                            self.scnRoomView.updateInversePosition(lastPositionNormal, activeFloor.associationMatrix["Mascetti"])
                        }
                        
                    }
                }
            } else {
                print("Error check node contained.")
            }
        } else {
            print("Node POS_FLOOR not found")
        }
    }
    
    func changeARWorldMap() {
        
        self.activeRoom = activeFloor.getRoom(byName: self.nodeContainedIn) ?? self.activeRoom
        //self.scnRoomView.loadPlanimetry(scene: self.activeRoom.scene, roomsNode: nil, borders: true, nameCaller: activeRoom.name)
        
    }
    
    func testChangeARWorldMap() {
        
        /**
         STEP:
         1. Traslare la posizione Floor nella nuova Room
         2. Inizializzare il punto 0 della Room con la posizione traslata
         3. Navigare con VIO di default ARWorldMap
         4. Quando torna normal continuare con la localizzazione ARKit.
         */
        
        self.activeRoom = activeFloor.getRoom(byName: self.nodeContainedIn) ?? self.activeRoom
        //self.scnRoomView.loadPlanimetrySwitching(scene: self.activeRoom.scene, roomsNode: nil, borders: true, lastFloorPosition: lastFloorPosition, lastRoom: prevRoom, floor: activeFloor)
        
        //self.scnRoomView.loadPlanimetry(scene: self.activeRoom.scene, roomsNode: nil, borders: true)
        //self.arView.startARSCNView(with: self.activeRoom.arWorldMap!)
    }
    
    public func onRoomChanged(_ newRoom: Room) {
        // TODO: Manage new Room
    }
    
    public func onFloorChanged(_ newFloor: Floor) {
        // TODO: Manage new Floor
    }
    
    public static func == (lhs: PositionProvider, rhs: PositionProvider) -> Bool {
        return lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

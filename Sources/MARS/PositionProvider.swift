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
import CoreMotion

@available(iOS 16.0, *)
public class PositionProvider: PositionSubject, LocationObserver, @preconcurrency Hashable, ObservableObject, PositionObserver{

    public var id: UUID = UUID()

    public let building: Building

    let delegate: ARSCNDelegate = ARSCNDelegate()
    let motionManager = CMMotionManager()

    var markers: Set<ARReferenceImage>
    var firstPrint: Bool = false

    var positionObservers: [PositionObserver]

    @Published var position: simd_float4x4 = simd_float4x4(0)
    @Published var trackingState: String = ""
    @Published var nodeContainedIn: String = ""
    @Published var switchingRoom: Bool = false

    @Published var arSCNView: ARSCNViewContainer
    @Published var scnRoomView: SCNViewContainer = SCNViewContainer()
    @Published var scnFloorView: SCNViewContainer = SCNViewContainer()
    @Published var activeRoomPlanimetry: SCNViewContainer? = nil

    @Published var activeRoom: Room = Room()
    @Published var prevRoom: Room = Room()
    @Published var activeFloor: Floor = Floor()

    var currentMatrix: simd_float4x4 = simd_float4x4(1.0)
    var previousVelocity: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
    var lastUpdateTime: TimeInterval = Date().timeIntervalSince1970
    
    var floorNodePosition: SCNNode = SCNNode()
    var lastFloorPosition: simd_float4x4 = simd_float4x4(0)
    
    public init(data: URL, arSCNView: ARSCNView) {
        self.positionObservers = []
        self.markers = []
        
        self.arSCNView = ARSCNViewContainer(delegate: self.delegate)
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
        
        // All'interno del tuo init o di una funzione di configurazione
//        motionManager.deviceMotionUpdateInterval = 0.02 // Aggiorna ogni 20 ms
//        motionManager.startDeviceMotionUpdates(using: .xArbitraryCorrectedZVertical)
        
        self.delegate.addLocationObserver(positionObserver: self)
    }

    public func start() {

        self.activeFloor = self.building.floors[0]
        
        addRoomNodesToScene(floor: self.activeFloor)
        
        let roomNodes = self.activeFloor.rooms.map { $0.name }
        
        self.activeRoom = self.activeFloor.rooms[2]
        self.activeRoomPlanimetry = self.activeRoom.planimetry
        self.prevRoom = self.activeRoom
        
        self.scnFloorView.loadPlanimetry(scene: activeFloor.scene, roomsNode: roomNodes  ,borders: true, nameCaller: activeFloor.name)
        self.scnRoomView.loadPlanimetry(scene: activeRoom.scene, roomsNode: nil, borders: true, nameCaller: activeRoom.name)

        addRoomLocationNode(room: self.activeRoom)
        addFloorLocationNode(floor: self.activeFloor)
        
        self.arSCNView.startARSCNView(with: self.activeRoom, for: false)
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
            
            let localPosition = roomNode.convertPosition(positionVector, from: nil)

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
        
        self.position = newPosition
        self.trackingState = newTrackingState
        
        switchingRoom = false
        
        scnRoomView.updatePosition(self.position, nil, floor: self.activeFloor)
        scnFloorView.updatePosition(self.position, self.activeFloor.associationMatrix["Corridoio"], floor: self.activeFloor)
        
        //var roto = RotoTraslationMatrix(name: "Corridoio", translation: simd_float4x4(0), r_Y: simd_float4x4(0))
        //scnFloorView.updatePosition(self.position, roto)
        
        //Save LastFloorPosition
        let posFloorNode = scnFloorView.scnView.scene?.rootNode.childNode(withName: "POS_FLOOR", recursively: true)
        self.lastFloorPosition = posFloorNode?.simdWorldTransform ?? simd_float4x4(0)
        
        //checkSwitchRoom()
        
//        }
        
//        if self.trackingState != "Normal" && switchingRoom == false {
//            print("1. Case: NO Normale & FALSE Switch")
//            
//            //Update Both Position
//            self.activeRoom.planimetry?.updatePosition(self.position, nil)
//            scnFloorView.updatePosition(newPosition, activeFloor.associationMatrix["Corridoio"])
//            
//            //Save LastFloorPosition
//            let posFloorNode = scnFloorView.scnView.scene?.rootNode.childNode(withName: "POS_FLOOR", recursively: true)
//            self.lastFloorPosition = posFloorNode?.simdWorldTransform ?? simd_float4x4(0)
//            
//            //Check if SwitchingRoom
//            checkSwitchRoom()
//            
//        }
//        
//        if self.trackingState != "Normal" && switchingRoom == true {
//            print("3. Case: NO Normal & TRUE Switch")
//            
//            //Update Both Position
//            self.activeRoom.planimetry?.updatePosition(self.position, nil)
//            scnFloorView.updatePosition(newPosition, activeFloor.associationMatrix["Corridoio"])
//            
//            checkSwitchRoom()
//        }


//        if let posFloorNode = scnFloorView.scnView.scene?.rootNode.childNode(withName: "POS_FLOOR", recursively: true) {
//            
//            var lastPositionNormal = posFloorNode.simdWorldTransform
//
//            var roomNodes = [String]()
//            self.activeFloor.rooms.forEach { room in
//                roomNodes.append(room.name)
//            }
//
//            let nextRoom = findPositionContainer(for: posFloorNode.worldPosition)
//            self.nodeContainedIn = nextRoom?.name ?? activeRoom.name
//            
//            if roomNodes.contains(self.nodeContainedIn) && self.nodeContainedIn != activeRoom.name{
//                
//                prevRoom = activeRoom
//                
//                self.activeRoom = activeFloor.getRoom(byName: self.nodeContainedIn) ?? prevRoom
//                
//                if activeRoom.planimetry != nil {
//                    
//                    print("CAMBIO MAPPA from: \(prevRoom.name) to: \(activeRoom.name)")
//                    
//                   // self.switchingRoom = true
//                    
//                    self.scnRoomView = SCNViewContainer()
//                    self.scnRoomView.loadPlanimetry(scene: activeRoom.scene, roomsNode: [], borders: true, nameCaller: activeRoom.name)
//                }
//            } else {
//                print("Error check node contained.")
//            }
//        }
//        else {
//            print("Node POS_FLOOR not found")
//        }
    }
    
    func checkSwitchRoom() {
        
        guard let posFloorNode = scnFloorView.scnView.scene?.rootNode.childNode(withName: "POS_FLOOR", recursively: true) else {
            print("Node POS_FLOOR not found")
            return
        }
        
        var lastPositionNormal = posFloorNode.simdWorldTransform
        
        let nextRoom = findPositionContainer(for: posFloorNode.worldPosition)
        self.nodeContainedIn = nextRoom?.name ?? activeRoom.name
        
        if activeFloor.rooms.map { $0.name }.contains(self.nodeContainedIn), self.nodeContainedIn != activeRoom.name {
            
            prevRoom = activeRoom
            self.activeRoom = activeFloor.getRoom(byName: self.nodeContainedIn) ?? prevRoom
            self.switchingRoom = true
            
            if let planimetry = activeRoom.planimetry {
                print("Change Room from: \(prevRoom.name) to: \(activeRoom.name)")

                DispatchQueue.main.async {
                    self.activeRoomPlanimetry = planimetry
                }
            }
            
            //Upload new ARSCNView
            //self.arSCNView.startARSCNView(with: self.activeRoom.arWorldMap!, for: false)
            
        } else {
            print("Node are in the same room: \(self.nodeContainedIn)")
        }
    }
    
//    func changeARWorldMap() {
//        
//        self.activeRoom = activeFloor.getRoom(byName: self.nodeContainedIn) ?? self.activeRoom
//        //self.scnRoomView.loadPlanimetry(scene: self.activeRoom.scene, roomsNode: nil, borders: true, nameCaller: activeRoom.name)
//        
//    }
//    
//    func testChangeARWorldMap() {
//        
//        /**
//         STEP:
//         1. Traslare la posizione Floor nella nuova Room
//         2. Inizializzare il punto 0 della Room con la posizione traslata
//         3. Navigare con VIO di default ARWorldMap
//         4. Quando torna normal continuare con la localizzazione ARKit.
//         */
//        
//        self.activeRoom = activeFloor.getRoom(byName: self.nodeContainedIn) ?? self.activeRoom
//        //self.scnRoomView.loadPlanimetrySwitching(scene: self.activeRoom.scene, roomsNode: nil, borders: true, lastFloorPosition: lastFloorPosition, lastRoom: prevRoom, floor: activeFloor)
//        
//        //self.scnRoomView.loadPlanimetry(scene: self.activeRoom.scene, roomsNode: nil, borders: true)
//        //self.arView.startARSCNView(with: self.activeRoom.arWorldMap!)
//    }
    
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
    
//    func updatePositionInertialMatrix(
//        currentMatrix: simd_float4x4
//    ) -> simd_float4x4 {
//        // Estrai la traslazione attuale dalla matrice corrente
//        let currentTranslation = SIMD3<Float>(
//            currentMatrix.columns.3.x,
//            currentMatrix.columns.3.y,
//            currentMatrix.columns.3.z
//        )
//        
//        // Definisci il vettore di spostamento di 1 metro in avanti
//        // Assumendo che l'asse "in avanti" sia l'asse z negativo (come in SceneKit e ARKit)
//        let forwardDisplacement = SIMD3<Float>(0, 0, -1) // Spostamento di 1 metro in avanti
//
//        // Somma lo spostamento alla traslazione corrente
//        let updatedTranslation = currentTranslation + forwardDisplacement
//
//        // Crea una nuova matrice di trasformazione con la posizione aggiornata
//        var updatedMatrix = currentMatrix
//        updatedMatrix.columns.3 = SIMD4<Float>(updatedTranslation.x, updatedTranslation.y, updatedTranslation.z, 1.0)
//
//        // Restituisci la matrice aggiornata
//        return updatedMatrix
//    }
    
    
//    func updatePositionInertialMatrix(
//        currentMatrix: simd_float4x4,
//        previousVelocity: SIMD3<Float>,
//        deltaTime: TimeInterval
//    ) -> (updatedMatrix: simd_float4x4, newVelocity: SIMD3<Float>) {
//
//        guard motionManager.isDeviceMotionAvailable, let deviceMotion = motionManager.deviceMotion else {
//            print("Device Motion non disponibile o dati non disponibili")
//            return (currentMatrix, previousVelocity)
//        }
//
//        // Ottieni l'accelerazione del dispositivo (in G)
//        let acceleration = deviceMotion.userAcceleration
//
//        // Converti l'accelerazione in metri al secondo quadrato
//        let accelerationVector = SIMD3<Float>(
//            Float(acceleration.x * 9.81),
//            Float(acceleration.y * 9.81),
//            Float(acceleration.z * 9.81)
//        )
//
//        // Aggiorna la velocità integrando l'accelerazione
//        let newVelocity = previousVelocity + accelerationVector * Float(deltaTime)
//
//        // Calcola lo spostamento integrando la velocità
//        let displacement = newVelocity * Float(deltaTime)
//
//        // Estrai la traslazione attuale dalla matrice corrente
//        let currentTranslation = SIMD3<Float>(
//            currentMatrix.columns.3.x,
//            currentMatrix.columns.3.y,
//            currentMatrix.columns.3.z
//        )
//
//        // Somma la traslazione calcolata a quella corrente
//        let updatedTranslation = currentTranslation + displacement
//
//        // Crea una nuova matrice di traslazione con la posizione aggiornata
//        var updatedMatrix = currentMatrix
//        updatedMatrix.columns.3 = SIMD4<Float>(updatedTranslation.x, updatedTranslation.y, updatedTranslation.z, 1.0)
//
//        // Calcola la rotazione del dispositivo
//        let attitude = deviceMotion.attitude
//        let rotationMatrix = matrix_float4x4(rotation: attitude)
//
//        // Combina la rotazione con la nuova matrice di traslazione
//        //updatedMatrix = rotationMatrix * updatedMatrix
//
//        // Calcola lo spostamento lungo l'asse x (in avanti)
//        let forwardDisplacement = displacement.x
//        print("Spostamento in avanti (asse x): \(forwardDisplacement) metri")
//
//        // Calcola l'angolo di rotazione rispetto all'asse x
//        let pitchAngle = atan2(rotationMatrix.columns.1.z, rotationMatrix.columns.2.z) // Rotazione attorno all'asse X
//        let pitchAngleDegrees = pitchAngle * (180.0 / .pi)
//        print("Rotazione: \(pitchAngleDegrees) gradi")
//
//        return (updatedMatrix, newVelocity)
//    }
}

// Estensioni per creare matrici di trasformazione
extension matrix_float4x4 {
    init(translation t: SIMD3<Float>) {
        self = matrix_identity_float4x4
        columns.3 = SIMD4<Float>(t.x, t.y, t.z, 1.0)
    }
    
    init(rotation attitude: CMAttitude) {
        let rotationMatrix = attitude.rotationMatrix
        self.init(columns: (
            SIMD4<Float>(Float(rotationMatrix.m11), Float(rotationMatrix.m12), Float(rotationMatrix.m13), 0),
            SIMD4<Float>(Float(rotationMatrix.m21), Float(rotationMatrix.m22), Float(rotationMatrix.m23), 0),
            SIMD4<Float>(Float(rotationMatrix.m31), Float(rotationMatrix.m32), Float(rotationMatrix.m33), 0),
            SIMD4<Float>(0, 0, 0, 1)
        ))
    }
}

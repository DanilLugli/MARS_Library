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
    @Published var roomMatrixActive: String = ""
    @Published var switchingRoom: Bool = false
    @Published var angleGradi: String = ""

    @Published var arSCNView: ARSCNViewContainer
    @Published var scnRoomView: SCNViewContainer = SCNViewContainer()
    @Published var scnFloorView: SCNViewContainer = SCNViewContainer()
    @Published var activeRoomPlanimetry: SCNViewContainer? = nil

    @Published var activeRoom: Room = Room()
    @Published var prevRoom: Room = Room()
    @Published var activeFloor: Floor = Floor()

    var currentMatrix: simd_float4x4 = simd_float4x4(1.0)
    var offMatrix: simd_float4x4 = simd_float4x4(1.0)
    var cont: Int = 0
    
    var positionOffTracking: simd_float4x4 = simd_float4x4(1)
    var floorNodePosition: SCNNode = SCNNode()
    var lastFloorPosition: simd_float4x4 = simd_float4x4(1)
    var lastFloorAngle: Float = 0.0
    
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
          
        self.delegate.addLocationObserver(positionObserver: self)
    }

    public func start() {

        self.activeFloor = self.building.floors[0]
                
        let roomNodes = self.activeFloor.rooms.map { $0.name }
        
        self.activeRoom = self.activeFloor.rooms[1]
        self.roomMatrixActive = self.activeRoom.name
        self.activeRoomPlanimetry = self.activeRoom.planimetry
        self.prevRoom = self.activeRoom
        
        self.scnFloorView.loadPlanimetry(scene: self.activeFloor, roomsNode: roomNodes  ,borders: true, nameCaller: activeFloor.name)
        self.scnRoomView.loadPlanimetry(scene: self.activeRoom, roomsNode: nil, borders: true, nameCaller: activeRoom.name)
        
        addRoomNodesToScene(floor: self.activeFloor, scene: self.scnFloorView.scnView.scene!)

        self.arSCNView.startARSCNView(with: self.activeRoom, for: false)
    }
    
    public func onLocationUpdate(_ newPosition: simd_float4x4, _ newTrackingState: String) {
        
        switch switchingRoom {
        case false:
            self.position = newPosition
            self.trackingState = newTrackingState
            
            self.roomMatrixActive = self.activeRoom.name

            scnRoomView.updatePosition(self.position, nil, floor: self.activeFloor)
            scnFloorView.updatePosition(self.position, self.activeFloor.associationMatrix[self.activeRoom.name], floor: self.activeFloor)

            if let posFloorNode = scnFloorView.scnView.scene?.rootNode.childNodes.first(where: { $0.name == "POS_FLOOR" }) {
                
                self.lastFloorPosition = posFloorNode.simdWorldTransform
                self.lastFloorAngle = getRotationAngles(from: posFloorNode.simdWorldTransform).yaw
                self.offMatrix = updateMatrixWithYawTest(matrix: self.lastFloorPosition,  yawRadians: self.lastFloorAngle)

            } else {
                self.lastFloorPosition = simd_float4x4(1)
            }

            checkSwitchRoom()
            
        case true:

            self.position = newPosition
            self.trackingState = newTrackingState

            positionOffTracking = calculatePositionOffTracking(lastFloorPosition: lastFloorPosition, newPosition: newPosition)

            scnRoomView.updatePosition(newPosition, nil, floor: activeFloor)
            scnFloorView.updatePosition(positionOffTracking, nil, floor: activeFloor)
            
            self.switchingRoom = (newTrackingState != "Normal")
            
        default:
            break
        }
        
    }

    func calculatePositionOffTracking( lastFloorPosition: simd_float4x4, newPosition: simd_float4x4) -> simd_float4x4 {
        
        positionOffTracking = offMatrix * newPosition
        return positionOffTracking
    }

    func updateMatrixWithYawTest(matrix: simd_float4x4, yawRadians: Float) -> simd_float4x4 {

        let rotationY = simd_float3x3(
            simd_make_float3(cos(yawRadians), 0, -sin(yawRadians)), // X
            simd_make_float3(0, 1, 0),                              // Y
            simd_make_float3(sin(yawRadians), 0, cos(yawRadians))   // Z
        )

        var combinedMatrix = matrix // Copia la matrice originale

        combinedMatrix.columns.0 = simd_make_float4(rotationY.columns.0, 0) // Prima colonna
        combinedMatrix.columns.1 = simd_make_float4(rotationY.columns.1, 0) // Seconda colonna
        combinedMatrix.columns.2 = simd_make_float4(rotationY.columns.2, 0) // Terza colonna

        combinedMatrix.columns.3 = matrix.columns.3

        return combinedMatrix
    }

    func createRotoTranslationMatrix(translation: simd_float3, angleY: Float) -> simd_float4x4 {
        let cosAngle = cos(angleY)
        let sinAngle = sin(angleY)

        // Matrice di rotazione attorno all'asse Y
        let rotationMatrix = simd_float4x4(
            simd_float4(cosAngle, 0, sinAngle, 0),
            simd_float4(0, 1, 0, 0),
            simd_float4(-sinAngle, 0, cosAngle, 0),
            simd_float4(0, 0, 0, 1)
        )

        // Matrice di traslazione
        var translationMatrix = simd_float4x4(1)
        translationMatrix.columns.3 = simd_float4(translation.x, translation.y, translation.z, 1)

        // Combina rotazione e traslazione
        return translationMatrix * rotationMatrix
    }
    
    func getRotationAngles(from matrix: simd_float4x4) -> (roll: Float, pitch: Float, yaw: Float) {
        // Calcola Pitch (rotazione attorno all'asse X)
        let pitch = atan2(-matrix[2][1], sqrt(matrix[0][1] * matrix[0][1] + matrix[1][1] * matrix[1][1]))
        
        // Calcola Yaw (rotazione attorno all'asse Y)
        let yaw = atan2(matrix[2][0], matrix[2][2])
        
        // Calcola Roll (rotazione attorno all'asse Z)
        let roll = atan2(matrix[0][1], matrix[1][1])
        
        return (roll, pitch, yaw)
    }

    public func printMatrix(){
        
        if cont == 0{
            print("\nInitial Matrix (lastFloorPosition)")
            printSimdFloat4x4(self.lastFloorPosition)
            print("\n")
            let rotationAngles = getRotationAngles(from: self.lastFloorPosition)
            print("Roll: \(rotationAngles.roll.radiansToDegrees)°")
            print("Pitch: \(rotationAngles.pitch.radiansToDegrees)°")
            print("Yaw: \(rotationAngles.yaw.radiansToDegrees)°")
            print("\n")

            print("Last Matrix (self.position)")
            printSimdFloat4x4(self.position)
            print("\n")
            let rotationAngles2 = getRotationAngles(from: self.position)
            print("Roll: \(rotationAngles.roll.radiansToDegrees)°")
            print("Pitch: \(rotationAngles.pitch.radiansToDegrees)°")
            print("Yaw: \(rotationAngles.yaw.radiansToDegrees)°")
            print("\n")
            print("_____________________________________\n")
        }
        print("_____________________________________\n")
        print("\nMatrix (self.position) n°: \(cont)")
        printSimdFloat4x4(self.position)
        print("\n")
        let rotationAngles = getRotationAngles(from: self.position)
        print("Roll: \(rotationAngles.roll.radiansToDegrees)°")
        print("Pitch: \(rotationAngles.pitch.radiansToDegrees)°")
        print("Yaw: \(rotationAngles.yaw.radiansToDegrees)°")
        print("\n")
        print("Matrix (positionOffTracking) n°: \(cont)")
        printSimdFloat4x4(positionOffTracking)
        print("\n")
        let rotationAngles2 = getRotationAngles(from: self.positionOffTracking)
        print("Roll: \(rotationAngles.roll.radiansToDegrees)°")
        print("Pitch: \(rotationAngles.pitch.radiansToDegrees)°")
        print("Yaw: \(rotationAngles.yaw.radiansToDegrees)°")
        print("\n")

        
        cont+=1
    }

    public func printMatrix2(){
        
        print("_____________________________________\n")
        print("\nMatrix (offMatrix) n°: \(cont)")
        printSimdFloat4x4(offMatrix)
        print("\n")
        let rotationAngles = getRotationAngles(from: offMatrix)
        print("Roll: \(rotationAngles.roll.radiansToDegrees)°")
        print("Pitch: \(rotationAngles.pitch.radiansToDegrees)°")
        print("Yaw: \(rotationAngles.yaw.radiansToDegrees)°")
        print("\n")
        print("Matrix (newPosition) n°: \(cont)")
        printSimdFloat4x4(self.position)
        print("\n")
        let rotationAngles2 = getRotationAngles(from: self.position)
        print("Roll: \(rotationAngles.roll.radiansToDegrees)°")
        print("Pitch: \(rotationAngles.pitch.radiansToDegrees)°")
        print("Yaw: \(rotationAngles.yaw.radiansToDegrees)°")
        print("\n")
        
        cont+=1
    }

    func checkSwitchRoom() {
        
        guard let posFloorNode = scnFloorView.scnView.scene?.rootNode.childNode(withName: "POS_FLOOR", recursively: true) else {
            print("Node POS_FLOOR not found")
            return
        }
        
        var roomsNode = getNodesMatchingRoomNames(from: activeFloor, in: scnFloorView.scnView)
        
        for room in roomsNode{
            print(room.name)
        }
        
        let nextRoomName = findPositionContainer(for: posFloorNode.worldPosition)?.name ?? "Error Contained"
        self.nodeContainedIn = nextRoomName

        if nextRoomName != activeRoom.name, activeFloor.rooms.contains(where: { $0.name == nextRoomName }) {
            
            self.switchingRoom = true

            prevRoom = activeRoom
            self.roomMatrixActive = prevRoom.name
            self.activeRoom = activeFloor.getRoom(byName: nextRoomName) ?? prevRoom
            
            self.arSCNView.startARSCNView(with: activeRoom, for: false)

            let roomNames = activeFloor.rooms.map { $0.name }

            if let planimetry = activeRoom.planimetry {
                self.scnRoomView.loadPlanimetry(scene: activeRoom,
                                                roomsNode: roomNames,
                                                borders: true,
                                                nameCaller: activeRoom.name)
            }
            
        } else {
            print("Node are in the same room: \(self.nodeContainedIn)")
        }
    }
    
    func createRotationMatrixY(angle: Float) -> simd_float4x4 {
        let cosAngle = cos(angle)
        let sinAngle = sin(angle)

        return simd_float4x4(
            simd_float4(cosAngle, 0, sinAngle, 0),
            simd_float4(0, 1, 0, 0),
            simd_float4(-sinAngle, 0, cosAngle, 0),
            simd_float4(0, 0, 0, 1)
        )
    }

    @available(iOS 16.0, *)
    func getNodesMatchingRoomNames(from floor: Floor, in scnFloorView: SCNView) -> [SCNNode] {
       
        let roomNames = Set(floor.rooms.map { $0.name })

        guard let rootNode = scnFloorView.scene?.rootNode else {
            print("La scena non ha un rootNode.")
            return []
        }

        let matchingNodes = rootNode.childNodes.filter { node in
            if let nodeName = node.name {
                return roomNames.contains(nodeName)
            }
            return false
        }
        
        return matchingNodes
    }

    func findPositionContainer(for positionVector: SCNVector3) -> SCNNode? {

        let roomNames = Set(activeFloor.rooms.map { $0.name })

        for roomNode in scnFloorView.scnView.scene!.rootNode.childNodes {
            guard let floorNodeName = roomNode.name,
                  floorNodeName.starts(with: "Floor_"),
                  let roomName = floorNodeName.split(separator: "_").last,
                  roomNames.contains(String(roomName))
            else {
                continue
            }

            if let matchingChildNode = roomNode.childNode(withName: String(roomName), recursively: true) {
                let localPosition = matchingChildNode.convertPosition(positionVector, from: nil)
                
                if isPositionContained(localPosition, in: matchingChildNode) {
                    return matchingChildNode
                }
            } else {
                print("No matching child node found for room: \(roomName)")
            }
        }
        return nil
    }
    
    private func isPositionContained(_ position: SCNVector3, in node: SCNNode) -> Bool {

        guard let geometry = node.geometry else {
            return false
        }
        
        let hitTestOptions: [String: Any] = [
            SCNHitTestOption.backFaceCulling.rawValue: false,
            SCNHitTestOption.boundingBoxOnly.rawValue: false,
            SCNHitTestOption.ignoreHiddenNodes.rawValue: false
        ]
        let rayOrigin = position
        let rayDirection = SCNVector3(0, 0, 1)
        let rayEnd = PositionProvider.sum(lhs: rayOrigin, rhs: rayDirection)

        let hitResults = node.hitTestWithSegment(from: rayOrigin, to: rayEnd, options: hitTestOptions)
        return !hitResults.isEmpty
    }

    func findFloorBelow(point: SCNVector3, floors: [SCNNode]) -> SCNNode? {
        
        // Configura le opzioni per l'hit-test
        let hitTestOptions: [String: Any] = [
            SCNHitTestOption.backFaceCulling.rawValue: false,  // Ignora il culling delle facce posteriori
            SCNHitTestOption.boundingBoxOnly.rawValue: false, // Usa la geometria effettiva
            SCNHitTestOption.ignoreHiddenNodes.rawValue: false // Non ignora i nodi nascosti
        ]

        // Lancia un raycast verso il basso per ogni pavimento
        for floor in floors {
            // Posizione del dispositivo nella scena
            print("Device position in scene: \(point)")

            // Posizione del nodo in cui si sta facendo il test
            print("Testing floor node position: \(floor.position)")

            // Definizione del segmento di hit test
            let rayStart = point
            let rayEnd = SCNVector3(point.x, point.y - 10, point.z)
            addDebugMarker(at: rayStart, color: .green, scene: self.scnFloorView.scnView.scene!)
            addDebugMarker(at: rayEnd, color: .red, scene: self.scnFloorView.scnView.scene!)
            // Stampa la posizione del raggio di partenza e di fine
            print("Ray start position: \(rayStart)")
            print("Ray end position: \(rayEnd)")

            // Esegui l'hit test
            let hitResults = floor.hitTestWithSegment(from: rayStart, to: rayEnd, options: hitTestOptions)
            
            // Disegna il raggio per la visualizzazione nella scena
            drawRay(from: rayStart, to: rayEnd, in: self.scnFloorView.scnView.scene!)

            if let closestHit = hitResults.first {
                // Distanza tra il punto del dispositivo e il punto di intersezione
                let distance = closestHit.worldCoordinates.distance(to: point)

                print("Hit detected on node: \(closestHit.node.name ?? "Unnamed Node")")
                print("Hit world coordinates: \(closestHit.worldCoordinates)")
                print("Distance to hit: \(distance)")

                return floor
            } else {
                print("No hit detected for this floor.")
            }
        }


        print("No floors were intersected.")
        return nil
    }
    
    func drawRay(from start: SCNVector3, to end: SCNVector3, in scene: SCNScene, color: UIColor = .blue) {
        // Calcola la direzione (vettore) tra start e end
        let vector = SCNVector3(end.x - start.x, end.y - start.y, end.z - start.z)
        
        // Calcola la lunghezza del vettore
        let length = sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
        
        // Crea un cilindro con la lunghezza calcolata
        let cylinder = SCNCylinder(radius: 0.01, height: CGFloat(length))
        cylinder.firstMaterial?.diffuse.contents = color

        // Crea un nodo per il cilindro
        let rayNode = SCNNode(geometry: cylinder)
        
        // Posiziona il cilindro al punto medio tra start e end
        rayNode.position = SCNVector3(
            (start.x + end.x) / 2,
            (start.y + end.y) / 2,
            (start.z + end.z) / 2
        )
        
        // Calcola la rotazione del cilindro per allinearlo al vettore
        let direction = vector.normalized()
        let up = SCNVector3(0, 1, 0) // L'asse Y locale del cilindro
        let rotation = SCNVector4.rotation(from: up, to: direction)
        rayNode.rotation = rotation

        // Aggiungi il cilindro alla scena
        scene.rootNode.addChildNode(rayNode)
    }
    
    func addDebugMarker(at position: SCNVector3, color: UIColor, scene: SCNScene) {
        let sphere = SCNSphere(radius: 0.05)
        sphere.firstMaterial?.diffuse.contents = color
        let markerNode = SCNNode(geometry: sphere)
        markerNode.position = position
        scene.rootNode.addChildNode(markerNode)
    }
    
    @MainActor
    public func showMap() -> some View {
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

    static private func sum(lhs: SCNVector3, rhs: SCNVector3) -> SCNVector3 {
        return SCNVector3(lhs.x + rhs.x, lhs.y + rhs.y, lhs.z + rhs.z)
    }
    
    public func onRoomChanged(_ newRoom: Room) {
        // TODO: Manage new Room
    }
    
    public func onFloorChanged(_ newFloor: Floor) {
        // TODO: Manage new Floor
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
    
    public static func == (lhs: PositionProvider, rhs: PositionProvider) -> Bool {
        return lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
}

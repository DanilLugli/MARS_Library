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
          
        self.delegate.addLocationObserver(positionObserver: self)
    }

    public func start() {

        self.activeFloor = self.building.floors[0]
                
        let roomNodes = self.activeFloor.rooms.map { $0.name }
        
        self.activeRoom = self.activeFloor.rooms[0]
        self.roomMatrixActive = self.activeRoom.name
        self.activeRoomPlanimetry = self.activeRoom.planimetry
        self.prevRoom = self.activeRoom
        
        self.scnFloorView.loadPlanimetry(scene: self.activeFloor, roomsNode: roomNodes  ,borders: true, nameCaller: activeFloor.name)
        self.scnRoomView.loadPlanimetry(scene: self.activeRoom, roomsNode: nil, borders: true, nameCaller: activeRoom.name)
        
        addRoomNodesToScene(floor: self.activeFloor, scene: self.scnFloorView.scnView.scene!)

        self.arSCNView.startARSCNView(with: self.activeRoom, for: false)
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
    
    func visualizeRaycast(from origin: SCNVector3, to end: SCNVector3, in scene: SCNScene, color: UIColor = .red) {
        // Calcola il vettore di direzione
        let direction = SCNVector3(end.x - origin.x, end.y - origin.y, end.z - origin.z)
        
        // Calcola la lunghezza del raycast
        let length = sqrt(direction.x * direction.x + direction.y * direction.y + direction.z * direction.z)
        
        // Crea una geometria cilindrica per rappresentare il raycast
        let cylinder = SCNCylinder(radius: 0.02, height: CGFloat(length))
        cylinder.firstMaterial?.diffuse.contents = color

        // Crea il nodo per il cilindro
        let raycastNode = SCNNode(geometry: cylinder)
        
        // Posiziona il cilindro a metà tra origine e fine
        raycastNode.position = SCNVector3(
            (origin.x + end.x) / 2,
            (origin.y + end.y) / 2,
            (origin.z + end.z) / 2
        )
        
        // Allinea il cilindro lungo il vettore direzione
        raycastNode.look(at: end)
        
        // Aggiungi il nodo alla scena
        scene.rootNode.addChildNode(raycastNode)
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
        if newTrackingState == "Normal"{
            print("SET SWITCH IN FALSE")
            //switchingRoom = false
        }
        
        if switchingRoom == false{
            self.position = newPosition
            self.trackingState = newTrackingState
            self.roomMatrixActive = self.activeRoom.name
                    
            scnRoomView.updatePosition(self.position, nil, floor: self.activeFloor)
            scnFloorView.updatePosition(self.position, self.activeFloor.associationMatrix[self.activeRoom.name], floor: self.activeFloor)
            
            //var roto = RotoTraslationMatrix(name: "Corridoio", translation: simd_float4x4(0), r_Y: simd_float4x4(0))
            //scnFloorView.updatePosition(self.position, roto)
            
            //Save LastFloorPosition

            let posFloorNode = scnFloorView.scnView.scene?.rootNode.childNodes.first(where: { $0.name == "POS_FLOOR" })
            self.lastFloorPosition = posFloorNode?.simdWorldTransform ?? simd_float4x4(0)
            
            checkSwitchRoom()
        }
        
        else if switchingRoom == true {
            self.position = newPosition
            
            var positionOffTracking = self.lastFloorPosition
            //self.angleGradi =  yRotationAngleString(from: newPosition)
            print("--> Initial Transform:")
            printSimdFloat4x4(positionOffTracking)
            
            // Aggiorniamo la traslazione sommando le colonne 3
            positionOffTracking.columns.3 = simd_float4(
                self.position.columns.3.x + self.lastFloorPosition.columns.3.x, // Somma [3,0]
                self.position.columns.3.y + self.lastFloorPosition.columns.3.y, // Somma [3,1]
                self.position.columns.3.z + self.lastFloorPosition.columns.3.z, // Somma [3,2]
                1.0 // Manteniamo il valore omogeneo
            )
            
            
//            // Estrai la rotazione sull'asse Y da newPosition
//               let yRotationNew = atan2(newPosition.columns.0.z, newPosition.columns.0.x) // Angolo Y di newPosition
//
//               // Estrai la rotazione sull'asse Y da positionOffTracking
//               let yRotationOffTracking = atan2(positionOffTracking.columns.0.z, positionOffTracking.columns.0.x) // Angolo Y di positionOffTracking
//
//               // Somma l'incremento di rotazione sull'asse Y
//               let combinedYRotation = yRotationOffTracking + (yRotationNew - yRotationOffTracking)
//
//               // Crea una matrice di rotazione intorno all'asse Y
//            let combinedRotationYMatrix = float4x4.rotationAroundY(combinedYRotation)
//
//               // Aggiorna solo la parte di rotazione della matrice di positionOffTracking
//               positionOffTracking.columns.0 = combinedRotationYMatrix.columns.0
//               positionOffTracking.columns.1 = combinedRotationYMatrix.columns.1
//               positionOffTracking.columns.2 = combinedRotationYMatrix.columns.2

            
            print("Updated Transform:")
            printSimdFloat4x4(positionOffTracking)
            
            scnRoomView.updatePosition(self.position, nil, floor: self.activeFloor)
            scnFloorView.updatePosition(positionOffTracking, nil, floor: self.activeFloor)
        }
        

//        func yRotationAngleString(from transform: simd_float4x4) -> String {
//            // Estrai i componenti della matrice di rotazione
//            let r11 = transform.columns.0.x // Elemento [0,0]
//            let r13 = transform.columns.2.x // Elemento [0,2]
//            
//            // Calcola l'angolo rispetto all'asse Y
//            let yRotationRadians = atan2(r13, r11)
//            
//            // Converti l'angolo da radianti a gradi
//            let yRotationDegrees = yRotationRadians * (180.0 / .pi)
//            
//            // Restituisci l'angolo come stringa formattata
//            return String(format: "%.2f°", yRotationDegrees)
//        }

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
    
    @available(iOS 16.0, *)
    func getNodesMatchingRoomNames(from floor: Floor, in scnFloorView: SCNView) -> [SCNNode] {
       
        let roomNames = Set(floor.rooms.map { $0.name })
        
        // Ottieni tutti i nodi dalla root della scena
        guard let rootNode = scnFloorView.scene?.rootNode else {
            print("La scena non ha un rootNode.")
            return []
        }
        
        // Trova i nodi che corrispondono ai nomi delle room
        let matchingNodes = rootNode.childNodes.filter { node in
            if let nodeName = node.name {
                return roomNames.contains(nodeName)
            }
            return false
        }
        
        return matchingNodes
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
        
        let nextRoom = findPositionContainer(for: posFloorNode.worldPosition)
        //let nextRoom =  findFloorBelow(point: posFloorNode.worldPosition, floors: roomsNode)
        self.nodeContainedIn = nextRoom?.name ?? "Error Contained"
        
        if activeFloor.rooms.map { $0.name }.contains(self.nodeContainedIn), self.nodeContainedIn != activeRoom.name {
            print("SET SWITCH IN TRUE")
            self.switchingRoom = true
            prevRoom = activeRoom
            self.activeRoom = activeFloor.getRoom(byName: self.nodeContainedIn) ?? prevRoom
            
            
            self.roomMatrixActive = prevRoom.name
            
            var rooms = [String]()
            for room in activeFloor.rooms {
                rooms.append(room.name)
            }
            
            if let planimetry = activeRoom.planimetry {
                print("Change Room from: \(prevRoom.name) to: \(activeRoom.name)")

                self.scnRoomView.loadPlanimetry(scene: self.activeRoom,
                                                roomsNode: rooms,
                                                borders: true,
                                                nameCaller: self.activeRoom.name)
            }
            
            //Upload new ARSCNView
            self.arSCNView.startARSCNView(with: self.activeRoom, for: false)
            
        } else {
            print("Node are in the same room: \(self.nodeContainedIn)")
        }
    }
    
    ///MARK: Old Method Check
    func findPositionContainer(for positionVector: SCNVector3) -> SCNNode? {
        // Ottieni i nomi delle stanze attive
        let roomNames = Set(activeFloor.rooms.map { $0.name })
        print("Room names:", roomNames)

        // Itera sui nodi figli del rootNode
        for roomNode in scnFloorView.scnView.scene!.rootNode.childNodes {
            // Controlla se il nodo è un nodo "Floor_" seguito dal nome della stanza
            guard let floorNodeName = roomNode.name,
                  floorNodeName.starts(with: "Floor_"),
                  let roomName = floorNodeName.split(separator: "_").last, // Estrai il nome della stanza
                  roomNames.contains(String(roomName))
            else {
                print("Error Continue: \(roomNode.name ?? "Unnamed Node")")
                continue
            }

            // Cerca un nodo figlio con il nome della stanza
            if let matchingChildNode = roomNode.childNode(withName: String(roomName), recursively: true) {
                // Converti la posizione rispetto al nodo figlio
                let localPosition = matchingChildNode.convertPosition(positionVector, from: nil)

                // Verifica se la posizione è contenuta
                if isPositionContained(localPosition, in: matchingChildNode) {
                    print("Position is contained in room: \(roomName)")
                    return matchingChildNode
                }
            } else {
                print("No matching child node found for room: \(roomName)")
            }
        }

        print("ERROR: Position not contained in any room.")
        return nil
    }
    
    private func isPositionContained(_ position: SCNVector3, in node: SCNNode) -> Bool {
        print("Check in \(node.name)")
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

        let hitResults = node.hitTestWithSegment(from: rayOrigin, to: rayEnd, options: hitTestOptions)
        return !hitResults.isEmpty
    }

    ///MARK: Check Room Position with Room Floor Intersecate (Dosn't work for Mascetti) 
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


extension SCNVector3 {
    func distance(to vector: SCNVector3) -> Float {
        return sqrt(
            pow(vector.x - self.x, 2) +
            pow(vector.y - self.y, 2) +
            pow(vector.z - self.z, 2)
        )
    }
}

extension SCNVector3 {
    /// Calcola il modulo (lunghezza) del vettore
    func length() -> Float {
        return sqrt(x * x + y * y + z * z)
    }
    
    /// Restituisce il vettore normalizzato
    func normalized() -> SCNVector3 {
        let length = self.length()
        return length == 0 ? SCNVector3(0, 0, 0) : SCNVector3(x / length, y / length, z / length)
    }
}

extension SCNVector4 {
    /// Calcola la rotazione necessaria per passare da `from` a `to`
    static func rotation(from fromVector: SCNVector3, to toVector: SCNVector3) -> SCNVector4 {
        let cross = fromVector.cross(to: toVector)
        let dot = fromVector.dot(to: toVector)
        let angle = acos(dot / (fromVector.length() * toVector.length()))
        
        // Se l'angolo è zero, nessuna rotazione è necessaria
        if angle.isNaN || angle == 0 {
            return SCNVector4(0, 1, 0, 0) // Nessuna rotazione
        }
        
        return SCNVector4(cross.x, cross.y, cross.z, angle)
    }
}

extension SCNVector3 {
    /// Calcola il prodotto vettoriale tra due vettori
    func cross(to vector: SCNVector3) -> SCNVector3 {
        return SCNVector3(
            y * vector.z - z * vector.y,
            z * vector.x - x * vector.z,
            x * vector.y - y * vector.x
        )
    }
    
    /// Calcola il prodotto scalare tra due vettori
    func dot(to vector: SCNVector3) -> Float {
        return x * vector.x + y * vector.y + z * vector.z
    }
}

extension float4x4 {
    static func rotationAroundY(_ angle: Float) -> float4x4 {
        let c = cos(angle)
        let s = sin(angle)

        return float4x4(columns: (
            simd_float4(c,  0, s, 0),
            simd_float4(0,  1, 0, 0),
            simd_float4(-s, 0, c, 0),
            simd_float4(0,  0, 0, 1)
        ))
    }
}

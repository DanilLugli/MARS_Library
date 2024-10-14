import Foundation
import RoomPlan
import SceneKit
import ARKit

@available(iOS 16.0, *)
@MainActor
public class LocationProvider: NSObject {
    
    var arView: ARSCNView
    var worldMap: ARWorldMap?
    public var building: Building?
    private var positionObservers: [PositionObserver]
    private var trState: TrackingState?
    
    // MARK: - Initialization
    
    /// Initializes the `LocationProvider` with an ARSCNView and a URL for loading building data.
    /// - Parameters:
    ///   - arView: The ARSCNView used for rendering the AR experience.
    ///   - url: The URL pointing to the building data to load.
    public init(arView: ARSCNView, url: URL) async {
        self.arView = arView
        self.positionObservers = []
        super.init()
        
        self.arView.delegate = self
        
        do {
            try await loadBuildings(from: url)
        } catch {
            print("Error uploading building: \(error)")
        }
    }
    
    // MARK: - Observer Management
    
    /// Adds a `PositionObserver` to the list of observers if not already added.
    /// - Parameter positionObserver: The observer to add.
    public func addLocationObserver(positionObserver: PositionObserver) {
        if !self.positionObservers.contains(where: { $0 === positionObserver }) {
            self.positionObservers.append(positionObserver)
        }
    }
    
    /// Removes a `PositionObserver` from the list of observers.
    /// - Parameter positionObserver: The observer to remove.
    public func removeLocationObserver(positionObserver: PositionObserver) {
        self.positionObservers = self.positionObservers.filter { $0 !== positionObserver }
    }
    
    // MARK: - Load Methods
    
    /// Loads building data from the given URL.
    /// - Parameter url: The URL pointing to the building directory.
    /// - Throws: Throws an error if no building data is found or if loading fails.
    private func loadBuildings(from url: URL) async throws {
        let fileManager = FileManager.default
        let buildingURLs = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles)
        for buildingURL in buildingURLs {
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: buildingURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
                
                let floors = try await loadFloors(from: buildingURL)
                let loadedBuilding = Building(name: buildingURL.lastPathComponent, floors: floors)
                
                // Assign loaded building to the building property
                self.building = loadedBuilding
                return
            }
        }
        
        throw NSError(domain: "com.example.error", code: 404, userInfo: [NSLocalizedDescriptionKey: "No building found"])
    }
    
    /// Loads floors from the specified building directory.
    /// - Parameter buildingURL: The URL of the building directory.
    /// - Returns: An array of loaded `Floor` objects.
    private func loadFloors(from buildingURL: URL) async throws -> [Floor] {
        let fileManager = FileManager.default
        let floorURLs = try fileManager.contentsOfDirectory(at: buildingURL, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles)
        
        var floors: [Floor] = []
        for floorURL in floorURLs {
            if isDirectory(at: floorURL) {
                // Create a Floor object
                
                let floor = Floor(
                    name: floorURL.lastPathComponent,
                    associationMatrix: try loadAssociationMatrix(from: floorURL) ?? [:],
                    rooms: [],
                    sceneObjects: [],
                    scene: SCNScene(),
                    planimetry: SCNViewContainer()
                )
                
                //Create a planimetry of Floor
                floor.planimetry.loadPlanimetry(scene: floor.scene, borders: true)
                
                // Load rooms asynchronously
                floor.rooms = try await loadRooms(from: floorURL, floor: floor)
                
                // Load scene if available
                if let usdzScene = try loadSceneIfAvailable(for: floor, url: floorURL) {
                    floor.scene = usdzScene
                }
                
                floors.append(floor)
            }
        }
        return floors
    }
    
    /// Loads rooms from a floor directory.
    /// - Parameters:
    ///   - floorURL: The URL of the floor directory.
    ///   - floor: The parent `Floor` object.
    /// - Returns: An array of loaded `Room` objects.
    private func loadRooms(from floorURL: URL, floor: Floor) async throws -> [Room] {
        let roomsDirectoryURL = floorURL.appendingPathComponent("Rooms")
        let roomURLs = try FileManager.default.contentsOfDirectory(at: roomsDirectoryURL, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles)
        
        var rooms: [Room] = []
        for roomURL in roomURLs {
            if isDirectory(at: roomURL) {
                
                let room = Room(
                    name: roomURL.lastPathComponent,
                    referenceMarkers: try loadReferenceMarkers(from: roomURL),
                    transitionZones: [],
                    scene: SCNScene(),
                    sceneObjects: [],
                    planimetry: SCNViewContainer(),
                    arWorldMap: nil,
                    roomURL: roomURL,
                    parentFloor: floor
                )
                
                // Load scene if available
                if let usdzScene = try loadSceneIfAvailable(for: room, url: roomURL) {
                    room.scene = usdzScene
                }
                
                //Create planimetry for Room
                room.planimetry.loadPlanimetry(scene: room.scene, borders: true)
                
                //Load ARWorldMap of Room
                self.worldMap = getWorldMap(url: roomURL.appendingPathComponent("Maps").appendingPathComponent("\(room.name).map"))
                
//                if let map = self.worldMap{
//                    loadWorldMap(worldMap: map, "\(room.name)")
//                    
//                }
                
                rooms.append(room)
            }
        }
        return rooms
    }
    
    // MARK: - File Utilities
    
    /// Loads the contents of a directory at the specified URL.
    /// - Parameter url: The directory URL.
    /// - Returns: An array of URLs for the files in the directory.
    private func loadContents(at url: URL) throws -> [URL] {
        let fileManager = FileManager.default
        return try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles)
    }
    
    /// Checks whether the specified URL is a directory.
    /// - Parameter url: The URL to check.
    /// - Returns: `true` if the URL is a directory, `false` otherwise.
    private func isDirectory(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
    
    // MARK: - JSON Parsing
    
    /// Loads the association matrix from the specified floor directory.
    /// - Parameter floorURL: The URL of the floor directory.
    /// - Returns: A dictionary mapping room names to roto-translation matrices, or `nil` if no matrix is found.
    private func loadAssociationMatrix(from floorURL: URL) throws -> [String: RotoTraslationMatrix]? {
        let associationMatrixURL = floorURL.appendingPathComponent("\(floorURL.lastPathComponent).json")
        guard FileManager.default.fileExists(atPath: associationMatrixURL.path) else {
            return nil
        }
        return loadRoomPositionFromJson(from: associationMatrixURL)
    }
    
    /// Loads the room position matrix from a JSON file.
    /// - Parameter fileURL: The URL of the JSON file.
    /// - Returns: A dictionary mapping room names to roto-translation matrices.
    private func loadRoomPositionFromJson(from fileURL: URL) -> [String: RotoTraslationMatrix]? {
        do {
            let data = try Data(contentsOf: fileURL)
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
            guard let jsonDict = jsonObject as? [String: [String: [[Double]]]] else {
                print("Invalid JSON format")
                return nil
            }
            
            var associationMatrix: [String: RotoTraslationMatrix] = [:]
            
            for (roomName, matrices) in jsonDict {
                guard let translationMatrix = matrices["translation"],
                      let r_YMatrix = matrices["R_Y"],
                      translationMatrix.count == 4,
                      r_YMatrix.count == 4 else {
                    print("Invalid JSON structure for room: \(roomName)")
                    continue
                }
                
                let translation = simd_float4x4(rows: translationMatrix.map { simd_float4($0.map { Float($0) }) })
                let r_Y = simd_float4x4(rows: r_YMatrix.map { simd_float4($0.map { Float($0) }) })
                
                let rotoTraslationMatrix = RotoTraslationMatrix(name: roomName, translation: translation, r_Y: r_Y)
                associationMatrix[roomName] = rotoTraslationMatrix
            }
            
            return associationMatrix
            
        } catch {
            print("Error loading or parsing JSON: \(error)")
            return nil
        }
    }
    
    // MARK: - Scene and Marker Loading
    
    /// Loads reference markers from a room directory.
    /// - Parameter roomURL: The URL of the room directory.
    /// - Returns: An array of `ReferenceMarker` objects.
    private func loadReferenceMarkers(from roomURL: URL) throws -> [ReferenceMarker] {
        let referenceMarkerURL = roomURL.appendingPathComponent("ReferenceMarker")
        guard FileManager.default.fileExists(atPath: referenceMarkerURL.path) else {
            return []
        }
        
        let markerFiles = try loadContents(at: referenceMarkerURL)
        var referenceMarkers: [ReferenceMarker] = []
        for fileURL in markerFiles {
            if fileURL.pathExtension.lowercased() == "jpg" || fileURL.pathExtension.lowercased() == "png" {
                let marker = ReferenceMarker(imageName: fileURL.deletingPathExtension().lastPathComponent)
                referenceMarkers.append(marker)
            }
        }
        
        return referenceMarkers
    }
    
    /// Loads a USDZ scene if available for the given floor or room.
    /// - Parameters:
    ///   - item: The floor or room to load the scene for.
    ///   - url: The URL where the scene is located.
    /// - Returns: The loaded SCNScene, or `nil` if no scene is found.
    private func loadSceneIfAvailable(for item: AnyObject, url: URL) throws -> SCNScene? {
        let usdzPath: String
        let name = (item as? Floor)?.name ?? (item as? Room)?.name
        guard let sceneName = name else { return nil }
        usdzPath = url.appendingPathComponent("MapUsdz").appendingPathComponent("\(sceneName).usdz").path
        
        guard FileManager.default.fileExists(atPath: usdzPath) else {
            print("USDZ file not found for \(sceneName)")
            return nil
        }
        
        return try SCNScene(url: URL(fileURLWithPath: usdzPath))
    }
    
    // MARK: - Observer Notification
    
    /// Notifies all observers of a room change.
    /// - Parameter newRoom: The new room that was detected.
    private func notifyRoomChanged(newRoom: Room) {
        for positionObserver in self.positionObservers {
            positionObserver.onRoomChanged(newRoom)
        }
    }
    
    /// Notifies all observers of a floor change.
    /// - Parameter newFloor: The new floor that was detected.
    private func notifyFloorChanged(newFloor: Floor) {
        for positionObserver in self.positionObservers {
            positionObserver.onFloorChanged(newFloor)
        }
    }
    
    /// Notifies all observers of a location update.
    /// - Parameter newLocation: The new location of the user.
    private func notifyLocationUpdate(newLocation: Position) {
        for positionObserver in self.positionObservers {
            positionObserver.onLocationUpdate(newLocation)
        }
    }
    
    /// Notifies all observers of a tracking state change.
    /// - Parameter trackingState: The new tracking state.
    private func notifyTrackingStateChanged(_ trackingState: TrackingState) {
        switch trackingState.state {
        case .normal:
            print("Tracking normal")
        case .limited(let reason):
            print("Tracking limited: \(reason)")
        case .notAvailable:
            print("Tracking not available")
        @unknown default:
            print("Unknown tracking state")
        }
    }
    
    // MARK: - Create ARWorldMap
    
    func loadWorldMap(worldMap: ARWorldMap, _ filename: String) {
        
        // Configurazione AR
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        
        let options: ARSession.RunOptions = [.resetTracking, .removeExistingAnchors]
        var id = 0
        
        if let data = try? Data(contentsOf: URL(fileURLWithPath: filename)) {
            if let room = try? JSONDecoder().decode(CapturedRoom.self, from: data) {
                // Aggiungi le ancore per le porte
                for e in room.doors {
                    worldMap.anchors.append(ARAnchor(name: "door\(id)", transform: e.transform))
                    id += 1
                }
                // Aggiungi le ancore per le pareti
                for e in room.walls {
                    worldMap.anchors.append(ARAnchor(name: "wall\(id)", transform: e.transform))
                    id += 1
                }
            }
        }
        
        configuration.initialWorldMap = worldMap
        
        arView.debugOptions = [.showFeaturePoints, .showWorldOrigin]
        arView.session.run(configuration, options: options)
        
        // Se disponibile, imposta l'origine globale in base alla posizione e rotazione dell'utente
        //        if let p = Model.shared.lastKnowPositionInGlobalSpace, let a = Model.shared.actualRoto {
        //            var originInGlobalSpace = Model.shared.origin.copy() as! SCNNode
        //            originInGlobalSpace = projectNode(originInGlobalSpace, a)
        //
        //            let Transl_Rot = PtoO_Pspace(T_P: p.simdWorldTransform, T_O: originInGlobalSpace.simdWorldTransform)
        //            let newOrig = Model.shared.origin.copy() as! SCNNode
        //            newOrig.simdPosition = Transl_Rot.0
        //            newOrig.simdLocalRotate(by: simd_quatf(angle: GLKMathDegreesToRadians(Transl_Rot.1), axis: [0, 1, 0]))
        //            arView.session.setWorldOrigin(relativeTransform: newOrig.simdWorldTransform)
        //
        //            NotificationCenter.default.post(name: .genericMessage2, object: "translation: \(Transl_Rot.0)\nrotation: \(Transl_Rot.1)")
        //        }
    }
    
    func getWorldMap(url: URL) -> ARWorldMap? {
        print("CHECK URL: \(url)")
        do {
            let mapData = try Data(contentsOf: url)
            
            if let worldMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: mapData) {
                return worldMap
            }
        } catch {
            print("Error upload ARWorldMap: \(error)")
        }
        
        return nil
    }
    
    
    
    // MARK: - Manage Position User
    
    public func overlapPositionRoom(_ position: SCNNode, _ room: SCNNode) -> Bool {
        let (minA, maxA) = position.boundingBox
        let (minB, maxB) = room.boundingBox
        
        let worldMinA = position.convertPosition(SCNVector3(minA.x, minA.y, minA.z), to: nil)
        let worldMaxA = position.convertPosition(SCNVector3(maxA.x, maxA.y, maxA.z), to: nil)
        
        let worldMinB = room.convertPosition(SCNVector3(minB.x, minB.y, minB.z), to: nil)
        let worldMaxB = room.convertPosition(SCNVector3(maxB.x, maxB.y, maxB.z), to: nil)
        
        let isOverlappingX = worldMinA.x <= worldMaxB.x && worldMaxA.x >= worldMinB.x
        let isOverlappingY = worldMinA.y <= worldMaxB.y && worldMaxA.y >= worldMinB.y
        let isOverlappingZ = worldMinA.z <= worldMaxB.z && worldMaxA.z >= worldMinB.z
        
        return isOverlappingX && isOverlappingY && isOverlappingZ
    }
    
    public func checkRoomChange(for positionNode: SCNNode, currentRoom: SCNNode?, allRooms: [SCNNode]) -> SCNNode? {
        
        if let currentRoom = currentRoom, overlapPositionRoom(positionNode, currentRoom) {
            return currentRoom
        }
        
        for room in allRooms {
            if overlapPositionRoom(positionNode, room) {
                print("La posizione è ora sovrapposta con la room: \(room.name ?? "Unnamed Room")")
                return room
            }
        }
        return nil
    }
    
    public func updatePosition(_ pos: simd_float4x4, _ rototraslation: RotoTraslationMatrix?, scnView: SCNView) {
        
        //remove position node
        scnView.scene?
            .rootNode
            .childNodes
            .filter({ $0.name == "UserPosition" })
            .forEach({ $0.removeFromParentNode() })
        
        //add position node
        var sphere = generateSphereNode(UIColor(red: 0, green: 0, blue: 255, alpha: 1.0), 0.2)
        print(sphere.position)
        
        //sphere.rotation.x = 0
        //sphere.rotation.z = 0
        //sphere.simdWorldPosition = simd_float3(pos.columns.3.x, pos.columns.3.y, pos.columns.3.z)
        sphere.simdWorldTransform = pos
        sphere.simdLocalRotate(by: simd_quatf(angle: GLKMathDegreesToRadians(90.0), axis: [0,0,1]))
        
        if let r = rototraslation {
            
            sphere = projectNode(sphere, r)
            
            //TODO: Da scommentare
            //Model.shared.lastKnowPositionInGlobalSpace = sphere
            
            //draw origin in global space
            scnView.scene?
                .rootNode
                .childNodes
                .filter({ $0.name == "ORIGININGLOBALSPACE" }).forEach({ $0.removeFromParentNode() })
            
            var O = generateSphereNode(UIColor(red: 0, green: 255, blue: 0, alpha: 1.0), 0.2)
            //TODO: DA scommentare
            //O.simdWorldTransform = (Model.shared.origin.copy() as! SCNNode).simdWorldTransform
            
            //O.simdLocalRotate(by: simd_quatf(angle: GLKMathDegreesToRadians(90.0), axis: [0,0,1]))
            O = projectNode(O, r)
            O.name = "ORIGININGLOBALSPACE"
            scnView.scene?.rootNode.addChildNode(O)
            
        }
        sphere.name = "UserPosition"
        scnView.scene?.rootNode.addChildNode(sphere)
    }
    
    private func projectNode(_ sphere: SCNNode, _ r: RotoTraslationMatrix) -> SCNNode {
        sphere.simdWorldTransform.columns.3 = sphere.simdWorldTransform.columns.3 * r.translation
        
        let r_Y = simd_float3x3([
            simd_float3(r.r_Y.columns.0.x, r.r_Y.columns.0.y, r.r_Y.columns.0.z),
            simd_float3(r.r_Y.columns.1.x, r.r_Y.columns.1.y, r.r_Y.columns.1.z),
            simd_float3(r.r_Y.columns.2.x, r.r_Y.columns.2.y, r.r_Y.columns.2.z),
        ])
        
        var rot = simd_float3x3([
            simd_float3(sphere.simdWorldTransform.columns.0.x, sphere.simdWorldTransform.columns.0.y, sphere.simdWorldTransform.columns.0.z),
            simd_float3(sphere.simdWorldTransform.columns.1.x, sphere.simdWorldTransform.columns.1.y, sphere.simdWorldTransform.columns.1.z),
            simd_float3(sphere.simdWorldTransform.columns.2.x, sphere.simdWorldTransform.columns.2.y, sphere.simdWorldTransform.columns.2.z),
        ])
        
        rot = r_Y * rot
        
        sphere.simdWorldTransform.columns.0 = simd_float4(
            rot.columns.0.x,
            rot.columns.0.y,
            rot.columns.0.z,
            sphere.simdWorldTransform.columns.0.z
        )
        sphere.simdWorldTransform.columns.1 = simd_float4(
            rot.columns.1.x,
            rot.columns.1.y,
            rot.columns.1.z,
            sphere.simdWorldTransform.columns.1.z
        )
        sphere.simdWorldTransform.columns.2 = simd_float4(
            rot.columns.2.x,
            rot.columns.2.y,
            rot.columns.2.z,
            sphere.simdWorldTransform.columns.2.z
        )
        
        return sphere
    }
    
    private func generateSphereNode(_ color: UIColor, _ radius: CGFloat) -> SCNNode {
        
        let houseNode = SCNNode() //3 Sphere
        let sphere = SCNSphere(radius: radius)
        //let sphere = SCNPyramid(width: radius, height: radius*2, length: radius)
        let sphereNode = SCNNode()
        sphereNode.geometry = sphere
        sphereNode.geometry?.firstMaterial?.diffuse.contents = color
        
        let sphere2 = SCNSphere(radius: radius)
        //let sphere = SCNPyramid(width: radius, height: radius*2, length: radius)
        let sphereNode2 = SCNNode()
        sphereNode2.geometry = sphere2
        var color2 = color
        sphereNode2.geometry?.firstMaterial?.diffuse.contents = color2.withAlphaComponent(color2.cgColor.alpha - 0.3)
        sphereNode2.position = SCNVector3(0, 0, -1)
        
        let sphere3 = SCNSphere(radius: radius)
        //let sphere = SCNPyramid(width: radius, height: radius*2, length: radius)
        let sphereNode3 = SCNNode()
        sphereNode3.geometry = sphere3
        var color3 = color
        sphereNode3.geometry?.firstMaterial?.diffuse.contents = color2.withAlphaComponent(color2.cgColor.alpha - 0.6)
        sphereNode3.position = SCNVector3(-0.5, 0, 0)
        
        
        houseNode.addChildNode(sphereNode)
        houseNode.addChildNode(sphereNode2)
        houseNode.addChildNode(sphereNode3)
        return houseNode
    }
    
}

// MARK: - ARSCNViewDelegate
@available(iOS 16.0, *)
@MainActor
extension LocationProvider: @preconcurrency ARSCNViewDelegate {
    nonisolated public func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        //
    }
    
    @MainActor
    public func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        if let camera = self.arView.session.currentFrame?.camera {
            
            //Position Update
            let newLocation = Position(position: camera.transform)
            notifyLocationUpdate(newLocation: newLocation)
            
            
            //Tracking State Update
            let newTrackingState = camera.trackingState
            if #available(iOS 16.0, *) {
                if trState?.state == newTrackingState { return }
            } else {
                //
            }
            trState = TrackingState(state: newTrackingState)
            if let updatedTrackingState = trState {
                notifyTrackingStateChanged(updatedTrackingState)
            }
        }
    }
}

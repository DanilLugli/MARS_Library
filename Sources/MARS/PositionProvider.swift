import Foundation
import RoomPlan
import SceneKit
import ARKit

public class LocationProvider: NSObject {

    var arView: ARSCNView
    var building: Building?
    
    private var positionObservers: [PositionObserver] // list of Observers who will be notified of the change of position
    
    // MARK: - Inizializzatore
    public init(arView: ARSCNView, url: URL) async {
        self.arView = arView
        self.positionObservers = []
        super.init()
        
        do {
            try await loadBuildings(from: url)
        } catch {
            print("Errore durante il caricamento del building: \(error)")
        }
    }
    
    /// Adds the specified LocationObserver to the list of observers who will be notified
    public func addLocationObserver(positionObserver: PositionObserver) {
        self.positionObservers.append(positionObserver)
    }
    
    /// Removes the specified LocationObserver from the list of observers
    public func removeLocationObserver(positionObserver: PositionObserver) {
        self.positionObservers = self.positionObservers.filter{$0 !== positionObserver}
    }
    
    
    // MARK: - Metodi principali di caricamento
    
    // Metodo che carica gli edifici in modo asincrono
    private func loadBuildings(from url: URL) async throws {
        let fileManager = FileManager.default
        let buildingURLs = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles)
        
        for buildingURL in buildingURLs {
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: buildingURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
                let floors = try await loadFloors(from: buildingURL)
                let loadedBuilding = Building(name: buildingURL.lastPathComponent, floors: floors)
                
                // Assegna l'edificio caricato alla proprietà building
                self.building = loadedBuilding
                return
            }
        }
        
        throw NSError(domain: "com.example.error", code: 404, userInfo: [NSLocalizedDescriptionKey: "No building found"])
    }
    
    // Metodo asincrono che carica i piani
    private func loadFloors(from buildingURL: URL) async throws -> [Floor] {
        let fileManager = FileManager.default
        let floorURLs = try fileManager.contentsOfDirectory(at: buildingURL, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles)
        
        var floors: [Floor] = []
        for floorURL in floorURLs {
            if isDirectory(at: floorURL) {
                // Crea un oggetto Floor
                let floor = Floor(
                    name: floorURL.lastPathComponent,
                    associationMatrix: try loadAssociationMatrix(from: floorURL) ?? [:],
                    rooms: [],
                    sceneObjects: [],
                    scene: SCNScene()
                )
                
                // Carica le stanze in modo asincrono
                floor.rooms = try await loadRooms(from: floorURL, floor: floor)
                
                // Carica la scena se disponibile
                if let usdzScene = try loadSceneIfAvailable(for: floor, url: floorURL) {
                    floor.scene = usdzScene
                }
                
                floors.append(floor)
            }
        }
        return floors
    }
    
    // Metodo asincrono che carica le stanze
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
                    roomURL: roomURL,
                    parentFloor: floor
                )
                
                // Carica la scena se disponibile
                if let usdzScene = try loadSceneIfAvailable(for: room, url: floorURL) {
                    room.scene = usdzScene
                }
                
                rooms.append(room)
            }
        }
        return rooms
    }
    
    
    // MARK: - Utilità per la gestione dei file
    
    // Funzione che carica i contenuti della directory
    private func loadContents(at url: URL) throws -> [URL] {
        let fileManager = FileManager.default
        return try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles)
    }
    
    // Metodo che verifica se il path è una directory
    private func isDirectory(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
    
    // MARK: - Caricamento JSON
    
    private func loadAssociationMatrix(from floorURL: URL) throws -> [String: RotoTraslationMatrix]? {
        let associationMatrixURL = floorURL.appendingPathComponent("\(floorURL.lastPathComponent).json")
        guard FileManager.default.fileExists(atPath: associationMatrixURL.path) else {
            return nil
        }
        return loadRoomPositionFromJson(from: associationMatrixURL)
    }
    
    func loadRoomPositionFromJson(from fileURL: URL) -> [String: RotoTraslationMatrix]? {
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
    
    // MARK: - Caricamento di scene e marker
    
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
    
    private func notifyRoomChanged(newRoom: Room) {
        for positionObserver in self.positionObservers {
            positionObserver.onRoomChanged(newRoom)
        }
    }
    
    private func notifyFloorChanged(newFloor: Floor) {
        for positionObserver in self.positionObservers {
            positionObserver.onFloorChanged(newFloor)
        }
    }
    
    private func notifyLocationUpdate(newLocation: Position) {
        for positionObserver in self.positionObservers {
            positionObserver.onLocationUpdate(newLocation)
        }
    }
    
}

extension LocationProvider: ARSCNViewDelegate {
    public func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        // Implementazione della gestione dell'aggiunta di un nodo
    }
    
    public func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
//        if let camera = self.sceneView?.session.currentFrame?.camera {
//            DispatchQueue.main.async {NotificationCenter.default.post(name: .trackingPosition, object:
//                                                                        camera.transform)}
//        }
//        
//        if trState == self.sceneView?.session.currentFrame?.camera.trackingState{return}
//        
//        trState = self.sceneView?.session.currentFrame?.camera.trackingState
//        
//        DispatchQueue.main.async {
//            NotificationCenter.default.post(name: .trackingState, object: self.trState)
//        }
    }
}


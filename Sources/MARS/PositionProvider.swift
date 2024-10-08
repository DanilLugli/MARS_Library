import Foundation
import RoomPlan
import SceneKit
import ARKit

class LocationProvider: NSObject {
    // MARK: - Proprietà
    private var arView: ARSCNView
    private var building: Building?
    
    // MARK: - Inizializzatore
    init(arView: ARSCNView, url: URL) {
        self.arView = arView
        super.init()

        do {
            try loadBuildings(from: url)
        } catch {
            print("Errore durante il caricamento del building: \(error)")
        }
    }

    // MARK: - Metodi principali di caricamento

    // Metodo che carica gli edifici
    private func loadBuildings(from url: URL) throws {
        let buildingURLs = try loadContents(at: url)
        
        for buildingURL in buildingURLs {
            guard isDirectory(at: buildingURL) else { continue }
            
            let floors = try loadFloors(from: buildingURL)
            let loadedBuilding = Building(name: buildingURL.lastPathComponent, floors: floors)
            self.building = loadedBuilding
            return
        }
        
        throw NSError(domain: "com.example.error", code: 404, userInfo: [NSLocalizedDescriptionKey: "No building found"])
    }

    // Metodo che carica i piani
    private func loadFloors(from buildingURL: URL) throws -> [Floor] {
        let floorURLs = try loadContents(at: buildingURL)
        
        var floors: [Floor] = []
        for floorURL in floorURLs {
            guard isDirectory(at: floorURL) else { continue }
            
            let associationMatrix = try loadAssociationMatrix(from: floorURL)
            
            let floor = Floor(
                name: floorURL.lastPathComponent,
                associationMatrix: associationMatrix ?? [:],
                rooms: [],
                sceneObjects: [],
                scene: SCNScene()
            )
            
            floor.rooms = try loadRooms(from: floorURL, floor: floor)
            
            if let usdzScene = try loadSceneIfAvailable(for: floor, url: floorURL) {
                floor.scene = usdzScene
            }
            
            floors.append(floor)
        }
        return floors
    }

    // Metodo che carica le stanze
    private func loadRooms(from floorURL: URL, floor: Floor) throws -> [Room] {
        let roomsDirectoryURL = floorURL.appendingPathComponent("Rooms")
        let roomURLs = try loadContents(at: roomsDirectoryURL)
        
        var rooms: [Room] = []
        for roomURL in roomURLs {
            guard isDirectory(at: roomURL) else { continue }
            
            let referenceMarkers = try loadReferenceMarkers(from: roomURL)
            
            let room = Room(
                name: roomURL.lastPathComponent,
                referenceMarkers: referenceMarkers,
                transitionZones: [],
                scene: SCNScene(),
                sceneObjects: [],
                roomURL: roomURL,
                parentFloor: floor
            )
            
            if let usdzScene = try loadSceneIfAvailable(for: room, url: floorURL) {
                room.scene = usdzScene
            }
            
            rooms.append(room)
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
}

extension LocationProvider: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        // Implementazione della gestione dell'aggiunta di un nodo
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        // Implementazione dell'aggiornamento del nodo
    }
}

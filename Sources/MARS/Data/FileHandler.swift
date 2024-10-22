//
//  File.swift
//  MARS
//
//  Created by Danil Lugli on 15/10/24.
//

import Foundation

import Foundation
import ARKit

@available(iOS 16.0, *)
struct FileHandler {

    // MARK: - Load Methods
    
    /// Loads building data from the given URL.
    /// - Parameter url: The URL pointing to the building directory.
    /// - Throws: Throws an error if no building data is found or if loading fails.
    public static func loadBuildings(from url: URL) async throws -> Building{
        let fileManager = FileManager.default
        let buildingURLs = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles)
        for buildingURL in buildingURLs {
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: buildingURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
                
                let floors = try await loadFloors(from: buildingURL)
                let loadedBuilding = Building(name: buildingURL.lastPathComponent, floors: floors)
                
                // Assign loaded building to the building property
                return loadedBuilding
                //return
            }
        }
        
        throw NSError(domain: "com.example.error", code: 404, userInfo: [NSLocalizedDescriptionKey: "No building found"])
    }
    
    /// Loads floors from the specified building directory.
    /// - Parameter buildingURL: The URL of the building directory.
    /// - Returns: An array of loaded `Floor` objects.
    private static func loadFloors(from buildingURL: URL) async throws -> [Floor] {
        let fileManager = FileManager.default
        let floorURLs = try fileManager.contentsOfDirectory(at: buildingURL, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles)
        
        var floors: [Floor] = []
        for floorURL in floorURLs {
            if isDirectory(at: floorURL) {
                // Create a Floor object
                let scene = SCNScene()
                let floor = Floor(
                    name: floorURL.lastPathComponent,
                    associationMatrix: try loadAssociationMatrix(from: floorURL) ?? [:],
                    rooms: [],
                    sceneObjects: [],
                    scene: scene
                )
               
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
    private static func loadRooms(from floorURL: URL, floor: Floor) async throws -> [Room] {
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
                    arWorldMap: nil,
                    roomURL: roomURL,
                    parentFloor: floor
                )
                
                // Load scene if available
                if let usdzScene = try loadSceneIfAvailable(for: room, url: roomURL) {
                    room.scene = usdzScene
                }
                
                
                //Load ARWorldMap of Room
                room.arWorldMap = getWorldMap(url: roomURL.appendingPathComponent("Maps").appendingPathComponent("\(room.name).map"))
                
                rooms.append(room)
            }
        }
        return rooms
    }
    
    // MARK: - File Utilities
    
    /// Loads the contents of a directory at the specified URL.
    /// - Parameter url: The directory URL.
    /// - Returns: An array of URLs for the files in the directory.
    private static func loadContents(at url: URL) throws -> [URL] {
        let fileManager = FileManager.default
        return try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles)
    }
    
    /// Checks whether the specified URL is a directory.
    /// - Parameter url: The URL to check.
    /// - Returns: `true` if the URL is a directory, `false` otherwise.
    private static func isDirectory(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
    
    // MARK: - JSON Parsing
    
    /// Loads the association matrix from the specified floor directory.
    /// - Parameter floorURL: The URL of the floor directory.
    /// - Returns: A dictionary mapping room names to roto-translation matrices, or `nil` if no matrix is found.
    private static func loadAssociationMatrix(from floorURL: URL) throws -> [String: RotoTraslationMatrix]? {
        let associationMatrixURL = floorURL.appendingPathComponent("\(floorURL.lastPathComponent).json")
        guard FileManager.default.fileExists(atPath: associationMatrixURL.path) else {
            return nil
        }
        return loadRoomPositionFromJson(from: associationMatrixURL)
    }
    
    /// Loads the room position matrix from a JSON file.
    /// - Parameter fileURL: The URL of the JSON file.
    /// - Returns: A dictionary mapping room names to roto-translation matrices.
    private static func loadRoomPositionFromJson(from fileURL: URL) -> [String: RotoTraslationMatrix]? {
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
    private static func loadReferenceMarkers(from roomURL: URL) throws -> [ReferenceMarker] {
        let referenceMarkerURL = roomURL.appendingPathComponent("ReferenceMarker")
        guard FileManager.default.fileExists(atPath: referenceMarkerURL.path) else {
            return []
        }
        
        let markerFiles = try loadContents(at: referenceMarkerURL)
        var referenceMarkers: [ReferenceMarker] = []
        for fileURL in markerFiles {
            if fileURL.pathExtension.lowercased() == "jpg" || fileURL.pathExtension.lowercased() == "png" {
                if let image = UIImage(contentsOfFile: fileURL.path) {
                    let marker = ReferenceMarker(image: image, physicalWidth: 0.0)
                    referenceMarkers.append(marker)
                } else {
                    print("Failed to load image from: \(fileURL.path)")
                }
            }
        }
        
        return referenceMarkers
    }
    
    /// Loads a USDZ scene if available for the given floor or room.
    /// - Parameters:
    ///   - item: The floor or room to load the scene for.
    ///   - url: The URL where the scene is located.
    /// - Returns: The loaded SCNScene, or `nil` if no scene is found.
    private static func loadSceneIfAvailable(for item: AnyObject, url: URL) throws -> SCNScene? {
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
    
    static func getWorldMap(url: URL) -> ARWorldMap? {
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
    
//    func getWorldMap(url: URL) -> ARWorldMap? {
//        guard let mapData = try? Data(contentsOf: url), let worldMap = try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: mapData) else {
//            return nil
//        }
//        return worldMap
//    }
}

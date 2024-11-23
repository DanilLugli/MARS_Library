//
//  File.swift
//  MARS
//
//  Created by Danil Lugli on 15/10/24.
//

import Foundation
import ARKit
import RoomPlan
import SwiftUICore

@available(iOS 16.0, *)
@MainActor
struct FileHandler {
    
    // MARK: - Load Methods
    
    /// Loads building data from the given URL.
    /// - Parameter url: The URL pointing to the building directory.
    /// - Throws: Throws an error if no building data is found or if loading fails.
    public static func loadBuildings(from url: URL) throws -> Building{
        let fileManager = FileManager.default
        
        let buildingURLs = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles)
        for buildingURL in buildingURLs {
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: buildingURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
                print(buildingURL)
                let floors = try loadFloors(from: buildingURL)
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
    private static func loadFloors(from buildingURL: URL) throws -> [Floor] {
        let fileManager = FileManager.default
        let floorURLs = try fileManager.contentsOfDirectory(at: buildingURL, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles)
        
        var floors: [Floor] = []
        for floorURL in floorURLs {
            if isDirectory(at: floorURL) {
                let scene = SCNScene()
                let floor = Floor(
                    name: floorURL.lastPathComponent,
                    associationMatrix: try loadAssociationMatrix(from: floorURL) ?? [:],
                    rooms: [],
                    sceneObjects: [],
                    scene: scene
                )
                
                floor.rooms = try loadRooms(from: floorURL, floor: floor)
                
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
    private static func loadRooms(from floorURL: URL, floor: Floor) throws -> [Room] {
        let roomsDirectoryURL = floorURL.appendingPathComponent("Rooms")
        let roomURLs = try FileManager.default.contentsOfDirectory(at: roomsDirectoryURL, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles)
        
        var rooms: [Room] = []
        for roomURL in roomURLs {
            print(roomURL)
            if isDirectory(at: roomURL) {
                
                var room = Room(
                    name: roomURL.lastPathComponent,
                    referenceMarkers: try loadReferenceMarkers(from: roomURL),
                    transitionZones: [],
                    scene: SCNScene(),
                    planimetry: SCNViewContainer(),
                    sceneObjects: [],
                    sceneAnchor: [],
                    arWorldMap: nil,
                    roomURL: roomURL,
                    parentFloor: floor
                )
                
                if let usdzScene = try loadSceneIfAvailable(for: room, url: roomURL) {
                   
                    room.scene = usdzScene

                    room.planimetry?.loadPlanimetry(scene: usdzScene, roomsNode: nil, borders: true, nameCaller: room.name)
                    
                }
                
                func countNodesRecursively(in node: SCNNode) -> Int {
                    return 1 + node.childNodes.reduce(0) { $0 + countNodesRecursively(in: $1) }
                }
                func printNodeNamesRecursively(from node: SCNNode, depth: Int = 0) {
                    let indentation = String(repeating: "  ", count: depth)
                    print("\(indentation)- \(node.name ?? "Unnamed Node")")
                    node.childNodes.forEach { printNodeNamesRecursively(from: $0, depth: depth + 1) }
                }
                
                let mapFileWithExtension = roomURL.appendingPathComponent("Maps").appendingPathComponent("\(room.name).map")
                let mapFileWithoutExtension = roomURL.appendingPathComponent("Maps").appendingPathComponent(room.name)
                
                if FileManager.default.fileExists(atPath: mapFileWithExtension.path) {
                    guard let mapData = try? Data(contentsOf: mapFileWithExtension),
                          let worldMap = try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: mapData)
                    else {
                        print("Failed to load ARWorldMap from \(mapFileWithExtension.path)")
                        continue
                    }
                   
                    room.arWorldMap = worldMap
                    
                } else if FileManager.default.fileExists(atPath: mapFileWithoutExtension.path) {
                    guard let mapData = try? Data(contentsOf: mapFileWithoutExtension),
                          let worldMap = try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: mapData)
                    else {
                        print("Failed to load ARWorldMap from \(mapFileWithoutExtension.path)")
                        continue
                    }
                    room.arWorldMap = worldMap
                }
                else {
                    print("File ARWorldMap for \(room.name) not found.")
                }
                
                var id = 0
                if let data = try? Data(contentsOf: roomURL.appending(path: "JsonParametric").appending(path: room.name)) {
                    if let roomData = try? JSONDecoder().decode(CapturedRoom.self, from: data) {
                        for doorAnchor in roomData.doors {
                            room.sceneAnchor.append(ARAnchor(name: "door\(id)", transform: doorAnchor.transform))
                            room.arWorldMap!.anchors.append(ARAnchor(name: "door\(id)", transform: doorAnchor.transform))
                            id = id+1
                        }
                        for roomAnchor in roomData.walls {
                            room.sceneAnchor.append(ARAnchor(name: "wall\(id)", transform: roomAnchor.transform))
                            room.arWorldMap!.anchors.append(ARAnchor(name: "wall\(id)", transform: roomAnchor.transform))
                            id = id+1
                        }
                    }
                }
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
    /// Loads reference markers from a room directory, including their room name and physical width.
    private static func loadReferenceMarkers(from roomURL: URL) throws -> [ReferenceMarker] {

        let fileManager = FileManager.default
        var referenceMarkers: [ReferenceMarker] = []
        
        let referenceMarkerURL = roomURL.appendingPathComponent("ReferenceMarker")
        let markerDataURL = referenceMarkerURL.appendingPathComponent("Marker Data.json")
        
        guard FileManager.default.fileExists(atPath: markerDataURL.path) else {
            print("Marker data JSON file not found at: \(markerDataURL.path)")
            return []
        }
        
        let decoder = JSONDecoder()
        var markersData: [String: ReferenceMarker.MarkerData] = [:]
        
        let referenceMarkerContents = try fileManager.contentsOfDirectory(at: referenceMarkerURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
        if fileManager.fileExists(atPath: markerDataURL.path) {
            let jsonData = try Data(contentsOf: markerDataURL)
            markersData = try JSONDecoder().decode([String: ReferenceMarker.MarkerData].self, from: jsonData)
        }
        
        for fileURL in referenceMarkerContents {
            if fileURL.pathExtension.lowercased() == "jpg" || fileURL.pathExtension.lowercased() == "png" || fileURL.pathExtension.lowercased() == "jpeg" {
                let possibleExtensions = ["png", "jpg", "jpeg", "PNG", "JPG", "JPEG"]
                var imageFound = false
                
                let imageName = fileURL.deletingPathExtension().lastPathComponent
                let imagePath = fileURL
                
                let markerWidth = markersData[imageName]?.width ?? 0.0
                let markerName = markersData[imageName]?.name ?? imageName
                
                let newMarker = ReferenceMarker(
                    width: markerWidth, name: markerName
                )
                
                for ext in possibleExtensions {
                    let imageURL = referenceMarkerURL.appendingPathComponent(newMarker.name).appendingPathExtension(ext)
                    
                    if FileManager.default.fileExists(atPath: imageURL.path),
                       let image = UIImage(contentsOfFile: imageURL.path) {

                        newMarker.loadImage(from: image)
                        imageFound = true
                        referenceMarkers.append(newMarker)
                        break
                        
                    }
                }
                if !imageFound {
                    print("Immagine non trovata per il marker con nome \(newMarker.name) in \(referenceMarkerURL.path)")
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
    static func loadSceneIfAvailable(for item: AnyObject, url: URL) throws -> SCNScene? {
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

}

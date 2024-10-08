//
//  PositionProvider.swift
//
//
//  Created by Danil Lugli on 03/10/24.
//

/**
 Questa è la classe che:
 1. Importa tutti i dati per la creazione della mappe
 2. Inizializza tutti i dati
 3. Calcola la posizione
 4. Aggiorna tutti gli Observer per il calcolo della posizione
 */

import Foundation
import RoomPlan
import SceneKit
import ARKit

class LocationProvider: NSObject {
    private var arView: ARSCNView
    //private var floor: SCNScene
    
    init(arView: ARSCNView, url: URL) {
        self.arView = arView
        
        //super.init()
        
        //        if let scene = floor.planimetry {
        //            arView.scene = scene
        //        }
        //
        //        arView.delegate = self
        //    }
        
        //    //Caricamento dati
        //    @MainActor
        //    func loadBuildingsFromRoot() throws {
        //        let fileManager = FileManager.default
        //
        //        let buildingURLs = try fileManager.contentsOfDirectory(at: BuildingModel.SCANBUILD_ROOT, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles)
        //
        //        for buildingURL in buildingURLs {
        //            if isDirectory(at: buildingURL) {
        //                let lastModifiedDate = try getLastModifiedDate(for: buildingURL)
        //                let floors = try loadFloors(from: buildingURL)
        //                let building = Building(name: buildingURL.lastPathComponent, lastUpdate: lastModifiedDate, floors: floors, buildingURL: buildingURL)
        //                addBuilding(building: building)
        //            }
        //        }
        //    }
        //
        //    @MainActor
        //    func loadFloors(from buildingURL: URL) throws -> [Floor] {
        //        let fileManager = FileManager.default
        //        let floorURLs = try fileManager.contentsOfDirectory(at: buildingURL, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles)
        //
        //        var floors: [Floor] = []
        //        for floorURL in floorURLs {
        //            if isDirectory(at: floorURL) {
        //                let lastModifiedDate = try getLastModifiedDate(for: floorURL)
        //
        //                // Load association matrix if available
        //                let associationMatrix = try loadAssociationMatrix(from: floorURL)
        //
        //                // Create Floor object
        //                let floor = Floor(
        //                    _name: floorURL.lastPathComponent,
        //                    _lastUpdate: lastModifiedDate,
        //                    _planimetry: SCNViewContainer(),
        //                    _planimetryRooms: SCNViewMapContainer(),
        //                    _associationMatrix: associationMatrix,
        //                    _rooms: [],
        //                    _sceneObjects: [],
        //                    _scene: nil,
        //                    _sceneConfiguration: nil,
        //                    _floorURL: floorURL
        //                )
        //
        //                // Load Rooms and scene
        //                floor.rooms = try loadRooms(from: floorURL, floor: floor)
        //                if let usdzScene = try loadSceneIfAvailable(for: floor) {
        //                    floor.scene = usdzScene
        //                    floor.sceneObjects = try loadValidSceneNodes(from: usdzScene)
        //                }
        //
        //                floor.planimetryRooms.handler.loadRoomsMaps(floor: floor, rooms: floor.rooms, borders: true)
        //                floors.append(floor)
        //            }
        //        }
        //        return floors
        //    }
        //
        //    private func loadRooms(from floorURL: URL, floor: Floor) throws -> [Room] {
        //        let roomsDirectoryURL = floorURL.appendingPathComponent(BuildingModel.FLOOR_ROOMS_FOLDER)
        //        let roomURLs = try FileManager.default.contentsOfDirectory(at: roomsDirectoryURL, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles)
        //
        //        var rooms: [Room] = []
        //        for roomURL in roomURLs {
        //            if isDirectory(at: roomURL) {
        //                let lastModifiedDate = try getLastModifiedDate(for: roomURL)
        //                let referenceMarkers = try loadReferenceMarkers(from: roomURL)
        //
        //                // Create Room object
        //                let room = Room(
        //                    _name: roomURL.lastPathComponent,
        //                    _lastUpdate: lastModifiedDate,
        //                    _planimetry: SCNViewContainer(),
        //                    _referenceMarkers: referenceMarkers,
        //                    _transitionZones: [],
        //                    _scene: nil,
        //                    _sceneObjects: [],
        //                    _roomURL: roomURL,
        //                    parentFloor: floor
        //                )
        //
        //                // Load room scene
        //                if let usdzScene = try loadSceneIfAvailable(for: room) {
        //                    room.scene = usdzScene
        //                    room.sceneObjects = try loadValidSceneNodes(from: usdzScene)
        //                }
        //
        //                room.planimetry.loadRoomPlanimetry(room: room, borders: true)
        //                rooms.append(room)
        //            }
        //        }
        //        return rooms
        //    }
        //
        //    private func isDirectory(at url: URL) -> Bool {
        //        var isDirectory: ObjCBool = false
        //        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
        //    }
        //
        //    private func getLastModifiedDate(for url: URL) throws -> Date {
        //        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        //        guard let lastModifiedDate = attributes[.modificationDate] as? Date else {
        //            throw NSError(domain: "com.example.ScanBuild", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to retrieve last modification date for \(url.path)"])
        //        }
        //        return lastModifiedDate
        //    }
        //
        //    private func loadAssociationMatrix(from floorURL: URL) throws -> [String: RotoTraslationMatrix]? {
        //        let associationMatrixURL = floorURL.appendingPathComponent("\(floorURL.lastPathComponent).json")
        //        guard FileManager.default.fileExists(atPath: associationMatrixURL.path) else {
        //            return nil
        //        }
        //        return loadRoomPositionFromJson(from: associationMatrixURL)
        //    }
        //
        //    private func loadReferenceMarkers(from roomURL: URL) throws -> [ReferenceMarker] {
        //        let referenceMarkerURL = roomURL.appendingPathComponent("ReferenceMarker")
        //        var referenceMarkers: [ReferenceMarker] = []
        //
        //        guard FileManager.default.fileExists(atPath: referenceMarkerURL.path) else {
        //            return referenceMarkers
        //        }
        //
        //        let markerFiles = try FileManager.default.contentsOfDirectory(at: referenceMarkerURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
        //        for fileURL in markerFiles {
        //            if fileURL.pathExtension == "json" {
        //                let jsonData = try Data(contentsOf: fileURL)
        //                let decodedMarkers = try JSONDecoder().decode([ReferenceMarker].self, from: jsonData)
        //                referenceMarkers.append(contentsOf: decodedMarkers)
        //            } else if fileURL.pathExtension.lowercased() == "jpg" || fileURL.pathExtension.lowercased() == "png" {
        //                let coordinates = Coordinates(x: Float.random(in: -100...100), y: Float.random(in: -100...100))
        //                let marker = ReferenceMarker(_imagePath: fileURL, _imageName: fileURL.deletingPathExtension().lastPathComponent, _coordinates: coordinates, _rmUML: URL(fileURLWithPath: ""))
        //                referenceMarkers.append(marker)
        //            }
        //        }
        //
        //        return referenceMarkers
        //    }
        //
        //    private func loadSceneIfAvailable(for item: AnyObject) throws -> SCNScene? {
        //        let usdzPath: String
        //        if let floor = item as? Floor {
        //            usdzPath = floor.floorURL.appendingPathComponent("MapUsdz").appendingPathComponent("\(floor.name).usdz").path
        //        } else if let room = item as? Room {
        //            usdzPath = room.roomURL.appendingPathComponent("MapUsdz").appendingPathComponent("\(room.name).usdz").path
        //        } else {
        //            return nil
        //        }
        //
        //        guard FileManager.default.fileExists(atPath: usdzPath) else {
        //            print("USDZ file not found for \(item)")
        //            return nil
        //        }
        //
        //        return try SCNScene(url: URL(fileURLWithPath: usdzPath))
        //    }
        //
        //    private func loadValidSceneNodes(from scene: SCNScene) throws -> [SCNNode] {
        //        var seenNodeNames = Set<String>()
        //        return scene.rootNode.childNodes(passingTest: { node, _ in
        //            guard let nodeName = node.name, !seenNodeNames.contains(nodeName), node.geometry != nil else {
        //                return false
        //            }
        //
        //            let isValidNode = nodeName != "Room" &&
        //            nodeName != "Geom" &&
        //            !nodeName.hasSuffix("_grp") &&
        //            !nodeName.hasPrefix("unidentified") &&
        //            !(nodeName.first?.isNumber ?? false) &&
        //            !nodeName.hasPrefix("_")
        //
        //            if isValidNode {
        //                seenNodeNames.insert(nodeName)
        //                print("VALID MESH NODE ADDED: \(nodeName)")
        //                return true
        //            }
        //
        //            return false
        //        }).sorted {
        //            ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending
        //        }
        //    }
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
    
    


//
//  Utils.swift
//  MARS
//
//  Created by Danil Lugli on 26/10/24.
//

import Foundation
import RoomPlan
import ARKit
import simd


@MainActor
func generatePositionNode(_ color: UIColor, _ radius: CGFloat) -> SCNNode {
    
    let houseNode = SCNNode() //3 Sphere
    
    let sphere = SCNSphere(radius: radius)
    let sphereNode = SCNNode()
    sphereNode.geometry = sphere
    sphereNode.geometry?.firstMaterial?.diffuse.contents = color
    
    let sphere2 = SCNSphere(radius: radius)
    let sphereNode2 = SCNNode()
    sphereNode2.geometry = sphere2
    var color2 = color
    sphereNode2.geometry?.firstMaterial?.diffuse.contents = color2.withAlphaComponent(color2.cgColor.alpha - 0.3)
    sphereNode2.position = SCNVector3(0,
                                      0,
                                      -1) //Profondità = z
    
    let sphere3 = SCNSphere(radius: radius)
    let sphereNode3 = SCNNode()
    sphereNode3.geometry = sphere3
    var color3 = color
    sphereNode3.geometry?.firstMaterial?.diffuse.contents = color2.withAlphaComponent(color2.cgColor.alpha - 0.6)
    sphereNode3.position = SCNVector3(0, //Laterale = x
                                       -0.5,
                                      0)
    
    houseNode.addChildNode(sphereNode)
    houseNode.addChildNode(sphereNode2)
    houseNode.addChildNode(sphereNode3)
    houseNode.worldPosition.y = 2
    return houseNode
}

@MainActor
func applyRotoTraslation(to node: SCNNode, with rotoTraslation: RotoTraslationMatrix) {

    let combinedMatrix = rotoTraslation.translation * rotoTraslation.r_Y
    node.simdWorldTransform = combinedMatrix * node.simdWorldTransform

    printSimdFloat4x4(node.simdWorldTransform)
}

@available(iOS 16.0, *)
@MainActor
func addLocationNode(scnView: SCNView) {
    
    if scnView.scene == nil {
        scnView.scene = SCNScene()
    }
    
    var userLocation = generatePositionNode(UIColor(red: 0, green: 255, blue: 0, alpha: 1.0), 0.2)
    userLocation.simdWorldPosition = simd_float3(0.0, 0.0, 0.0)
    userLocation.name = "POS_ROOM"
    scnView.scene!.rootNode.addChildNode(userLocation)
}

@available(iOS 16.0, *)
@MainActor
func addFloorLocationNode(scnView: SCNView) {
    
    if scnView.scene == nil {
        scnView.scene = SCNScene()
    }
    
    let sphere = SCNSphere(radius: 1.0)
    
    let userLocation = generatePositionNode(UIColor(red: 0, green: 0, blue: 255, alpha: 1.0), 0.2)
    userLocation.simdWorldPosition = simd_float3(0.0, 0.0, 0.0)
    userLocation.name = "POS_FLOOR"
    scnView.scene?.rootNode.addChildNode(userLocation)
}

@available(iOS 16.0, *)
@MainActor
func addRoomNodesToScene(floor: Floor, scene: SCNScene) {
    
    do {
        for room in floor.rooms {

            let roomMap = room.roomURL.appendingPathComponent("MapUsdz").appendingPathComponent("\(room.name).usdz")
            let roomScene = try SCNScene(url: URL(fileURLWithPath: roomMap.path))
            
            let roomNode = createSceneNode(from: roomScene, roomName: room.name)
            roomNode.name = "Floor_\(room.name)"
            roomNode.simdWorldPosition = simd_float3(0, 0.2, 0)
            
            if let rotoTraslationMatrix = floor.associationMatrix[room.name] {
                applyRotoTraslation(to: roomNode, with: rotoTraslationMatrix)
            } else {
                print("No RotoTraslationMatrix found for room: \(room.name)")
            }
            
            scene.rootNode.addChildNode(roomNode)
        }
    } catch {
        print("Error loading room scenes: \(error)")
    }
}

@MainActor
private func createSceneNode(from scene: SCNScene, roomName: String) -> SCNNode {
    let containerNode = SCNNode()
    containerNode.name = "SceneContainer"
    
    // Cerca il nodo 'Floor0'
    if let floorNode = scene.rootNode.childNode(withName: "Floor0", recursively: true) {
        floorNode.name = roomName
        
        // Applica i materiali in base al nome della stanza
        let material = SCNMaterial()
        switch roomName {
        case "Mascetti":
            material.diffuse.contents = UIColor.red.withAlphaComponent(0.2)
        case "Corridoio":
            material.diffuse.contents = UIColor.green.withAlphaComponent(0.2)
        case "Bettini":
            material.diffuse.contents = UIColor.blue.withAlphaComponent(0.2)
        default:
            material.diffuse.contents = UIColor.white.withAlphaComponent(0.2)
        }
        floorNode.geometry?.materials = [material]
        
        // Calcola e applica la scala per impostare l'altezza desiderata
        let size = getNodeSize(node: floorNode)
        let desiredHeight: Float = 4.0
        let currentHeight = size.y
        
        if currentHeight != 0 {
            let scaleFactor = desiredHeight / currentHeight
            floorNode.scale = SCNVector3(floorNode.scale.x, floorNode.scale.y, floorNode.scale.z * (-scaleFactor))
            
            let newSize = getNodeSize(node: floorNode)
            print("Node resized - Width: \(newSize.x), Height: \(newSize.y), Length: \(newSize.z)")
        }
        
        containerNode.addChildNode(floorNode)
    } else {
        print("Node 'Floor0' not found in the provided scene.")
    }
    
    // Aggiungi una sfera arancione come marker centrale
    let sphereNode = SCNNode()
    sphereNode.name = "SceneCenterMarker"
    sphereNode.position = SCNVector3(0, 0, 0)
    
    let sphereGeometry = SCNSphere(radius: 0.1)
    let sphereMaterial = SCNMaterial()
    sphereMaterial.emission.contents = UIColor.orange
    sphereMaterial.diffuse.contents = UIColor.orange
    sphereGeometry.materials = [sphereMaterial]
    sphereNode.geometry = sphereGeometry
    containerNode.addChildNode(sphereNode)
    
    // Imposta il pivot sul puntino arancione
    if let markerNode = containerNode.childNode(withName: "SceneCenterMarker", recursively: true) {
        let localMarkerPosition = markerNode.position
        containerNode.pivot = SCNMatrix4MakeTranslation(localMarkerPosition.x, localMarkerPosition.y, localMarkerPosition.z)
    } else {
        print("SceneCenterMarker not found, pivot not modified.")
    }
    
    return containerNode
}

@MainActor
func getNodeSize(node: SCNNode) -> SCNVector3 {
    var minVec = SCNVector3Zero
    var maxVec = SCNVector3Zero
    node.__getBoundingBoxMin(&minVec, max: &maxVec)
    
    let width = maxVec.x - minVec.x
    let height = maxVec.z - minVec.z
    let length = maxVec.y - minVec.y
    
    // Applica la scala del nodo
    let scale = node.scale
    return SCNVector3(width * scale.x, height * scale.y, length * scale.z)
}

func printSimdFloat4x4(_ matrix: simd_float4x4) {
    for column in 0..<4 { // Cambiato per iterare sulle colonne
        let columnValues = (0..<4).map { row in
            String(format: "%.4f", matrix[row, column]) // Corretto ordine
        }.joined(separator: "\t")
        print("[ \(columnValues) ]")
    }
}

func printMatrix4x4(_ matrix: simd_float4x4, label: String) {
    print("\(label):")
    print("[\(matrix.columns.0.x), \(matrix.columns.1.x), \(matrix.columns.2.x), \(matrix.columns.3.x)]")
    print("[\(matrix.columns.0.y), \(matrix.columns.1.y), \(matrix.columns.2.y), \(matrix.columns.3.y)]")
    print("[\(matrix.columns.0.z), \(matrix.columns.1.z), \(matrix.columns.2.z), \(matrix.columns.3.z)]")
    print("[\(matrix.columns.0.w), \(matrix.columns.1.w), \(matrix.columns.2.w), \(matrix.columns.3.w)]\n")
}

public func trackingStateToString(_ state: ARCamera.TrackingState) -> String {

    switch state {
    case .normal:
        return "Normal"
    case .notAvailable:
        return "Not available"
    case .limited(.excessiveMotion):
        return "ExcessiveMotion"
    case .limited(.initializing):
        return "Initializing..."
    case .limited(.insufficientFeatures):
        return "Insufficient Features"
    case .limited(.relocalizing):
        return "Re-Localizing..."
    default:
        return ""
    }
}

extension simd_float4x4 {
    func formattedString() -> String {
        let rows = [
            String(format: "[%.2f, %.2f, %.2f, %.2f]", columns.0.x, columns.1.x, columns.2.x, columns.3.x),
            String(format: "[%.2f, %.2f, %.2f, %.2f]", columns.0.y, columns.1.y, columns.2.y, columns.3.y),
            String(format: "[%.2f, %.2f, %.2f, %.2f]", columns.0.z, columns.1.z, columns.2.z, columns.3.z),
            String(format: "[%.2f, %.2f, %.2f, %.2f]", columns.0.w, columns.1.w, columns.2.w, columns.3.w)
        ]
        return rows.joined(separator: "\n")
    }
}

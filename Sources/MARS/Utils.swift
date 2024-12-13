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

@available(iOS 16.0, *)
@MainActor func updateFloorPositionNode(in scnView: SCNView,
                                        newPosition: simd_float4x4,
                                        withColor color: UIColor = UIColor(red: 0, green: 255, blue: 0, alpha: 1.0),
                                        size: Float = 0.2,
                                        rotationAngle: Float = 90.0,
                                        rotationAxis: SIMD3<Float> = [0, 0, 1],
                                        rotoTranslationMatrix r: RotoTraslationMatrix,
                                        floor: Floor
) {
    
//    if let floorNodes = scnView.scene?.rootNode.childNodes.filter({ $0.name == "POS_FLOOR" }), !floorNodes.isEmpty {
//        floorNodes.forEach { $0.removeFromParentNode() }
//    } else {
//        print("Nessun nodo trovato con nome 'POS_FLOOR' per la rimozione.")
//    }
//    
//    var floorPositionNode = generatePositionNode(color, CGFloat(size))
//    
//    floorPositionNode.simdWorldTransform = newPosition
//    floorPositionNode.name = "POS_FLOOR"
//    
//    floor.scene.rootNode.addChildNode(floorPositionNode)
//    print("PARENT OF: \(floorPositionNode.name)")
//    print(floorPositionNode.parent)
    scnView.scene?.rootNode.childNodes.first(where: { $0.name == "POS_FLOOR" })?.simdWorldTransform = newPosition
    applyRotoTraslation(to: (scnView.scene?.rootNode.childNodes.first(where: { $0.name == "POS_FLOOR" }) as? SCNNode)!, with: r)

}

@MainActor func generatePositionNode(_ color: UIColor, _ radius: CGFloat) -> SCNNode {
    
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
    sphereNode2.position = SCNVector3(0, 0, -1)
    
    let sphere3 = SCNSphere(radius: radius)
    let sphereNode3 = SCNNode()
    sphereNode3.geometry = sphere3
    var color3 = color
    sphereNode3.geometry?.firstMaterial?.diffuse.contents = color2.withAlphaComponent(color2.cgColor.alpha - 0.6)
    sphereNode3.position = SCNVector3(0, -0.5, 0)
    
    
    houseNode.addChildNode(sphereNode)
    houseNode.addChildNode(sphereNode2)
    houseNode.addChildNode(sphereNode3)
    return houseNode
}

@MainActor
func applyRotoTraslation(to node: SCNNode, with rotoTraslation: RotoTraslationMatrix) {
    print("APPLY TO NODE: \(node.name)")
    print("NEW POSITION (simdWorldTransform): ")
    printSimdFloat4x4(node.simdWorldTransform)
    
    let translationVector = simd_float3(
        rotoTraslation.translation.columns.3.x, //Laterale
        rotoTraslation.translation.columns.3.y, //Verticale
        rotoTraslation.translation.columns.3.z  //Profondità
    )
    
    print("APPLY RotoTraslation")
    print("[Roto]:")
    printSimdFloat4x4(rotoTraslation.r_Y)
    print("[Traslation]:")
    printSimdFloat4x4(rotoTraslation.translation)
    

    let rotationMatrix = rotoTraslation.r_Y
    
    let rotationQuaternion = simd_quatf(rotationMatrix)

    
    node.simdWorldPosition = translationVector + node.simdWorldPosition
    //node.simdWorldOrientation = node.simdWorldOrientation * rotationQuaternion
    node.simdWorldOrientation = rotationQuaternion * node.simdWorldOrientation
    //node.simdWorldPosition.z  = 0
    print("PARENT OF: \(node.name)")
    print(node.parent)
    print(node.simdOrientation)
    
    
    print("\nPOST (simdWorldTransform): ")
    printSimdFloat4x4(node.simdWorldTransform)
    print("\n\n")
}

//@MainActor
//func applyRotoTraslation(to node: SCNNode, with rotoTraslation: RotoTraslationMatrix) {
//    
//    let translationVector = simd_float3(
//        rotoTraslation.translation.columns.3.x,
//        rotoTraslation.translation.columns.3.y,
//        rotoTraslation.translation.columns.3.z
//    )
//    node.simdPosition += translationVector
//
//    let rotationMatrix = rotoTraslation.r_Y
//
//    let rotationQuaternion = simd_quatf(rotationMatrix)
//
//    node.simdOrientation = rotationQuaternion * node.simdOrientation
//}


@MainActor
func applyInverseRotoTraslation(to node: SCNNode, with rotoTraslation: RotoTraslationMatrix) -> simd_float4x4 {
    // Inversione della traslazione
    let inverseTranslationVector = simd_float3(
        rotoTraslation.translation.columns.3.x,
        rotoTraslation.translation.columns.3.y,
        rotoTraslation.translation.columns.3.z
    )
    node.simdPosition -= inverseTranslationVector

    // Inversione della rotazione
    let rotationMatrix = rotoTraslation.r_Y
    let rotationQuaternion = simd_quatf(rotationMatrix)
    let inverseRotationQuaternion = simd_quatf(angle: -rotationQuaternion.angle, axis: rotationQuaternion.axis)
    
    node.simdOrientation = inverseRotationQuaternion * node.simdOrientation
    
    return node.simdWorldTransform
}

func printMatrix4x4(_ matrix: simd_float4x4, label: String) {
    print("\(label):")
    print("[\(matrix.columns.0.x), \(matrix.columns.1.x), \(matrix.columns.2.x), \(matrix.columns.3.x)]")
    print("[\(matrix.columns.0.y), \(matrix.columns.1.y), \(matrix.columns.2.y), \(matrix.columns.3.y)]")
    print("[\(matrix.columns.0.z), \(matrix.columns.1.z), \(matrix.columns.2.z), \(matrix.columns.3.z)]")
    print("[\(matrix.columns.0.w), \(matrix.columns.1.w), \(matrix.columns.2.w), \(matrix.columns.3.w)]\n")
}

@available(iOS 16.0, *)
@MainActor
func addRoomLocationNode(room: Room) {
    
    if room.scene == nil {
        room.scene = SCNScene()
    }
    
    var userLocation = generatePositionNode(UIColor(red: 0, green: 0, blue: 255, alpha: 1.0), 0.2)
    userLocation.simdWorldTransform = simd_float4x4(0)
    userLocation.name = "POS_ROOM"
    room.scene.rootNode.addChildNode(userLocation)
}

@available(iOS 16.0, *)
@MainActor
func addFloorLocationNode(floor: Floor) {
    
    if floor.scene == nil {
        floor.scene = SCNScene()
    }
    
    let sphere = SCNSphere(radius: 1.0)
    
    let userLocation = generatePositionNode(UIColor(red: 0, green: 0, blue: 255, alpha: 1.0), 0.2)
    userLocation.simdWorldPosition = simd_float3(0.0, 0.0, 0.0)
    userLocation.name = "POS_FLOOR"
    floor.scene.rootNode.addChildNode(userLocation)
}

@available(iOS 16.0, *)
@MainActor
func addRoomNodesToScene(floor: Floor) {
    do {
        for room in floor.rooms {
            let roomScene = room.scene
            if let roomNode = roomScene.rootNode.childNode(withName: "Floor0", recursively: true) {
                
                let originalScale = roomNode.scale
                
                roomNode.name = room.name
                roomNode.simdWorldPosition = simd_float3(0.0, 0.0, 0.0)
                printSimdFloat4x4(roomNode.simdWorldTransform)
                
                if let rotoTraslationMatrix = floor.associationMatrix[roomNode.name!] {
                
                    applyRotoTraslation(to: roomNode, with: rotoTraslationMatrix)
                  
                } else {
                    print("No RotoTraslationMatrix found for room: \(roomNode.name)")
                }
                
                let material = SCNMaterial()
                roomNode.geometry?.materials = [material]
                
                
//                let size = getNodeSize(node: roomNode)
//                print("Dimensioni del nodo prima della scala - Larghezza: \(size.x), Altezza: \(size.y), Lunghezza: \(size.z)")
//
//                let desiredHeight: Float = 4.0
//                let currentHeight = size.y
//
//                if currentHeight != 0 {
//                    let scaleFactor = desiredHeight / currentHeight
//
//                    // Applica lo scaling lungo l'asse Y per impostare l'altezza desiderata
//                    roomNode.scale = SCNVector3(
//                        roomNode.scale.x,
//                        roomNode.scale.y,
//                        roomNode.scale.z
//                    )
//
//                    // Verifica le nuove dimensioni dopo lo scaling
//                    let newSize = getNodeSize(node: roomNode)
//                    print("Dimensioni del nodo dopo la scala - Larghezza: \(newSize.x), Altezza: \(newSize.y), Lunghezza: \(newSize.z)")
//                } else {
//                    print("Altezza corrente zero, impossibile scalare il nodo.")
//                }
//
//                // **Fine delle modifiche**

                floor.scene.rootNode.addChildNode(roomNode)
                
                print("\n\nAdded \(roomNode.name ?? "Unnamed Node") to \(floor.name)")
            } else {
                print("Node 'Floor0' not found in scene: \(roomScene)")
            }
        }
    } catch {
        print("Error loading room scenes: \(error)")
    }
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

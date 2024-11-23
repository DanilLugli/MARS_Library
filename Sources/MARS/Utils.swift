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
        //print("Normal")
        return "Normal"
    case .notAvailable:
        return "Not available"
    case .limited(.excessiveMotion):
        return "ExcessiveMotion"
    case .limited(.initializing):
        //print("Initial")
        return "Initializing..."
    case .limited(.insufficientFeatures):
        return "Insufficient Features"
    case .limited(.relocalizing):
        //print("relo")
        return "Re-Localizing..."
    default:
        return ""
    }
}

@MainActor
func projectFloorPosition(_ position: SCNNode, _ matrix: RotoTraslationMatrix) -> SCNNode {
    print("Rotating the node by 90 degrees")
    
    // Angolo di rotazione in radianti (90 gradi)
    let rotationAngle = GLKMathDegreesToRadians(90.0)
    
    // Asse di rotazione (asse Z)
    let rotationAxis = simd_float3(0, 1, 0)
    
    // Crea un quaternione per la rotazione di 90 gradi attorno all'asse Z
    let rotationQuaternion = simd_quatf(angle: rotationAngle, axis: rotationAxis)
    
    // Applica la rotazione al nodo
    position.simdOrientation = rotationQuaternion * position.simdOrientation
    
    return position
}

@MainActor
func applyRotoTraslation(to node: SCNNode, with rotoTraslation: RotoTraslationMatrix) {
    
    let translationVector = simd_float3(
        rotoTraslation.translation.columns.3.x,
        rotoTraslation.translation.columns.3.y,
        rotoTraslation.translation.columns.3.z
    )
    node.simdPosition += translationVector

    let rotationMatrix = rotoTraslation.r_Y

    let rotationQuaternion = simd_quatf(rotationMatrix)

    node.simdOrientation = rotationQuaternion * node.simdOrientation
}

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
func addRoomNodesToScene(floor: Floor) {
    do {
        for room in floor.rooms {
            
            let roomScene = room.scene
            
            if let roomNode = roomScene.rootNode.childNode(withName: "Floor0", recursively: true) {
                
                let roomName = room.name
                
                if let rotoTraslationMatrix = floor.associationMatrix[roomName] {
                    applyRotoTraslation(to: roomNode, with: rotoTraslationMatrix)
                } else {
                    print("No RotoTraslationMatrix found for room: \(roomName)")
                }
                
                roomNode.name = roomName
                
                let material = SCNMaterial()
                roomNode.geometry?.materials = [material]
                
                
                let size = getNodeSize(node: roomNode)
                print("Dimensioni del nodo prima della scala - Larghezza: \(size.x), Altezza: \(size.y), Lunghezza: \(size.z)")
                
                let desiredHeight: Float = 4.0
                let currentHeight = size.y
                
                if currentHeight != 0 {
                    let scaleFactor = desiredHeight / currentHeight
                    
                    // Applica lo scaling lungo l'asse Y per impostare l'altezza desiderata
                    roomNode.scale = SCNVector3(
                        roomNode.scale.x,
                        roomNode.scale.y,
                        roomNode.scale.z * (-scaleFactor)
                    )
                    
                    // Verifica le nuove dimensioni dopo lo scaling
                    let newSize = getNodeSize(node: roomNode)
                    print("Dimensioni del nodo dopo la scala - Larghezza: \(newSize.x), Altezza: \(newSize.y), Lunghezza: \(newSize.z)")
                } else {
                    print("Altezza corrente zero, impossibile scalare il nodo.")
                }
                
                // **Fine delle modifiche**
                
                floor.scene.rootNode.addChildNode(roomNode)
                
                print("Added \(roomNode.name ?? "Unnamed Node") to \(floor.name)")
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
    print("Pippo:")
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

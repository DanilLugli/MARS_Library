//
//  Extension.swift
//  MARS
//
//  Created by Danil Lugli on 27/10/24.
//

import Foundation
import ARKit
import CoreMotion

extension ARWorldMap: Encodable {
    public func encode(to encoder: Encoder) throws {
        //var container = encoder.container(keyedBy: CodingKeys.self)
        //try container.encode(id, forKey: .id)
        //try container.encode(type.rawValue, forKey: .type)
        //try container.encode(isFavorited, forKey: .isFavorited)
    }
}

struct ARWorldMapCodable: Codable {
    let anchors: [AnchorCodable]
    let center: simd_float3
    let extent: simd_float3
    let rawFeaturesPoints: [simd_float3]
}

struct AnchorCodable: Codable {
    let x: Float
    let y: Float
    let z: Float
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

extension Float {
    var radiansToDegrees: Float {
        return self * 180 / .pi
    }
}

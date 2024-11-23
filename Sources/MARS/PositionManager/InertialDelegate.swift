//
//  InertialDelegate.swift
//  MARS
//
//  Created by Danil Lugli on 23/11/24.
//

import CoreMotion
import simd

let motionManager = CMMotionManager()

func updatePositionMatrix(currentMatrix: simd_float4x4, previousVelocity: SIMD3<Float>, deltaTime: TimeInterval) -> (updatedMatrix: simd_float4x4, newVelocity: SIMD3<Float>) {
    // Assicurati che i sensori siano attivi
    guard motionManager.isDeviceMotionAvailable, let deviceMotion = motionManager.deviceMotion else {
        print("Device Motion non disponibile o dati non disponibili")
        return (currentMatrix, previousVelocity)
    }
    
    // Ottieni l'accelerazione del dispositivo (in G)
    let acceleration = deviceMotion.userAcceleration
    // Converti l'accelerazione in metri al secondo quadrato
    let accelerationVector = SIMD3<Float>(
        Float(acceleration.x * 9.81),
        Float(acceleration.y * 9.81),
        Float(acceleration.z * 9.81)
    )
    
    // Aggiorna la velocità integrando l'accelerazione
    let newVelocity = previousVelocity + accelerationVector * Float(deltaTime)
    
    // Aggiorna la posizione integrando la velocità
    let displacement = newVelocity * Float(deltaTime)
    let translationMatrix = matrix_float4x4(translation: displacement)
    
    // Ottieni la rotazione del dispositivo
    let attitude = deviceMotion.attitude
    let rotationMatrix = matrix_float4x4(rotation: attitude)
    
    // Aggiorna la matrice corrente con rotazione e traslazione
    let updatedMatrix = currentMatrix * rotationMatrix * translationMatrix
    
    return (updatedMatrix, newVelocity)
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

//
//  Position.swift
//
//
//  Created by Danil Lugli on 03/10/24.
//

import Foundation
import simd

public class Position{
    public var position: simd_float4x4
    //Serve altro?
    //In quale piano è ?
    
    public init(position: simd_float4x4) {
        self.position = position
    }
    
    // MARK: - Inizializzatore con posizione "zero" (tutti i valori a 0)
    public init() {
        self.position = simd_float4x4(0) // Matrice 4x4 con tutti i valori a zero
    }
}

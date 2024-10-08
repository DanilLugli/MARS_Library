//
//  Position.swift
//  
//
//  Created by Danil Lugli on 03/10/24.
//

import Foundation
import simd

class Position{
    public var position: simd_float4x4
    //Serve altro?
    //In quale piano è ?
    
    init(position: simd_float4x4) {
        self.position = position
    }
}

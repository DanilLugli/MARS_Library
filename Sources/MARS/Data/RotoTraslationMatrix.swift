//
//  RotoTraslationMatrix.swift
//  
//
//  Created by Danil Lugli on 03/10/24.
//

import Foundation

struct RotoTraslationMatrix: Codable {
    let name: String
    var translation: simd_float4x4
    var r_Y: simd_float4x4
    
    init(name: String, translation: simd_float4x4, r_Y: simd_float4x4) {
        self.name = name
        self.translation = translation
        self.r_Y = r_Y
    }
}


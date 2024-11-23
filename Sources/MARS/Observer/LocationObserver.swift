//
//  File.swift
//  MARS
//
//  Created by Danil Lugli on 16/10/24.
//

import Foundation
import simd
import ARKit

@available(iOS 16.0, *)
@MainActor
public protocol LocationObserver{
    var id : UUID { get }
    func onLocationUpdate(_ newPosition: simd_float4x4, _ trackingState: String)
}

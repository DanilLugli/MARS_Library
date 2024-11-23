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
protocol LocationSubject {
    
    var positionObservers: [PositionObserver] { get }
    
    mutating func addLocationObserver(positionObserver: PositionObserver)
    mutating func removeLocationObserver(positionObserver: PositionObserver)
    func notifyLocationUpdate(newLocation: simd_float4x4, newTrackingState: String)
}

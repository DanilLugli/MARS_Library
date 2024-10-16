//
//  File.swift
//  MARS
//
//  Created by Danil Lugli on 16/10/24.
//

import Foundation

@available(iOS 16.0, *)
protocol LocationSubject {
    
    var positionObservers: [PositionObserver] { get }
    
    mutating func addLocationObserver(positionObserver: PositionObserver)
    mutating func removeLocationObserver(positionObserver: PositionObserver)
    func notifyLocationUpdate(newLocation: Position, newTrackingState: TrackingState)
}

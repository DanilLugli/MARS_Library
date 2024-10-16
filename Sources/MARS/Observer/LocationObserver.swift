//
//  File.swift
//  MARS
//
//  Created by Danil Lugli on 16/10/24.
//

import Foundation

@available(iOS 16.0, *)

public protocol LocationObserver{
    var id : UUID { get }
    func onLocationUpdate(_ newPosition: Position, _ trackingState: TrackingState)
}

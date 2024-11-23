//
//  File.swift
//  MARS
//
//  Created by Danil Lugli on 11/10/24.
//

import Foundation
import ARKit
import SceneKit

public struct TrackingState{
    public var state: ARCamera.TrackingState
    
    public init(state: ARCamera.TrackingState) {
        self.state = state
    }
}

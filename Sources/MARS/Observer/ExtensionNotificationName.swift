//
//  ExtensionNotificationName.swift
//  MARS
//
//  Created by Danil Lugli on 26/10/24.
//

import Foundation

extension Notification.Name {
    
    static var trackingState: Notification.Name {
        return .init(rawValue: "trackingState.message")
    }
    
    static var worldMapMessage: Notification.Name {
        return .init(rawValue: "WorldMapMessage.message")
    }
    static var worldMapCounter: Notification.Name {
        return .init(rawValue: "WorldMapMessage.counter")
    }
    
    static var trackingPosition: Notification.Name {
        return .init(rawValue: "trackingPosition.message")
    }
    
    static var worlMapNewFeatures: Notification.Name {
        return .init(rawValue: "worlMapNewFeatures.message")
    }
    
    static var trackingPositionFromMotionManager: Notification.Name {
        return .init(rawValue: "trackingPositionFromMotionManager.message")
    }
    
}


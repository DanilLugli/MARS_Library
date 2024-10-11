//
//  ReferenceMarker.swift
//  
//
//  Created by Danil Lugli on 03/10/24.
//
import SwiftUI
import Foundation

public class ReferenceMarker: ObservableObject, Identifiable {
    public var id: UUID
    public var imageName: String 
    public var image: Image {
        Image(imageName)
    }

    public init(imageName: String) {
        self.id = UUID()
        self.imageName = imageName
    }

    public enum CodingKeys: String, CodingKey {
        case id
        case imageName
    }
}

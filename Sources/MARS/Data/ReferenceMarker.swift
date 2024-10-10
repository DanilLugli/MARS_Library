//
//  ReferenceMarker.swift
//  
//
//  Created by Danil Lugli on 03/10/24.
//
import SwiftUI
import Foundation

@available(iOS 13.0, *)
public class ReferenceMarker: ObservableObject, Identifiable {
    public var id: UUID
    public var imageName: String // Store the image name or path instead of the `Image`
    public var image: Image {
        Image(imageName) // Load the image based on `imageName`
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

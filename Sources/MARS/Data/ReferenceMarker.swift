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
    public var image: UIImage
    public var physicalWidth: CGFloat  // width of the marker in meters

    public init(image: UIImage, physicalWidth: CGFloat) {
        self.id = UUID()
        self.image = image
        self.physicalWidth = physicalWidth
    }

    public enum CodingKeys: String, CodingKey {
        case id
        case imageName
    }
}

//
//  ReferenceMarker.swift
//  
//
//  Created by Danil Lugli on 03/10/24.
//
import SwiftUI
import Foundation
import ARKit

public class ReferenceMarker: ObservableObject, Identifiable, Decodable {
    public var id: UUID
    public var image: ARReferenceImage?
    public var width: CGFloat
    public var room: String = ""
    public var name: String
    
    public init(id: UUID = UUID(), image: ARReferenceImage? = nil, width: CGFloat, name: String) {
        self.id = id
        self.image = image
        self.width = width
        self.name = name
    }

    enum CodingKeys: String, CodingKey {
        case width
        case name
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id = UUID()
        self.width = try container.decode(CGFloat.self, forKey: .width)
        self.name = try container.decode(String.self, forKey: .name)
        self.image = nil
    }

    public func loadARReferenceImage(from imageSource: UIImage) {
        if let cgImage = imageSource.cgImage {
            self.image = ARReferenceImage(cgImage, orientation: .up, physicalWidth: self.width)
            self.image?.name = self.name
        } else {
            print("Errore: impossibile ottenere cgImage dall'immagine fornita.")
        }
    }
    
    struct MarkerData: Codable {
        var name: String
        var width: CGFloat
    }
}

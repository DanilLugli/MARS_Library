//
//  ReferenceMarker.swift
//  
//
//  Created by Danil Lugli on 03/10/24.
//

class ReferenceMarker: ObservableObject, Codable, Identifiable  {
    public var id: UUID = UUID()
    public var image: Image
    public var imageName: String

    
    init(image: Image, imageName: String) {
        self.image = image
        self.imageName = imageName
    }
}

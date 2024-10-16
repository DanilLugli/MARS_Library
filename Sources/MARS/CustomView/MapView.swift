//
//  SwiftUIView.swift
//  MARS
//
//  Created by Danil Lugli on 11/10/24.
//

import SwiftUI
import ARKit

@available(iOS 16.0, *)
public struct MapView: View {
    
    @StateObject private var locationProvider: PositionProvider
    
    public init(locationProvider: PositionProvider) {
        _locationProvider = StateObject(wrappedValue: locationProvider)
    }
    
    public var body: some View {
        VStack {
            Text("Position Map")
                .font(.headline)
                .padding()
            
            Text(locationProvider.building.name)
                .font(.headline)
                .padding()
            
            ZStack{
                
                locationProvider.arView
                    .edgesIgnoringSafeArea(.all)
                
                locationProvider.scnView
                    .frame(width: 100, height: 50)
            }
            
        }
        .onAppear {
            Task {
                await locationProvider.start()
            }
        }
    }
}

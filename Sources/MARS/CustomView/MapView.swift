//
//  SwiftUIView.swift
//  MARS
//
//  Created by Danil Lugli on 11/10/24.
//

import SwiftUI
import ARKit

@available(iOS 16.0, *)
struct MapView: UIViewRepresentable {
    var locationProvider: LocationProvider
    
    func makeUIView(context: Context) -> ARSCNView {
        let arView = ARSCNView()
        locationProvider.arSCNView = arView
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        arView.session.run(configuration)
        
        arView.debugOptions = [.showFeaturePoints, .showWorldOrigin]
        
        return arView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {
        // Potresti aggiornare qui la sessione AR o altre configurazioni se necessario
    }
}

@available(iOS 16.0, *)
struct SceneViewContainer: View {
    @StateObject var locationProvider: LocationProvider
    
    var body: some View {
        ZStack {
            MapView(locationProvider: locationProvider)
                .edgesIgnoringSafeArea(.all) // Mostra la visualizzazione AR
            Divider()
            SCNViewContainer() // Contiene la visualizzazione della posizione
                .frame(height: 200) // Puoi regolare l'altezza
        }
    }
}

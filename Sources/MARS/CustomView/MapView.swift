import SwiftUI
import ARKit

@available(iOS 16.0, *)
public struct MapView: View {
    
    @StateObject private var locationProvider: PositionProvider
    
    public init(locationProvider: PositionProvider) {
        _locationProvider = StateObject(wrappedValue: locationProvider)
    }
    
    public var body: some View {
        ZStack {
            locationProvider.arView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
            
            VStack {
                
                Text(locationProvider.building.name)
                    .font(.title)
                    .bold()
                    .foregroundColor(.white)
                    .padding(.top, 60)
                
                Spacer()
                
                locationProvider.scnFloorView
                    .frame(width: 320, height: 200)
                    .cornerRadius(20)
                    .padding(.bottom, 20)
            }
        }
        .onAppear {
            Task {
                await locationProvider.start()
            }
        }
    }
}

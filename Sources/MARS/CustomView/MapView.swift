import SwiftUI
import ARKit

@available(iOS 16.0, *)
public struct MapView: View {
    
    @StateObject private var locationProvider: PositionProvider
    
    @State private var hasStarted: Bool = false
    @State private var debug: Bool = false
    
    public init(locationProvider: PositionProvider) {
        _locationProvider = StateObject(wrappedValue: locationProvider)
    }
    
    public var body: some View {
        ZStack {
 
            locationProvider.arView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
            
            switch debug{
                
            case true :
                VStack {
                    
                    CardView(
                        buildingMap: locationProvider.building.name,
                        floorMap: locationProvider.activeFloor.name,
                        roomMap: locationProvider.activeRoom.name,
                        matrixMap: locationProvider.activeFloor.associationMatrix[locationProvider.activeRoom.name]?.name ?? "ERROR Activer Room",
                        actualPosition: locationProvider.position,
                        trackingState: locationProvider.trackingState,
                        nodeContainedIn: locationProvider.nodeContainedIn,
                        switchingRoom: locationProvider.switchingRoom
                    )
                    .padding(.top, 60)
                    
                    Spacer()
                    
                    VStack{
                        HStack{
                            VStack{
                                
                                HStack(spacing: 0) {
                                    Text("Floor: ")
                                        .foregroundColor(.white)
                                        .bold()
                                        .font(.title2)
                                    Text(locationProvider.activeFloor.name)
                                        .foregroundColor(.white)
                                        .bold()
                                        .font(.title2)
                                        .italic()
                                }
                                
                                locationProvider.scnFloorView
                                    .frame(width: 185, height: 200)
                                    .cornerRadius(20)
                                    .padding(.bottom, 20)
                            }
                            
                            
                            VStack{
                                HStack(spacing: 0) {
                                    Text("Room: ")
                                        .foregroundColor(.white)
                                        .bold()
                                        .font(.title2)
                                    Text(locationProvider.activeRoom.name)
                                        .foregroundColor(.white)
                                        .bold()
                                        .font(.title2)
                                        .italic()
                                }
                                
                                locationProvider.scnRoomView
                                    .frame(width: 185, height: 200)
                                    .cornerRadius(20)
                                    .padding(.bottom, 20)
                            }
                            
                        }
                        
                        HStack {
                            Text("Debug Mode")
                                .font(.system(size: 18))
                                .bold()
                                .foregroundColor(.white)
                                .padding([.leading, .trailing], 16)
                            Toggle("", isOn: $debug) // Rimuove l'etichetta originale
                                .toggleStyle(SwitchToggleStyle())
                                .padding([.leading, .trailing], 16)
                        }.frame(width: 300, height: 60)
                            .background(Color.blue.opacity(0.4))
                            .cornerRadius(20)
                        
                        
                    }.padding(.bottom, 40)
                }
                
            case false :
                VStack {
                    
                    Spacer()
                    
                    VStack{
                        HStack{
                            locationProvider.scnFloorView
                                .frame(width: 380, height: 200)
                                .cornerRadius(20)
                                .padding(.bottom, 20)
                        }
                        
                        
                        HStack {
                            Text("Debug Mode")
                                .font(.system(size: 18))
                                .bold()
                                .foregroundColor(.white)
                                .padding([.leading, .trailing], 16)
                            Toggle("", isOn: $debug)
                                .toggleStyle(SwitchToggleStyle())
                                .padding([.leading, .trailing], 16)
                        }.frame(width: 300, height: 60)
                            .background(Color.blue.opacity(0.4))
                            .cornerRadius(20)
                        
                    }.padding(.bottom, 40)
                    
                }
                
            }
        }
        .onAppear {
            if !hasStarted {
                locationProvider.start()
                hasStarted = true
            }
        }
    }
}
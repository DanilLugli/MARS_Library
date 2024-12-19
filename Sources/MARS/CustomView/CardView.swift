//
//  CardView.swift
//  MARS
//
//  Created by Danil Lugli on 30/10/24.
//

import SwiftUI
import ARKit
import simd


@available(iOS 16.0, *)
public struct CardView: View {
    
    var buildingMap: String = ""
    var floorMap: String = ""
    var roomMap: String = ""
    var matrixMap: String = ""
    var actualPosition: simd_float4x4 = simd_float4x4(0)
    var trackingState: String = ""
    var nodeContainedIn: String = ""
    var switchingRoom: Bool = false
    
    public var body: some View {
        
        
        HStack() {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading) {
                    HStack(spacing: 0) {
                        Text("Building Map: ")
                        Text("\(buildingMap)").italic()
                    }
                    HStack(spacing: 0) {
                        Text("Floor Map: ")
                        Text("\(floorMap)").italic()
                    }
                    
                    Divider()
                    
                    HStack(spacing: 0) {
                        Text("Active Room ARWorldMap: ")
                        Text("\(roomMap)").italic()
                    }
                    HStack(spacing: 0) {
                        Text("Active RotoTranslation: ")
                        Text("\(matrixMap)").italic()
                    }

                    Divider()
                    
                    // Actual Position
                    
                    switch nodeContainedIn {
                    case "No Room Positioned":
                        HStack(spacing: 0) {
                            Text("Pos. Contained in Room: ")
                            Text("\(nodeContainedIn)")
                                .italic()
                                .foregroundColor(.red)
                        }
                    default:
                        HStack(spacing: 0) {
                            Text("Pos. Contained in Room: ")
                            Text("\(nodeContainedIn)")
                                .italic()
                                .foregroundColor(.green)
                        }
                    }
                    
                    switch switchingRoom{
                    case true:
                        HStack(spacing: 0) {
                            Text("Switching Room: ")
                            Text("Switching to \(nodeContainedIn)...")
                                .foregroundColor(.red)
                                .italic()
                        }
                        
                    case false:
                        HStack(spacing: 0) {
                            Text("Switching Room: ")
                            Text("False")
                                .bold()
                                .foregroundColor(.green)
                        }
                    }
                    
                    switch trackingState {
                    case "":
                        HStack(spacing: 0) {
                            Text("Tracking State: ")
                            Text("Uploading AR World Map...")
                                .italic()
                                .foregroundColor(.red)
                        }
                    case "Normal":
                        HStack(spacing: 0) {
                            Text("Tracking State: ")
                            Text("\(trackingState)")
                                .italic()
                                .foregroundColor(.green)
                        }
                    case "Insufficient Features":
                        HStack(spacing: 0) {
                            Text("Tracking State: ")
                            Text("\(trackingState)")
                                .italic()
                                .foregroundColor(.orange)
                        }
                    case "Re-Localizing...":
                        HStack(spacing: 0) {
                            Text("Tracking State: ")
                            Text("\(trackingState)")
                                .italic()
                                .foregroundColor(.yellow)
                        }
                    default:
                        HStack(spacing: 0) {
                            Text("Tracking State: ")
                            Text("\(trackingState)")
                                .italic()
                        }
                    }
                    
                    Divider()

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Actual Position:")
                        Text(actualPosition.formattedString())
                            .font(.system(.body, design: .monospaced))
                            .italic()
                    }
                }
            }
            .foregroundColor(.white)
            .bold()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding()
        .frame(width: 400, height: 350)
        .background(Color.blue.opacity(0.4))
        .cornerRadius(20)
    }
}


@available(iOS 16.0, *)
struct CardView_Previews: PreviewProvider {
    static var previews: some View {
        CardView()
    }
}

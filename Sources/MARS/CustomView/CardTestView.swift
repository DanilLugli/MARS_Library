//
//  CardTestView.swift
//  MARS
//
//  Created by Danil Lugli on 20/12/24.
//

import SwiftUI
import ARKit
import simd


@available(iOS 16.0, *)
public struct CardTestView: View {
    
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
                        Text("Take First Angle: ")
                        Text("\(roomMap)").italic()
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

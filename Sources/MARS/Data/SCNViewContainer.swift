//
//  File.swift
//  MARS
//
//  Created by Danil Lugli on 07/10/24.
//

import SwiftUI
import SceneKit
import ARKit
import RoomPlan
import CoreMotion
import ComplexModule

@available(iOS 16.0, *)
public struct SCNViewContainer: UIViewRepresentable {
    
    public typealias UIViewType = SCNView
    
    var scnView = SCNView(frame: .zero)
    var handler = HandleTap()
    
    var cameraNode = SCNNode()
    var massCenter = SCNNode()
    var delegate = RenderDelegate()
    var dimension = SCNVector3()
    
    var rotoTraslation: [RotoTraslationMatrix] = []
    var origin = SCNNode()
    @State var rotoTraslationActive: Int = 0
    
    init() {
        massCenter.worldPosition = SCNVector3(0, 0, 0)
        origin.simdWorldTransform = simd_float4x4([1.0,0,0,0],[0,1.0,0,0],[0,0,1.0,0],[0,0,0,1.0])
    }
    
    func loadPlanimetry(scene: SCNScene, borders: Bool) {
        
        scnView.scene = scene
        addLocationNode()
        drawContent(borders: borders)
        setMassCenter()
        setCamera()
        
    }
    
    func setCamera() {
        cameraNode.camera = SCNCamera()
        
        scnView.scene?.rootNode.addChildNode(cameraNode)
        
        cameraNode.worldPosition = SCNVector3(massCenter.worldPosition.x, massCenter.worldPosition.y + 10, massCenter.worldPosition.z)
        
        cameraNode.camera?.usesOrthographicProjection = true
        cameraNode.camera?.orthographicScale = 10
        
        cameraNode.eulerAngles = SCNVector3(-Double.pi / 2, 0, 0)
        
        let directionalLight = SCNNode()
        directionalLight.light = SCNLight()
        directionalLight.light!.type = .ambient
        directionalLight.light!.color = UIColor(white: 1.0, alpha: 1.0)
        cameraNode.addChildNode(directionalLight)
        
        scnView.pointOfView = cameraNode
        
        cameraNode.constraints = []
    }
    
    func setMassCenter() {
        var massCenter = SCNNode()
        massCenter.worldPosition = SCNVector3(0, 0, 0)
        if let nodes = scnView.scene?.rootNode
            .childNodes(passingTest: {
                n,_ in n.name != nil && n.name! != "Room" && n.name! != "Geom" && String(n.name!.suffix(4)) != "_grp"
            }) {
            massCenter = findMassCenter(nodes)
        }
        scnView.scene?.rootNode.addChildNode(massCenter)
    }
    
    func findMassCenter(_ nodes: [SCNNode]) -> SCNNode {
        let massCenter = SCNNode()
        var X: [Float] = [Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude]
        var Z: [Float] = [Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude]
        for n in nodes{
            if (n.worldPosition.x < X[0]) {X[0] = n.worldPosition.x}
            if (n.worldPosition.x > X[1]) {X[1] = n.worldPosition.x}
            if (n.worldPosition.z < Z[0]) {Z[0] = n.worldPosition.z}
            if (n.worldPosition.z > Z[1]) {Z[1] = n.worldPosition.z}
        }
        massCenter.worldPosition = SCNVector3((X[0]+X[1])/2, 0, (Z[0]+Z[1])/2)
        return massCenter
    }
    
    func generateSphereNode(_ color: UIColor, _ radius: CGFloat) -> SCNNode {
        
        let houseNode = SCNNode() //3 Sphere
        
        let sphere = SCNSphere(radius: radius)
        //let sphere = SCNPyramid(width: radius, height: radius*2, length: radius)
        let sphereNode = SCNNode()
        sphereNode.geometry = sphere
        sphereNode.geometry?.firstMaterial?.diffuse.contents = color
        
        let sphere2 = SCNSphere(radius: radius)
        //let sphere = SCNPyramid(width: radius, height: radius*2, length: radius)
        let sphereNode2 = SCNNode()
        sphereNode2.geometry = sphere2
        var color2 = color
        sphereNode2.geometry?.firstMaterial?.diffuse.contents = color2.withAlphaComponent(color2.cgColor.alpha - 0.3)
        sphereNode2.position = SCNVector3(0, 0, -1)
        
        let sphere3 = SCNSphere(radius: radius)
        //let sphere = SCNPyramid(width: radius, height: radius*2, length: radius)
        let sphereNode3 = SCNNode()
        sphereNode3.geometry = sphere3
        var color3 = color
        sphereNode3.geometry?.firstMaterial?.diffuse.contents = color2.withAlphaComponent(color2.cgColor.alpha - 0.6)
        sphereNode3.position = SCNVector3(-0.5, 0, 0)
        
        
        houseNode.addChildNode(sphereNode)
        houseNode.addChildNode(sphereNode2)
        houseNode.addChildNode(sphereNode3)
        return houseNode
    }
    
    func addLocationNode() {
        
        if scnView.scene == nil {
            print("New Scene")
            scnView.scene = SCNScene()
        }
        
        let sphere = SCNSphere(radius: 1.0)  // Adjust the radius as needed
        
        // Get the SF Symbol image
        if let symbolImage = UIImage(systemName: "location.north.circle.fill")?.withTintColor(UIColor.blue, renderingMode: .alwaysOriginal) {
            
            let material = SCNMaterial()
            material.diffuse.contents = symbolImage
            
            sphere.materials = [material]
            
            let symbolNode = SCNNode(geometry: sphere)
            symbolNode.position = SCNVector3(0, 0, 0)
            
            symbolNode.name = "locationSF"
            
            //TODO: Add new icon for position
            //scnView.scene?.rootNode.addChildNode(symbolNode)
        }
        
        var userLocation = generateSphereNode(UIColor(red: 0, green: 0, blue: 255, alpha: 1.0), 0.2)
        
        userLocation.name = "userLocation"
        scnView.scene?.rootNode.addChildNode(userLocation)
    }
    
    func drawContent(borders: Bool) {
        var drawnNodes = Set<String>()
        
        print("RootNode: \(String(describing: scnView.scene?.rootNode.name))\n\n")
        
        scnView.scene?
            .rootNode
            .childNodes(passingTest: { n, _ in
                n.name != nil &&
                n.name! != "Room" &&
                n.name! != "Floor0" &&
                n.name! != "Geom" &&
                String(n.name!.suffix(4)) != "_grp" &&
                n.name! != "__selected__"
            })
            .forEach { node in
                guard let nodeName = node.name else { return }
                print(node.name)
                let material = SCNMaterial()
                
                if nodeName == "Floor0" {
                    material.diffuse.contents = UIColor.green
                } else {
                    material.diffuse.contents = UIColor.black
                    if nodeName.prefix(5) == "Floor" {
                        material.diffuse.contents = UIColor.white.withAlphaComponent(0.2)
                    }
                    if nodeName.prefix(6) == "Transi" {
                        material.diffuse.contents = UIColor.white
                    }
                    if nodeName.prefix(4) == "Door" {
                        material.diffuse.contents = UIColor.systemGray5
                    }
                    if nodeName.prefix(4) == "Open" {
                        material.diffuse.contents = UIColor.systemGray5
                    }
                    if nodeName.prefix(4) == "Tabl" {
                        material.diffuse.contents = UIColor.brown
                    }
                    if nodeName.prefix(4) == "Chai" {
                        material.diffuse.contents = UIColor.brown.withAlphaComponent(0.4)
                    }
                    if nodeName.prefix(4) == "Stor" {
                        material.diffuse.contents = UIColor.systemGray2
                    }
                    if nodeName.prefix(4) == "Sofa" {
                        material.diffuse.contents = UIColor(red: 0.0, green: 0.0, blue: 0.5, alpha: 0.6)
                    }
                    if nodeName == "locationUser" {
                        print("exist")
                    }
                    if nodeName.prefix(4) == "Tele" {
                        material.diffuse.contents = UIColor.orange
                    }
                    material.lightingModel = .physicallyBased
                }
                
                node.geometry?.materials = [material]
                
                if borders {
                    node.scale.x = node.scale.x < 0.2 ? node.scale.x + 0.1 : node.scale.x
                    node.scale.z = node.scale.z < 0.2 ? node.scale.z + 0.1 : node.scale.z
                    node.scale.y = (node.name!.prefix(4) == "Wall") ? 0.1 : node.scale.y
                }
                
                drawnNodes.insert(nodeName)
            }
    }
    
    public func makeUIView(context: Context) -> SCNView {
        
        handler.scnView = scnView
        
        let pinchGesture = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handlePinch(_:)))
        scnView.addGestureRecognizer(pinchGesture)
        
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handlePan(_:)))
        scnView.addGestureRecognizer(panGesture)
        
        scnView.backgroundColor = UIColor.white
        
        return scnView
    }
    
    public func updateUIView(_ uiView: SCNView, context: Context) {}
    
    public func makeCoordinator() -> SCNViewContainerCoordinator {
    SCNViewContainerCoordinator(self)
}
    
    public class SCNViewContainerCoordinator: NSObject {
        public var parent: SCNViewContainer
        
        public init(_ parent: SCNViewContainer) {
            self.parent = parent
        }
        
        @MainActor @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            guard let camera = parent.cameraNode.camera else { return }
            
            if gesture.state == .changed {
                let newScale = camera.orthographicScale / Double(gesture.scale)
                camera.orthographicScale = max(5.0, min(newScale, 50.0)) // Limita lo zoom tra 5x e 50x
                gesture.scale = 1
            }
        }
        
        @MainActor @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            
            let translation = gesture.translation(in: parent.scnView)
            
            parent.cameraNode.position.x -= Float(translation.x) * 0.01
            parent.cameraNode.position.z += Float(translation.y) * 0.01
            
            gesture.setTranslation(.zero, in: parent.scnView)
            
        }
    }
}

@available(iOS 16.0, *)
public struct SCNViewContainer_Previews: PreviewProvider {
    public static var previews: some View {
        SCNViewContainer()
    }
}

extension SCNQuaternion {
    func difference(_ other: SCNQuaternion) -> SCNQuaternion{
        return SCNQuaternion(
            self.x - other.x,
            self.y - other.y,
            self.z - other.z,
            self.w - other.w
        )
    }
    
    func sum(_ other: SCNQuaternion) -> SCNQuaternion{
        return SCNQuaternion(
            self.x + other.x,
            self.y + other.y,
            self.z + other.z,
            self.w + other.w
        )
    }
}

extension SCNVector3 {
    func difference(_ other: SCNVector3) -> SCNVector3 {
        return SCNVector3(
            self.x - other.x,
            self.y - other.y,
            self.z - other.z
        )
    }
    
    func sum(_ other: SCNVector3) -> SCNVector3 {
        return SCNVector3(
            self.x + other.x,
            self.y + other.y,
            self.z + other.z
        )
    }
    
    func rotateAroundOrigin(_ angle: Float) -> SCNVector3 {
        var a = Complex<Float>.i
        a.real = cos(angle)
        a.imaginary = sin(angle)
        var b = Complex<Float>.i
        b.real = self.x
        b.imaginary = self.z
        let position = a*b
        return SCNVector3(
            position.real,
            self.y,
            position.imaginary
        )
    }
}

extension SCNNode {
    
    var height: CGFloat { CGFloat(self.boundingBox.max.y - self.boundingBox.min.y) }
    var width: CGFloat { CGFloat(self.boundingBox.max.x - self.boundingBox.min.x) }
    var length: CGFloat { CGFloat(self.boundingBox.max.z - self.boundingBox.min.z) }
    
    var halfCGHeight: CGFloat { height / 2.0 }
    var halfHeight: Float { Float(height / 2.0) }
    var halfScaledHeight: Float { halfHeight * self.scale.y  }
}

class HandleTap: UIViewController {
    var scnView: SCNView?
    
    @objc func handleTap(_ gestureRecognize: UITapGestureRecognizer) {
        print("handleTap")
        
        let p = gestureRecognize.location(in: scnView)
        let hitResults = scnView!.hitTest(p, options: nil)
        if let tappedNode = hitResults.first?.node {
            print(tappedNode)
        }
    }
}

class RenderDelegate: NSObject, SCNSceneRendererDelegate {
    
    var lastRenderer: SCNSceneRenderer!
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        lastRenderer = renderer
    }
}


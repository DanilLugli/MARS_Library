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
import DeviceKit

@available(iOS 16.0, *)
@MainActor
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
        origin = generatePositionNode(UIColor(red: 0, green: 230, blue: 0, alpha: 3.0), 0.2)
        origin.simdWorldTransform = simd_float4x4([1.0,0,0,0],
                                                  [0,1.0,0,0],
                                                  [0,0,1.0,0],
                                                  [0,0,0,1.0])
        scnView.scene?.rootNode.addChildNode(origin)
    }
        
    @MainActor
    func loadPlanimetry(scene: SCNScene, roomsNode: [String]?, borders: Bool, nameCaller: String) {
        // Log utile per il debugging
        print("NAME CALLER: \(nameCaller)")
        
        // Resetta completamente la scena
        self.scnView.scene = SCNScene() // Nuova scena vuota
        print("Scene reset. Starting fresh.")

        // Aggiungi la nuova scena
        self.scnView.scene = scene
        print("New scene set. Number of nodes in scene: \(self.scnView.scene?.rootNode.childNodes.count ?? 0)")
        
        // Aggiungi il marker di origine
        addOriginMarker(to: self.scnView.scene!)
        
        // Disegna il contenuto
        drawContent(roomsNode: roomsNode, borders: borders)
        
        // Imposta il centro di massa
        setMassCenter()
        
        // Imposta la fotocamera
        setCamera()
    }
    
    func addOriginMarker(to scene: SCNScene) {
        let originNode = SCNNode()
        originNode.geometry = SCNSphere(radius: 0.2)
        originNode.geometry?.firstMaterial?.diffuse.contents = UIColor.systemPink
        originNode.position = SCNVector3(0, 0, 0)
        
        scene.rootNode.addChildNode(originNode)
    }
    
    func addLastPositionMarker() -> SCNNode {
        let originNode = SCNNode()
        originNode.geometry = SCNSphere(radius: 0.2)
        originNode.geometry?.firstMaterial?.diffuse.contents = UIColor.red
        originNode.position = SCNVector3(0, 0, 0)
        originNode.name = "Originini"

        return originNode
    }
    
    @MainActor
    func loadPlanimetrySwitching(scene: SCNScene, roomsNode: [String]?, borders: Bool, lastFloorPosition: simd_float4x4?, lastRoom: Room, floor: Floor ) {
        print("DEBUG LAST ROOM: \(lastRoom.name)\n")
        
        var newPos0 = generatePositionNode(UIColor(red: 255, green: 0, blue: 0, alpha: 1.0), 0.2)
        newPos0.simdWorldTransform = lastFloorPosition!
        
        print("\(printMatrix4x4(newPos0.simdWorldTransform, label: "Old"))\n")
//        var newPos0 = scene.rootNode.childNodes.first(where: { $0.name == "POS_ROOM" }) ?? SCNNode()
        
        newPos0.simdWorldTransform = applyInverseRotoTraslation(to: newPos0, with: floor.associationMatrix[lastRoom.name]!)
        
        print("\(printMatrix4x4(newPos0.simdWorldTransform, label: "New"))\n")
        
        scene.rootNode.addChildNode(newPos0)
        
        self.scnView.scene = scene
        drawContent(roomsNode: roomsNode, borders: borders)
        setMassCenter()
        setCamera()
    }
    
    func setCamera(){
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
    
    func setCameraUp() {
        cameraNode.camera = SCNCamera()
        
        // Add the camera node to the scene
        scnView.scene?.rootNode.addChildNode(cameraNode)
        
        // Position the camera at the same Y level as the mass center, and at a certain distance along the Z-axis
        let cameraDistance: Float = 10.0 // Distance in front of the mass center
        let cameraHeight: Float = massCenter.worldPosition.y + 2.0 // Slightly above the mass center
        
        cameraNode.worldPosition = SCNVector3(massCenter.worldPosition.x, cameraHeight, massCenter.worldPosition.z + cameraDistance)
        
        // Set the camera to use perspective projection
        cameraNode.camera?.usesOrthographicProjection = false
        
        // Optionally set the field of view
        cameraNode.camera?.fieldOfView = 60.0 // Adjust as needed
        
        // Make the camera look at the mass center
        let lookAtConstraint = SCNLookAtConstraint(target: massCenter)
        lookAtConstraint.isGimbalLockEnabled = true
        cameraNode.constraints = [lookAtConstraint]
        
        // Add ambient light to the scene
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light!.type = .ambient
        ambientLight.light!.color = UIColor(white: 0.5, alpha: 1.0)
        scnView.scene?.rootNode.addChildNode(ambientLight)
        
        // Add a directional light to simulate sunlight
        let directionalLight = SCNNode()
        directionalLight.light = SCNLight()
        directionalLight.light!.type = .directional
        directionalLight.light!.color = UIColor(white: 1.0, alpha: 1.0)
        directionalLight.eulerAngles = SCNVector3(-Float.pi / 3, 0, 0) // Adjust angle as needed
        scnView.scene?.rootNode.addChildNode(directionalLight)
        
        // Set the point of view of the scene to the camera node
        scnView.pointOfView = cameraNode
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
    
    func generatePositionNode(_ color: UIColor, _ radius: CGFloat) -> SCNNode {
        
        let houseNode = SCNNode() //3 Sphere
        
        let sphere = SCNSphere(radius: radius)
        let sphereNode = SCNNode()
        sphereNode.geometry = sphere
        sphereNode.geometry?.firstMaterial?.diffuse.contents = color
        
        let sphere2 = SCNSphere(radius: radius)
        let sphereNode2 = SCNNode()
        sphereNode2.geometry = sphere2
        var color2 = color
        sphereNode2.geometry?.firstMaterial?.diffuse.contents = color2.withAlphaComponent(color2.cgColor.alpha - 0.3)
        sphereNode2.position = SCNVector3(0, 0, -1)
        
        let sphere3 = SCNSphere(radius: radius)
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
    
//    @MainActor func addRoomLocationNode() {
//        
//        if scnView.scene == nil {
//            scnView.scene = SCNScene()
//        }
//        
//        let sphere = SCNSphere(radius: 1.0)
//        
//        var userLocation = generatePositionNode(UIColor(red: 0, green: 0, blue: 255, alpha: 1.0), 0.2)
//        
//        userLocation.name = "POS"
//        scnView.scene?.rootNode.addChildNode(userLocation)
//    }
//    
//    @MainActor func addFloorLocationNode() {
//        
//        if scnView.scene == nil {
//            scnView.scene = SCNScene()
//        }
//        
//        let sphere = SCNSphere(radius: 1.0)
//        
//        var userLocation = generatePositionNode(UIColor(red: 255, green: 0, blue: 0, alpha: 1.0), 0.2)
//        
//        userLocation.name = "POS_FLOOR"
//        scnView.scene?.rootNode.addChildNode(userLocation)
//    }
//
    
    func drawContent(roomsNode: [String]?, borders: Bool) {
        var drawnNodes = Set<String>()
        
        scnView.scene?
            .rootNode
            .childNodes(passingTest: { node, _ in
                node.name != nil &&
                node.name! != "Room" &&
                node.name! != "Floor0" &&
                node.name! != "Geom" &&
                //node.name! != "Lab" &&
                String(node.name!.suffix(4)) != "_grp" &&
                node.name! != "__selected__"
            })
            .forEach { node in
                guard let nodeName = node.name else { return }
                let material = SCNMaterial()
                
                if nodeName == "Floor0" {
                    material.diffuse.contents = UIColor.green
                } else {
                    
                    material.diffuse.contents = UIColor.black
                    
                    if nodeName.prefix(5) == "Floor" {
                        material.diffuse.contents = UIColor.white.withAlphaComponent(0.2)
                    }
                    if ((roomsNode?.contains(nodeName)) != nil){
                        material.diffuse.contents = UIColor.green.withAlphaComponent(0.1)
                    }
                    if nodeName.prefix(6) == "Transi" {
                        material.diffuse.contents = UIColor.white
                    }
                    if nodeName.prefix(4) == "Door" {
                        material.diffuse.contents = UIColor.systemGray5
                    }
                    if nodeName.prefix(4) == "Wall" {
                        material.diffuse.contents = UIColor.black
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
    
    @MainActor func updateInversePosition(_ newPosition: simd_float4x4, _ rotoTraslation: RotoTraslationMatrix?) {
        var floorPositionNode = addLastPositionMarker()
        
        if let r = rotoTraslation {
            if let floorNodes = scnView.scene?.rootNode.childNodes.filter({ $0.name == "Originini" }), !floorNodes.isEmpty {
                floorNodes.forEach { $0.removeFromParentNode() }
            } else {
                print("Nessun nodo trovato con nome 'POS_FLOOR' per la rimozione.")
            }
            
            floorPositionNode.simdWorldTransform = newPosition
            applyInverseRotoTraslation(to: floorPositionNode, with: r)
        }
            scnView.scene?.rootNode.addChildNode(floorPositionNode)
    }
    
    @MainActor func updatePosition(_ newPosition: simd_float4x4, _ rotoTraslation: RotoTraslationMatrix?) {
        
        if rotoTraslation == nil {
            if let roomNodes = scnView.scene?.rootNode.childNodes.filter({ $0.name == "POS_ROOM" }), !roomNodes.isEmpty {
                roomNodes.forEach { $0.removeFromParentNode() }
            } else {
                print("Nessun nodo trovato con nome 'POS' per la rimozione.")
            }
        }
        if rotoTraslation == nil{
            
            
            var roomPositionNode = generatePositionNode(UIColor(red: 0, green: 0, blue: 255, alpha: 1.0), 0.2)
            
            roomPositionNode.simdWorldTransform = newPosition
            roomPositionNode.simdLocalRotate(by: simd_quatf(angle: GLKMathDegreesToRadians(90.0), axis: [0,0,1]))
            
            roomPositionNode.name = "POS_ROOM"
            scnView.scene?.rootNode.addChildNode(roomPositionNode)
            
        }
        
        if let r = rotoTraslation {
            
            //roomPositionNode = projectFloorPosition(roomPositionNode, r)
            
            if let floorNodes = scnView.scene?.rootNode.childNodes.filter({ $0.name == "POS_FLOOR" }), !floorNodes.isEmpty {
                floorNodes.forEach { $0.removeFromParentNode() }
            } else {
                print("Nessun nodo trovato con nome 'POS_FLOOR' per la rimozione.")
            }
            
            var floorPositionNode = generatePositionNode(UIColor(red: 0, green: 255, blue: 0, alpha: 1.0), 0.2)
            
            floorPositionNode.simdWorldTransform = newPosition
            floorPositionNode.simdLocalRotate(by: simd_quatf(angle: GLKMathDegreesToRadians(90.0), axis: [0,0,1]))
            
            applyRotoTraslation(to: floorPositionNode, with: r)
            
            floorPositionNode.name = "POS_FLOOR"
            scnView.scene?.rootNode.addChildNode(floorPositionNode)
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

@MainActor
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

@MainActor
class RenderDelegate: NSObject, @preconcurrency SCNSceneRendererDelegate {
    
    var lastRenderer: SCNSceneRenderer!
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        lastRenderer = renderer
    }
}


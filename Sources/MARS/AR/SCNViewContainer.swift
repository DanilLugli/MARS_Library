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
        print("NAME CALLER: \(nameCaller)")
        
        // Resetta e assegna la nuova scena
        self.scnView.scene = SCNScene()
        self.scnView.scene = scene
        print("New scene set. Number of nodes in scene: \(self.scnView.scene?.rootNode.childNodes.count ?? 0)")
        
        // Stampa il nome di tutti i nodi in rootNode.childNodes
        if let childNodes = self.scnView.scene?.rootNode.childNodes {
            for (index, node) in childNodes.enumerated() {
                print("Node \(index + 1): \(node)")
            }
        } else {
            print("No child nodes found.")
        }
        
        // Aggiunge il marker di origine
        addOriginMarker(to: self.scnView.scene!)
        
        // Disegna il contenuto
        drawContent(roomsNode: roomsNode, borders: borders)
        
        // Imposta il centro di massa
        setMassCenter()
        
        // Configura la camera
        setCamera()
        
        createAxesNode()
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
        sphereNode.geometry?.firstMaterial?.diffuse.contents = UIColor.blue
        
        let sphere2 = SCNSphere(radius: radius)
        let sphereNode2 = SCNNode()
        sphereNode2.geometry = sphere2
        var color2 = color
        sphereNode2.geometry?.firstMaterial?.diffuse.contents = UIColor.blue.withAlphaComponent(0.6)
        sphereNode2.position = SCNVector3(0,    //y = altezza
                                          0,    //x = orizzontale
                                          -1)   //z = profondità
        
        let sphere3 = SCNSphere(radius: radius)
        let sphereNode3 = SCNNode()
        sphereNode3.geometry = sphere3
        var color3 = color
        sphereNode3.geometry?.firstMaterial?.diffuse.contents = UIColor.blue.withAlphaComponent(0.4)
        sphereNode3.position = SCNVector3(0,    //y = altezza
                                          -0.5, //x = orizzontale a sx negativo
                                          0)    //z = profondità
        
        houseNode.addChildNode(sphereNode)
        houseNode.addChildNode(sphereNode2)
        houseNode.addChildNode(sphereNode3)
        //houseNode.worldPosition = SCNVector3(0.0, 3.0, 0.0)
        return houseNode
    }

    func createAxesNode(length: CGFloat = 1.0, radius: CGFloat = 0.02) {
        let axisNode = SCNNode()
        
        // X Axis (Red)
        let xAxis = SCNNode(geometry: SCNCylinder(radius: radius, height: length))
        xAxis.geometry?.firstMaterial?.diffuse.contents = UIColor.red
        xAxis.position = SCNVector3(length / 2, 0, 0) // Offset by half length
        xAxis.eulerAngles = SCNVector3(0, 0, Float.pi / 2) // Rotate cylinder along X-axis
        
        // Y Axis (Green)
        let yAxis = SCNNode(geometry: SCNCylinder(radius: radius, height: length))
        yAxis.geometry?.firstMaterial?.diffuse.contents = UIColor.green
        yAxis.position = SCNVector3(0, length / 2, 0) // Offset by half length
        
        // Z Axis (Blue)
        let zAxis = SCNNode(geometry: SCNCylinder(radius: radius, height: length))
        zAxis.geometry?.firstMaterial?.diffuse.contents = UIColor.blue
        zAxis.position = SCNVector3(0, 0, length / 2) // Offset by half length
        zAxis.eulerAngles = SCNVector3(Float.pi / 2, 0, 0) // Rotate cylinder along Z-axis
        
        // Add axes to parent node
        axisNode.addChildNode(xAxis)
        axisNode.addChildNode(yAxis)
        axisNode.addChildNode(zAxis)
        self.scnView.scene?.rootNode.addChildNode(axisNode)
        
    }
    
    @MainActor func addRoomLocationNode() {
        
        if scnView.scene == nil {
            scnView.scene = SCNScene()
        }
        
        var userLocation = generatePositionNode(UIColor(red: 0, green: 0, blue: 255, alpha: 1.0), 0.2)
        userLocation.simdWorldTransform = simd_float4x4(0)
        userLocation.name = "POS_ROOM"
        scnView.scene?.rootNode.addChildNode(userLocation)
    }
    
    @MainActor func addFloorLocationNode() {
        
        if scnView.scene == nil {
            scnView.scene = SCNScene()
        }
        
        let sphere = SCNSphere(radius: 1.0)
        
        var userLocation = generatePositionNode(UIColor(red: 255, green: 0, blue: 0, alpha: 1.0), 0.2)
        userLocation.simdWorldTransform = simd_float4x4(0)
        userLocation.name = "POS_FLOOR"
        scnView.scene?.rootNode.addChildNode(userLocation)
    }
    
    func drawContent(roomsNode: [String]?, borders: Bool) {
        let excludedNames = ["Room", "Floor0", "Geom", "__selected__"]
        var drawnNodes = Set<String>()

        scnView.scene?.rootNode.childNodes(passingTest: { node, _ in
            guard let name = node.name else { return false }
            return !excludedNames.contains(name) && !name.hasSuffix("_grp")
        })
        .forEach { node in
            guard let nodeName = node.name else { return }

            resetNodeMaterial(node)

            node.geometry?.materials = [materialForNode(named: nodeName, roomsNode: roomsNode)]

            drawnNodes.insert(nodeName)
        }
    }

    private func materialForNode(named name: String, roomsNode: [String]?) -> SCNMaterial {
        let material = SCNMaterial()
        switch name {
        case "Floor0":
            material.diffuse.contents = UIColor.white.withAlphaComponent(0)
        case _ where name.hasPrefix("Floor"):
            material.diffuse.contents = UIColor.white.withAlphaComponent(0.2)
        case _ where roomsNode?.contains(name) == true:
            material.diffuse.contents = UIColor.blue.withAlphaComponent(0)
//        case _ where name.hasPrefix("Transi"):
//            material.diffuse.contents = UIColor.white
//        case _ where name.hasPrefix("Door") && name.hasPrefix("Open"):
//            material.diffuse.contents = UIColor.white
        case _ where name.hasPrefix("Wall"):
            material.diffuse.contents = UIColor.black
//        case _ where name.hasPrefix("Tabl"):
//            material.diffuse.contents = UIColor.systemBrown
//        case _ where name.hasPrefix("Chai"):
//            material.diffuse.contents = UIColor.brown
//        case _ where name.hasPrefix("Stor"):
//            material.diffuse.contents = UIColor.gray
//        case _ where name.hasPrefix("Sofa"):
//            material.diffuse.contents = UIColor.blue
//        case _ where name.hasPrefix("Tele"):
//            material.diffuse.contents = UIColor.orange
        default:
            material.diffuse.contents = UIColor.black
        }
        material.lightingModel = .physicallyBased
        return material
    }

    private func resetNodeMaterial(_ node: SCNNode) {
        // Reimposta il materiale del nodo eliminando eventuali trasparenze o modifiche precedenti
        node.geometry?.materials = [SCNMaterial()] // Crea un materiale vuoto come reset
    }
    
    @MainActor func updateInversePosition(_ newPosition: simd_float4x4, _ rotoTraslation: RotoTraslationMatrix?) {
        var floorPositionNode = addLastPositionMarker()
        
        if let r = rotoTraslation {
            if let floorNodes = scnView.scene?.rootNode.childNodes.filter({ $0.name == "POS_ROOM" }), !floorNodes.isEmpty {
                floorNodes.forEach { $0.removeFromParentNode() }
            } else {
                print("Nessun nodo trovato con nome 'POS_FLOOR' per la rimozione.")
            }
            
            floorPositionNode.simdWorldTransform = newPosition
            applyInverseRotoTraslation(to: floorPositionNode, with: r)
        }
            scnView.scene?.rootNode.addChildNode(floorPositionNode)
    }
    
    @MainActor func updatePosition(_ newPosition: simd_float4x4, _ matrix: RotoTraslationMatrix?, floor: Floor) {
        
        if matrix == nil {
//            if let roomNodes = scnView.scene?.rootNode.childNodes.filter({ $0.name == "POS_ROOM" }), !roomNodes.isEmpty {
//                roomNodes.forEach { $0.removeFromParentNode() }
//            } else {
//                print("Nessun nodo trovato con nome 'POS' per la rimozione.")
//            }
//            
//            var roomPositionNode = generatePositionNode(UIColor(red: 0, green: 0, blue: 255, alpha: 1.0), 0.2)
            scnView.scene?.rootNode.childNodes.first(where: { $0.name == "POS_ROOM" })?.simdWorldTransform = newPosition
            //roomPositionNode.simdWorldTransform = newPosition
            //roomPositionNode.simdLocalRotate(by: simd_quatf(angle: GLKMathDegreesToRadians(90.0), axis: [0,0,1]))
            
//            roomPositionNode.name = "POS_ROOM"
//            scnView.scene?.rootNode.addChildNode(roomPositionNode)
            
        }
        
        if let r = matrix {
            
            updateFloorPositionNode(in: scnView,
                                    newPosition: newPosition,
                                    withColor: UIColor.green,
                                    size: 0.2,
                                    rotationAngle: 90.0,
                                    rotationAxis: [0, 0, 1],
                                    rotoTranslationMatrix: matrix!, floor: floor)
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





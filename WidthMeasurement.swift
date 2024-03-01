/*
 Here is a project description of what I want this app to do.
 
 On this screen I want to access the devices camera and project a scale (similar to a back up camera on a car) that overlays on the camera and then I want to be able to use that scale to then project/measure the distance between (or the width of the opening/trail width) objects on a trail. I want to be able to then take a picture and log the picture with a geo location stamp and time stamp and eventually link those pictures to my MapView.swift 
 */

import SwiftUI
import ARKit

struct ARViewContainer: UIViewRepresentable {
    typealias UIViewType = ARSCNView
    
    @Binding var anchors: [ARAnchor]
    
    func makeUIView(context: Context) -> ARSCNView {
        let arView = ARSCNView(frame: .zero)
        arView.session.run(ARWorldTrackingConfiguration())
        arView.delegate = context.coordinator
        
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tapGesture)
        
        return arView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {
        // Remove old anchors
        uiView.session.currentFrame?.anchors.forEach { uiView.session.remove(anchor: $0) }
        // Add new anchors
        anchors.forEach { uiView.session.add(anchor: $0) }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, ARSCNViewDelegate {
        var parent: ARViewContainer
        
        // New property to keep track of marker nodes
        var markerNodes = [SCNNode]()
        
        private var tapCount = 0

        
        init(_ parent: ARViewContainer) {
            self.parent = parent
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            let view = gesture.view as! ARSCNView
            let location = gesture.location(in: view)
            
            // Increment tap count
            tapCount += 1
            
            // Add anchor and marker at tap location
            addAnchorAtScreenPosition(location, in: view)
            addMarkerAtScreenPosition(location, in: view)
            
            // Clear markers and reset tap count after the third tap
            if tapCount == 3 {
                clearMarkers()
                //now clear/rest the anchors
                parent.anchors.removeAll()
                tapCount = 0  // Reset tap count
            }
            
          
            
         
        }
        
        // Adds a visual marker (e.g., a sphere) at the specified screen position.
        func addMarkerAtScreenPosition(_ point: CGPoint, in view: ARSCNView) {
            guard let raycastQuery = view.raycastQuery(from: point, allowing: .estimatedPlane, alignment: .any),
                  let raycastResult = view.session.raycast(raycastQuery).first else {
                
                
                return
            }
            
            // Create a 3D sphere node as a marker
            let sphere = SCNSphere(radius: 0.01) // Adjust size as needed
            let sphereNode = SCNNode(geometry: sphere)
            sphereNode.geometry?.firstMaterial?.diffuse.contents = UIColor.red // Change color as needed
            sphereNode.position = SCNVector3(raycastResult.worldTransform.columns.3.x,
                                             raycastResult.worldTransform.columns.3.y,
                                             raycastResult.worldTransform.columns.3.z)
            
            // Add the sphere node to the scene
            view.scene.rootNode.addChildNode(sphereNode)
            markerNodes.append(sphereNode)
        }
        
        // New method to clear all markers
        func clearMarkers() {
            for node in markerNodes {
                node.removeFromParentNode()
            }
            markerNodes.removeAll()
        }
        
        
        func addAnchorAtScreenPosition(_ point: CGPoint, in view: ARSCNView) {
            if let raycastQuery = view.raycastQuery(from: point, allowing: .estimatedPlane, alignment: .any) {
                let raycastResults = view.session.raycast(raycastQuery)
                if let result = raycastResults.first {
                    let anchor = ARAnchor(transform: result.worldTransform)
                    parent.anchors.append(anchor)
                }
            }
        }
    }
}

struct WidthMeasurementView: View {
    @State private var anchors: [ARAnchor] = []
    @State private var distanceText: String = ""
    
    var body: some View {
        ZStack {
            ARViewContainer(anchors: $anchors)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                Spacer()
                Rectangle()
                    .frame(height: 2)
                    .foregroundColor(.white)
                Text(distanceText)
                    .font(.title)
                    .padding()
                Spacer()
            }
        }
        .onChange(of: anchors) { newAnchors in
            if newAnchors.count == 2 {
                let distance = calculateDistance(anchor1: newAnchors[0], anchor2: newAnchors[1])
                distanceText = String(format: "%.2f inches", distance)
                anchors.removeAll()  // Clear anchors for the next measurement
            }
            
        }
    }
    
    func calculateDistance(anchor1: ARAnchor, anchor2: ARAnchor) -> Float {
        let transform1 = SCNMatrix4(anchor1.transform)
        let transform2 = SCNMatrix4(anchor2.transform)
        
        let position1 = SCNVector3Make(transform1.m41, transform1.m42, transform1.m43)
        let position2 = SCNVector3Make(transform2.m41, transform2.m42, transform2.m43)
        
        let distanceInMeters = SCNVector3Distance(position1, position2)
        
        // Convert the distance from meters to inches
        let distanceInInches = distanceInMeters * 39.3701
        return distanceInInches
    }
}

// Helper function to calculate distance between two points
func SCNVector3Distance(_ a: SCNVector3, _ b: SCNVector3) -> Float {
    return sqrt(pow(b.x - a.x, 2) + pow(b.y - a.y, 2) + pow(b.z - a.z, 2))
}




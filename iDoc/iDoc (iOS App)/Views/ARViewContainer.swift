//
//  ARViewContainer.swift
//  iDoc
//
//  Created by Keith  Salyer on 2/24/25.
//

import SwiftUI
import ARKit

struct ARViewContainer: UIViewRepresentable {
    func makeUIView(context: Context) -> ARSCNView {
        let sceneView = ARSCNView(frame: .zero)
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        sceneView.session.run(configuration)
        return sceneView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {
        // No dynamic updates needed
    }
}

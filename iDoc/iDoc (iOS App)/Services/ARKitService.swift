//
//  ARKitService.swift
//  iDoc
//
//  Created by Keith  Salyer on 2/24/25.
//

import ARKit

class ARKitService {
    static func configureSceneView(_ sceneView: ARSCNView) {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
}

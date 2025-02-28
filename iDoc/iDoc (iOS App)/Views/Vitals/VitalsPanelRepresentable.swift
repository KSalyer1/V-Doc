//
//  VitalsPanelRepresentable.swift
//  iDoc
//
//  Created by Keith  Salyer on 2/24/25.
//

import SwiftUI

struct VitalsPanelRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> VitalsPanelView {
        return VitalsPanelView(frame: .zero)
    }
    
    func updateUIView(_ uiView: VitalsPanelView, context: Context) {
        // No updates needed
    }
}

struct VitalsPanelRepresentable_Previews: PreviewProvider {
    static var previews: some View {
        VitalsPanelRepresentable()
            .previewLayout(.sizeThatFits)
    }
}

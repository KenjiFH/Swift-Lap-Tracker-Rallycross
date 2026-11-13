//
//  ContentView.swift
//  Apexiel Proj1
//
//  Created by Kenji Fahselt on 7/13/25.
//

import SwiftUI

struct ContentView: View {
    
    var body: some View {
        CaptureView()
    }
    
}

struct ModalView: View {
    // Access the environment's dismiss action to close the modal.
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack {
            Text("This is a modal popup!")
                .padding()
            Button("Dismiss") {
                // Call dismiss() to close the view.
                dismiss()
            }
        }
    }
}

#Preview {
    ContentView()
}

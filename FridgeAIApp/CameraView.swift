//
//  CameraView.swift
//  FridgeAIApp
//
//  Created by Ranveer Singh on 3/28/25.
//

import SwiftUI
import AVFoundation

struct CameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) var presentationMode
    @State private var showError = false
    @State private var errorMessage = ""
    let sourceType: UIImagePickerController.SourceType
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        print("Creating image picker controller")
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        
        // Check if source type is available
        if !UIImagePickerController.isSourceTypeAvailable(sourceType) {
            print("Source type is not available")
            errorMessage = "This feature is not available on this device"
            showError = true
            return picker
        }
        
        // Check authorization status for camera or photo library
        if sourceType == .camera {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                print("Camera is authorized")
                return picker
            case .notDetermined:
                print("Requesting camera authorization")
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    if !granted {
                        print("Camera access denied")
                        errorMessage = "Camera access is required to take photos"
                        showError = true
                    }
                }
                return picker
            case .denied, .restricted:
                print("Camera access denied or restricted")
                errorMessage = "Please enable camera access in Settings"
                showError = true
                return picker
            @unknown default:
                print("Unknown camera authorization status")
                errorMessage = "Unknown camera authorization status"
                showError = true
                return picker
            }
        } else {
            // For photo library, we'll handle authorization in the coordinator
            return picker
        }
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            print("Image picker finished picking media")
            if let image = info[.originalImage] as? UIImage {
                print("Successfully captured image")
                parent.image = image
            } else {
                print("Failed to get image from picker")
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            print("Image picker cancelled")
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFailWithError error: Error) {
            print("Image picker failed with error: \(error)")
            parent.errorMessage = "Failed to capture image: \(error.localizedDescription)"
            parent.showError = true
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// Preview provider for SwiftUI canvas
struct CameraView_Previews: PreviewProvider {
    static var previews: some View {
        CameraView(image: .constant(nil), sourceType: .camera)
    }
}

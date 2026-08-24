import SwiftUI
import UIKit

/// The system camera, for photographing the room you are standing in.
///
/// The app only ever offered the photo library, so someone posting a room had
/// to leave, open Camera, take the picture, come back and find it again — and
/// Info.plist promised a camera the app never opened. Posting a room is the one
/// moment the person is most likely to be standing in it.
///
/// UIImagePickerController rather than a custom AVFoundation capture screen:
/// this is the camera people already know, it handles orientation, flash and
/// the retake step for free, and there is nothing here worth reinventing.
struct CameraPicker: UIViewControllerRepresentable {

    /// The captured photo, as JPEG bytes and as an image. Bytes are handed back
    /// alongside the image because the rest of the posting flow uploads exactly
    /// what it was given rather than re-encoding.
    let onCapture: (UIImage, Data) -> Void

    @Environment(\.dismiss) private var dismiss

    /// Whether this device can actually take a photo. Simulators cannot, and
    /// offering the option there presents a camera that never appears.
    static var isAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, dismiss: { dismiss() })
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

        private let onCapture: (UIImage, Data) -> Void
        private let dismiss: () -> Void

        init(onCapture: @escaping (UIImage, Data) -> Void, dismiss: @escaping () -> Void) {
            self.onCapture = onCapture
            self.dismiss = dismiss
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            // The edited image when there is one, so a crop the person made is
            // the picture that gets posted.
            let picked = (info[.editedImage] as? UIImage) ?? (info[.originalImage] as? UIImage)

            // 0.85 rather than 1.0: a full-quality capture from a modern phone
            // is several megabytes, and six of them is an upload people abandon
            // on a phone signal. The difference is not visible on a room photo.
            if let image = picked, let data = image.jpegData(compressionQuality: 0.85) {
                onCapture(image, data)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}

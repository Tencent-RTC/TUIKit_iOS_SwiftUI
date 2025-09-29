import SwiftUI

public struct ImagePickerConfig {
    var maxCount: Int = 1
    var gridCount: Int = 4
    var primaryColor: Int = -1
}

public struct ImagePicker: UIViewControllerRepresentable {
    static var sourceType: UIImagePickerController.SourceType?
    static var selectedImage: ((UIImage?) -> Void)?
    static let shared = ImagePicker()
    static var config: ImagePickerConfig?

    public static func pickImages(sourceType: UIImagePickerController.SourceType,
                                  imagePickerConfig: ImagePickerConfig? = nil,
                                  selectedImage: @escaping (UIImage?) -> Void) -> ImagePicker
    {
        self.sourceType = sourceType
        self.selectedImage = selectedImage
        config = imagePickerConfig
        return shared
    }

    public func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = ImagePicker.sourceType ?? .photoLibrary
        picker.delegate = context.coordinator
        picker.mediaTypes = ["public.image"]
        return picker
    }

    public func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                ImagePicker.selectedImage?(image)
            } else {
                ImagePicker.selectedImage?(nil)
            }
            picker.dismiss(animated: true)
        }

        public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            ImagePicker.selectedImage?(nil)
            picker.dismiss(animated: true)
        }
    }
}

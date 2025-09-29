import Foundation
import SwiftUI
import UniformTypeIdentifiers

#if canImport(UIKit)
import UIKit
#endif

public struct FilePickerConfig {
    var maxCount: Int = 1
}

public struct FilePicker: UIViewControllerRepresentable {
    static var selectedFile: ((URL?) -> Void)?
    static let shared = FilePicker()
    static var config: FilePickerConfig?

    public static func pickFiles(config: FilePickerConfig? = nil, selectedFile: @escaping (URL?) -> Void) -> FilePicker {
        self.config = config
        self.selectedFile = selectedFile
        return shared
    }

    public func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let documentPicker: UIDocumentPickerViewController
        if #available(iOS 14.0, *) {
            documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.item])
        } else {
            documentPicker = UIDocumentPickerViewController(documentTypes: ["public.item"], in: .import)
        }
        documentPicker.delegate = context.coordinator
        documentPicker.allowsMultipleSelection = false
        return documentPicker
    }

    public func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: FilePicker
        init(_ parent: FilePicker) {
            self.parent = parent
        }

        public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else {
                FilePicker.selectedFile?(nil)
                return
            }
            let securityScoped = url.startAccessingSecurityScopedResource()
            defer {
                if securityScoped {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            FilePicker.selectedFile?(url)
        }

        public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            FilePicker.selectedFile?(nil)
        }
    }
}

import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct FilePickerImpl {
    static func makeController(delegate: UIDocumentPickerDelegate) -> UIDocumentPickerViewController {
        let controller: UIDocumentPickerViewController
        if #available(iOS 14.0, *) {
            controller = UIDocumentPickerViewController(forOpeningContentTypes: [.item])
        } else {
            controller = UIDocumentPickerViewController(documentTypes: ["public.item"], in: .import)
        }
        controller.delegate = delegate
        controller.allowsMultipleSelection = false
        return controller
    }

    static func didPickDocuments(_ urls: [URL]) {
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
}

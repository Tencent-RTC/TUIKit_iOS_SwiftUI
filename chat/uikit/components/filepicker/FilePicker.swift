import Foundation
import SwiftUI
import UniformTypeIdentifiers

#if canImport(UIKit)
import UIKit
#endif

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
        FilePickerImpl.makeController(delegate: context.coordinator)
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
            FilePickerImpl.didPickDocuments(urls)
        }

        public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            FilePicker.selectedFile?(nil)
        }
    }
}

public struct FilePickerConfig {
    public var userMaxCount: Int? = nil
}

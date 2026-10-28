import Foundation
import ObjectiveC
import QuickLook

class FilePreviewController: NSObject, QLPreviewControllerDataSource {
    let fileURL: URL
    init(fileURL: URL) {
        self.fileURL = fileURL
        super.init()
    }

    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return 1
    }

    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        return fileURL as QLPreviewItem
    }
}

class FilePreviewCoordinator: NSObject {
    let fileURL: URL
    init(fileURL: URL) {
        self.fileURL = fileURL
        super.init()
    }
}

private enum AssociatedObjectKey {
    static var coordinator = "FilePreviewCoordinatorKey"
}

class FilePreviewManager {
    static func openFile(at path: String) {
        let fileURL = URL(fileURLWithPath: path)
        let previewController = QLPreviewController()
        let filePreview = FilePreviewController(fileURL: fileURL)
        previewController.dataSource = filePreview
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            let coordinator = FilePreviewCoordinator(fileURL: fileURL)
            objc_setAssociatedObject(previewController, &AssociatedObjectKey.coordinator, coordinator, .OBJC_ASSOCIATION_RETAIN)
            topVC.present(previewController, animated: true, completion: nil)
        }
    }

    static func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    static func fileTypeIcon(for fileName: String) -> String {
        let extensionName = (fileName as NSString).pathExtension.lowercased()
        switch extensionName {
        case "pdf": return "message_file_type_pdf"
        case "ppt", "pptx", "key", "keynote": return "message_file_type_ppt"
        case "doc", "docx": return "message_file_type_word"
        case "xls", "xlsx", "csv", "numbers": return "message_file_type_excel"
        case "txt", "log", "md", "rtf": return "message_file_type_txt"
        case "zip", "rar", "7z", "tar", "gz", "bz2": return "message_file_type_zip"
        case "jpg", "jpeg", "png", "gif", "bmp", "webp", "svg", "heic", "heif": return "message_file_type_img"
        default: return "message_file_type_unknown"
        }
    }
}

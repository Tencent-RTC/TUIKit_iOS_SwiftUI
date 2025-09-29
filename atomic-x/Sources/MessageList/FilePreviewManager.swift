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
        if let rootVC = UIApplication.shared.windows.first?.rootViewController {
            let coordinator = FilePreviewCoordinator(fileURL: fileURL)
            objc_setAssociatedObject(previewController, &AssociatedObjectKey.coordinator, coordinator, .OBJC_ASSOCIATION_RETAIN)
            rootVC.present(previewController, animated: true, completion: nil)
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
        case "pdf":
            return "doc.fill"
        case "doc", "docx":
            return "doc.fill"
        case "xls", "xlsx":
            return "tablecells.fill"
        case "ppt", "pptx":
            return "chart.bar.fill"
        case "zip", "rar", "7z":
            return "archivebox.fill"
        case "txt":
            return "doc.text.fill"
        case "jpg", "jpeg", "png", "gif", "webp":
            return "photo.fill"
        case "mp3", "wav", "aac", "flac":
            return "music.note"
        case "mp4", "mov", "avi", "mkv":
            return "film.fill"
        default:
            return "doc.fill"
        }
    }
}

import UIKit

final class MediaThumbnailCache {
    static let shared = MediaThumbnailCache()

    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 60
        cache.totalCostLimit = 150 * 1024 * 1024
    }

    func cachedImage(for path: String) -> UIImage? {
        cache.object(forKey: path as NSString)
    }

    func image(for path: String, maxPixelSize: CGFloat) async -> UIImage? {
        if let cached = cachedImage(for: path) {
            return cached
        }
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let decoded = Self.decodeDownscaled(path: path, maxPixelSize: maxPixelSize)
                if let decoded {
                    let cost = decoded.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
                    self.cache.setObject(decoded, forKey: path as NSString, cost: cost)
                }
                continuation.resume(returning: decoded)
            }
        }
    }

    // 直接降采样，避免先解码完整位图造成内存峰值。
    private static func decodeDownscaled(path: String, maxPixelSize: CGFloat) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil) else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, Int(maxPixelSize)),
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}

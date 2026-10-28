import Foundation

class BundleHelper {
    static func atomicXBundle() -> Bundle {
        let bundlePath = getBundlePath(bundleName: "ChatUIKitBundle", classType: BundleHelper.self, frameworkName: "")
        guard let atomicXBundle = Bundle(path: bundlePath) else {
            return Bundle.main
        }
        return atomicXBundle
    }

    static func findLocalizableBundle(bundleName: String, classType: AnyClass, language: String, frameworkName: String) -> Bundle? {
        var bundleCache: [String: Bundle] = [:]
        let languageDir = "Localizable/\(language)"
        let cacheKey = "\(bundleName)_\(languageDir)"
        var bundle = bundleCache[cacheKey]
        if bundle == nil {
            let bundlePath = getBundlePath(bundleName: bundleName, classType: classType, frameworkName: frameworkName)
            if let path = Bundle(path: bundlePath)?.path(forResource: languageDir, ofType: "lproj") {
                bundle = Bundle(path: path)
                if let bundle = bundle {
                    bundleCache[cacheKey] = bundle
                }
            }
        }
        return bundle
    }

    static func getBundlePath(bundleName: String, classType: AnyClass, frameworkName: String) -> String {
        var bundlePathCache: [String: String] = [:]
        let classTypeString = NSStringFromClass(classType)
        let bundlePathKey = "\(bundleName)_\(classTypeString)"
        if let bundlePath = bundlePathCache[bundlePathKey] {
            return bundlePath
        }
        var bundlePath = Bundle.main.path(forResource: bundleName, ofType: "bundle")
        if bundlePath == nil || bundlePath?.isEmpty == true {
            let frameworkBundlePath = Bundle(for: classType).path(forResource: frameworkName, ofType: "bundle")
            if let frameworkBundle = Bundle(path: frameworkBundlePath ?? "") {
                bundlePath = frameworkBundle.path(forResource: bundleName, ofType: "bundle")
            }
        }
        if (bundlePath == nil || bundlePath?.isEmpty == true) && !frameworkName.isEmpty {
            var path = Bundle.main.bundlePath
            path = (path as NSString).appendingPathComponent("Frameworks")
            path = (path as NSString).appendingPathComponent(frameworkName)
            path = (path as NSString).appendingPathExtension("framework") ?? path
            path = (path as NSString).appendingPathComponent(bundleName)
            bundlePath = (path as NSString).appendingPathExtension("bundle")
        }
        if let finalPath = bundlePath {
            bundlePathCache[bundlePathKey] = finalPath
        }
        return bundlePath ?? ""
    }
}

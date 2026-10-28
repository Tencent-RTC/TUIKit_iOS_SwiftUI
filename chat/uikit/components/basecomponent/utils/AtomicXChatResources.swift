import UIKit

public class AtomicXChatResources {
    public static let frameworkBundle = Bundle(for: AtomicXChatResources.self)
    public static var resourceBundle: Bundle {
        if let bundlePath = frameworkBundle.path(forResource: "ChatUIKitBundle", ofType: "bundle"),
           let bundle = Bundle(path: bundlePath)
        {
            return bundle
        }
        return frameworkBundle
    }

    public static func image(named name: String) -> UIImage? {
        return UIImage(named: name, in: resourceBundle, compatibleWith: nil)
    }
}

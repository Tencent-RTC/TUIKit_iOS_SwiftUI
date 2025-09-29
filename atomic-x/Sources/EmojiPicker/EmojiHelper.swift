import Foundation
import SwiftUI
import UIKit

let defaultEmojiSize = CGSize(width: 23, height: 23)
class EmojiBundleHelper {
    static var bundlePath: String = BundleHelper.getBundlePath(bundleName: "EmojiFace", classType: EmojiBundleHelper.self, frameworkName: "AtomicXBundle")
    static func appendPath(_ path: String) -> String {
        return (bundlePath as NSString).appendingPathComponent(path)
    }

    static func getLocalizedString(_ key: String) -> String {
        return LanguageHelper.getLocalizedString(forKey: key, bundle: "EmojiFace", classType: EmojiBundleHelper.self, frameworkName: "AtomicXBundle")
    }
}

class EmojiGroup: NSObject {
    public var groupIndex: Int = 0
    public var groupPath: String?
    public var rowCount: Int = 0
    public var itemCountPerRow: Int = 0
    public var emojis: [EmojiData]?
    public var needBackDelete: Bool = false
    public var menuPath: String?
    public var recentGroup: EmojiGroup?
    public var isNeedAddInInputBar: Bool = false
    public var groupName: String?
    private var _emojisMap: [String: String]?
    public var emojisMap: [String: String] {
        if _emojisMap == nil || (_emojisMap?.count ?? 0) != (emojis?.count ?? 0) {
            var emojiDic: [String: String] = [:]
            if let emojis = emojis {
                for data in emojis {
                    if let name = data.name {
                        emojiDic[name] = data.path
                    }
                }
            }
            _emojisMap = emojiDic
        }
        return _emojisMap ?? [:]
    }
}

class EmojiCache {
    public static let shared = EmojiCache()
    private var emojiCache: [String: UIImage] = [:]
    
    private init() {}
    public func addEmojiToCache(_ path: String) {
        asyncDecodeImage(path) { [weak self] key, image in
            guard let self = self, let key = key, let image = image else { return }
            self.emojiCache[key] = image
        }
    }

    public func getImageFromCache(_ path: String) -> UIImage? {
        guard !path.isEmpty else { return nil }
        if let image = emojiCache[path] {
            return image
        }
        if path.contains(".gif") {
            if let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                return UIImage(data: data)
            }
            return nil
        }
        if let image = UIImage(contentsOfFile: path) {
            return image
        }
        // In case image is gif but suffix is not .gif
        let formatPath = path + ".gif"
        if let data = try? Data(contentsOf: URL(fileURLWithPath: formatPath)) {
            return UIImage(data: data)
        }
        return nil
    }

    func asyncDecodeImage(_ path: String, complete: @escaping (String?, UIImage?) -> Void) {
        DispatchQueue.global().async {
            if let image = UIImage(contentsOfFile: path) {
                DispatchQueue.main.async {
                    complete(path, image)
                }
            } else {
                DispatchQueue.main.async {
                    complete(nil, nil)
                }
            }
        }
    }
}

class EmojiConfig: NSObject {
    public static let shared = EmojiConfig()
    public var emojiGroups: [EmojiGroup] = []
    public var chatPopDetailGroups: [EmojiGroup] = []
    public var chatContextEmojiDetailGroups: [EmojiGroup] = []
    
    override private init() {
        super.init()
        if let group = createEmojiGroup() {
            emojiGroups.append(group)
        }
    }

    private func createEmojiGroup() -> EmojiGroup? {
        var emojiEmojis: [EmojiData] = []
        let plistPath = EmojiBundleHelper.appendPath("emoji/emoji.plist")
        if let emojiList = NSArray(contentsOfFile: plistPath) as? [[String: String]] {
            for dic in emojiList {
                let data = EmojiData()
                if let name = dic["face_name"], let fileName = dic["face_file"] {
                    let path = "emoji/\(fileName)@2x.png"
                    let localizableName = EmojiBundleHelper.getLocalizedString(name)
                    data.name = name
                    data.path = EmojiBundleHelper.appendPath(path)
                    data.localizableName = localizableName
                    if let path = data.path {
                        EmojiCache.shared.addEmojiToCache(path)
                    }
                    emojiEmojis.append(data)
                }
            }
        }
        if !emojiEmojis.isEmpty {
            let emojiGroup = EmojiGroup()
            emojiGroup.emojis = emojiEmojis
            emojiGroup.groupIndex = 0
            emojiGroup.groupPath = EmojiBundleHelper.appendPath("emoji/")
            emojiGroup.menuPath = EmojiBundleHelper.appendPath("emoji/menu")
            emojiGroup.isNeedAddInInputBar = true
            emojiGroup.groupName = "All"
            emojiGroup.rowCount = 4
            emojiGroup.itemCountPerRow = 8
            emojiGroup.needBackDelete = false
            if let path = emojiGroup.menuPath {
                EmojiCache.shared.addEmojiToCache(path)
            }
            EmojiCache.shared.addEmojiToCache(EmojiBundleHelper.appendPath("del_normal"))
            EmojiCache.shared.addEmojiToCache(EmojiBundleHelper.appendPath("ic_unknown_image@2x"))
            return emojiGroup
        }
        return nil
    }

    func getChatPopMenuRecentQueue() -> EmojiGroup? {
        var emojiEmojis: [EmojiData] = []
        if let emojis = getChatPopMenuQueue() {
            for dic in emojis {
                let data = EmojiData()
                if let name = dic["face_name"] as? String, let fileName = dic["face_file"] as? String {
                    let path = "emoji/\(fileName)"
                    let localizableName = EmojiBundleHelper.getLocalizedString(name)
                    data.name = name
                    data.path = EmojiBundleHelper.appendPath(path)
                    data.localizableName = localizableName
                    emojiEmojis.append(data)
                }
            }
        }
        if !emojiEmojis.isEmpty {
            var ocEmojis: [EmojiData] = []
            for emoji in emojiEmojis {
                ocEmojis.append(emoji)
            }
            let emojiGroup = EmojiGroup()
            emojiGroup.emojis = ocEmojis
            emojiGroup.groupIndex = 0
            emojiGroup.groupPath = EmojiBundleHelper.appendPath("emoji/")
            emojiGroup.menuPath = EmojiBundleHelper.appendPath("emoji/menu")
            emojiGroup.rowCount = 1
            emojiGroup.itemCountPerRow = 6
            emojiGroup.needBackDelete = false
            emojiGroup.isNeedAddInInputBar = true
            return emojiGroup
        }
        return nil
    }

    func updateRecentMenuQueue(_ emojiName: String) {
        let emojis = getChatPopMenuQueue() ?? []
        var muArray = emojis
        if let index = emojis.firstIndex(where: { ($0["face_name"] as? String) == emojiName }) {
            let targetDic = emojis[index]
            muArray.remove(at: index)
            muArray.insert(targetDic, at: 0)
        } else {
            muArray.removeLast()
            if let emojis = NSArray(contentsOfFile: EmojiBundleHelper.appendPath("emoji/emoji.plist")) as? [[String: String]] {
                if let targetDic = emojis.first(where: { $0["face_name"] == emojiName }) {
                    muArray.insert(targetDic, at: 0)
                }
            }
        }
        UserDefaults.standard.set(muArray, forKey: "TUIChatPopMenuQueue")
        UserDefaults.standard.synchronize()
    }

    private func getChatPopMenuQueue() -> [[String: Any]]? {
        if let emojis = UserDefaults.standard.object(forKey: "TUIChatPopMenuQueue") as? [[String: Any]], !emojis.isEmpty {
            if let dic = emojis.last, let fileName = dic["face_file"] as? String {
                let path = "emoji/\(fileName)"
                if UIImage(contentsOfFile: EmojiBundleHelper.appendPath(path)) != nil {
                    return emojis
                }
            }
        }
        return NSArray(contentsOfFile: EmojiBundleHelper.appendPath("emoji/emojiRecentDefaultList.plist")) as? [[String: Any]]
    }
}

import Foundation
import SwiftUI
import UIKit

let defaultEmojiSize = CGSize(width: 23, height: 23)
class EmojiBundleHelper {
    static var bundlePath: String = BundleHelper.getBundlePath(bundleName: "EmojiFace", classType: EmojiBundleHelper.self, frameworkName: "ChatUIKitBundle")
    static func appendPath(_ path: String) -> String {
        return (bundlePath as NSString).appendingPathComponent(path)
    }

    static func getLocalizedString(_ key: String) -> String {
        return LanguageHelper.getLocalizedString(forKey: key, bundle: "EmojiFace", classType: EmojiBundleHelper.self, frameworkName: "ChatUIKitBundle")
    }
}



class EmojiCache {
    static let shared = EmojiCache()
    private var emojiCache: [String: UIImage] = [:]

    private init() {}
    func addEmojiToCache(_ path: String) {
        asyncDecodeImage(path) { [weak self] key, image in
            guard let self = self, let key = key, let image = image else { return }
            self.emojiCache[key] = image
        }
    }

    func getImageFromCache(_ path: String) -> UIImage? {
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
    static let shared = EmojiConfig()
    static let builtInGroupID = "tui_built_in_little_emoji"
    var emojiGroups: [EmojiGroup] = []
    var chatPopDetailGroups: [EmojiGroup] = []
    var chatContextEmojiDetailGroups: [EmojiGroup] = []

    override private init() {
        super.init()
        if let group = createEmojiGroup() {
            emojiGroups.append(group)
        }
    }

    static let groupsDidChangeNotification = Notification.Name("EmojiConfigGroupsDidChange")


    @discardableResult
    func addEmojiGroup(_ group: EmojiGroup) -> EmojiConfig {
        if let index = emojiGroups.firstIndex(where: { $0.id == group.id }) {
            emojiGroups.remove(at: index)
        }
        emojiGroups.append(group)
        notifyGroupsChanged()
        return self
    }

    @discardableResult
    func addEmojiGroups(_ groups: [EmojiGroup]) -> EmojiConfig {
        for group in groups {
            if let existing = emojiGroups.firstIndex(where: { $0.id == group.id }) {
                emojiGroups.remove(at: existing)
            }
            emojiGroups.append(group)
        }
        notifyGroupsChanged()
        return self
    }

    @discardableResult
    func insertEmojiGroup(_ group: EmojiGroup, at index: Int) -> EmojiConfig {
        if let existing = emojiGroups.firstIndex(where: { $0.id == group.id }) {
            emojiGroups.remove(at: existing)
        }
        let safeIndex = max(0, min(index, emojiGroups.count))
        emojiGroups.insert(group, at: safeIndex)
        notifyGroupsChanged()
        return self
    }

    @discardableResult
    func removeEmojiGroup(id: String) -> EmojiConfig {
        emojiGroups.removeAll { $0.id == id }
        notifyGroupsChanged()
        return self
    }

    @discardableResult
    func clearEmojiGroups() -> EmojiConfig {
        emojiGroups.removeAll()
        notifyGroupsChanged()
        return self
    }

    private func notifyGroupsChanged() {
        NotificationCenter.default.post(name: EmojiConfig.groupsDidChangeNotification, object: nil)
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
            emojiGroup.id = EmojiConfig.builtInGroupID
            emojiGroup.isLittleEmoji = true
            emojiGroup.supportReaction = true
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

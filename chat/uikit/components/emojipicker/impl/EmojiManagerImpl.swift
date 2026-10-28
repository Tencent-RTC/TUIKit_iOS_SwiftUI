import Foundation
import UIKit

class EmojiManagerImpl {
    static let shared = EmojiManagerImpl()
    private init() {}
    private static let localizedEmojiRegex = try? NSRegularExpression(pattern: getEmojiRegex(), options: .caseInsensitive)
    private static let emojiLocalizationRegex = try? NSRegularExpression(pattern: getEmojiRegex(), options: [])
    private static let emojiCodeRegex = try? NSRegularExpression(pattern: "\\[TUIEmoji_[^\\]]+\\]", options: [])

    func createAttributedStringFromEmojiData(_ emoji: EmojiData) -> NSAttributedString {
        let emojiTextAttachment = EmojiTextAttachment()
        emojiTextAttachment.faceCellData = emoji
        emojiTextAttachment.emojiTag = emoji.name
        emojiTextAttachment.image = getStickerFromCache(emoji.path ?? "")
        emojiTextAttachment.emojiSize = defaultEmojiSize
        return NSAttributedString(attachment: emojiTextAttachment)
    }

    func createAttributedStringWithTextAndStyle(text: String, withFont textFont: UIFont, textColor: UIColor) -> NSMutableAttributedString {
        guard !text.isEmpty else {
            print("createAttributedStringWithTextAndStyle failed, current text is nil")
            return NSMutableAttributedString(string: "")
        }
        let attributeString = NSMutableAttributedString(string: text)
        let faceGroups = EmojiConfig.shared.emojiGroups
        guard !faceGroups.isEmpty else {
            attributeString.addAttribute(.font, value: textFont, range: NSRange(location: 0, length: attributeString.length))
            return attributeString
        }
        do {
            guard let regex = Self.localizedEmojiRegex else { return attributeString }
            let results = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
            let group = faceGroups[0]
            var imageArray = [(range: NSRange, imageStr: NSAttributedString)]()
            for match in results {
                let range = match.range
                let subStr = (text as NSString).substring(with: range)
                if let faces = group.emojis {
                    for face in faces {
                        if face.name == subStr || face.localizableName == subStr {
                            let emojiTextAttachment = EmojiTextAttachment()
                            emojiTextAttachment.faceCellData = face
                            emojiTextAttachment.emojiTag = face.name
                            if let path = face.path {
                                emojiTextAttachment.image = EmojiCache.shared.getImageFromCache(path)
                            }
                            emojiTextAttachment.emojiSize = defaultEmojiSize
                            let imageStr = NSAttributedString(attachment: emojiTextAttachment)
                            imageArray.append((range, imageStr))
                            break
                        }
                    }
                }
            }
            var locations = [(originRange: NSRange, originStr: NSAttributedString, currentStr: NSAttributedString)]()
            for item in imageArray.reversed() {
                let originRange = item.range
                let originStr = attributeString.attributedSubstring(from: originRange)
                let currentStr = item.imageStr
                locations.insert((originRange, originStr, currentStr), at: 0)
                attributeString.replaceCharacters(in: originRange, with: currentStr)
            }
            var offsetLocation = 0
            for location in locations {
                var currentRange = location.originRange
                currentRange.location += offsetLocation
                currentRange.length = location.currentStr.length
                offsetLocation += location.currentStr.length - location.originStr.length
            }
            attributeString.addAttribute(.font, value: textFont, range: NSRange(location: 0, length: attributeString.length))
            attributeString.addAttribute(.foregroundColor, value: textColor, range: NSRange(location: 0, length: attributeString.length))
        }
        return attributeString
    }

    func createAttributedStringFromEmojiCodes(from text: String) -> NSAttributedString {
        let regex = Self.emojiCodeRegex
        let nsString = text as NSString
        let matches = regex?.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length)) ?? []
        let attributedString = NSMutableAttributedString()
        var lastIndex = 0
        for match in matches {
            if match.range.location > lastIndex {
                let textRange = NSRange(location: lastIndex, length: match.range.location - lastIndex)
                let textString = nsString.substring(with: textRange)
                attributedString.append(NSAttributedString(string: textString))
            }
            let emojiCode = nsString.substring(with: match.range)
            if let faceGroup = EmojiConfig.shared.emojiGroups.first,
               let emojiData = faceGroup.emojis?.first(where: { $0.name == emojiCode }),
               let imagePath = emojiData.path,
               let image = EmojiCache.shared.getImageFromCache(imagePath)
            {
                let attachment = EmojiTextAttachment()
                attachment.image = image
                attachment.emojiTag = emojiCode
                attachment.faceCellData = emojiData
                attachment.emojiSize = defaultEmojiSize
                attachment.bounds = CGRect(x: 0, y: -4, width: 20, height: 20)
                let imageString = NSAttributedString(attachment: attachment)
                attributedString.append(imageString)
            } else {
                attributedString.append(NSAttributedString(string: emojiCode))
            }
            lastIndex = match.range.location + match.range.length
        }
        if lastIndex < nsString.length {
            let textRange = NSRange(location: lastIndex, length: nsString.length - lastIndex)
            let textString = nsString.substring(with: textRange)
            attributedString.append(NSAttributedString(string: textString))
        }
        return attributedString
    }

    func createStyledAttributedString(fromEmojiCodes text: String, font: UIFont, textColor: UIColor) -> NSAttributedString {
        let base = NSMutableAttributedString(attributedString: createAttributedStringFromEmojiCodes(from: text))
        let fullRange = NSRange(location: 0, length: base.length)
        let emojiSize = font.pointSize * 1.2
        base.enumerateAttribute(.attachment, in: fullRange, options: []) { value, range, _ in
            if let attachment = value as? NSTextAttachment {
                attachment.bounds = CGRect(x: 0, y: -emojiSize * 0.2, width: emojiSize, height: emojiSize)
            } else {
                base.addAttribute(.font, value: font, range: range)
                base.addAttribute(.foregroundColor, value: textColor, range: range)
            }
        }
        return base
    }

    func createLocalizedStringFromEmojiCodes(_ text: String) -> String {
        let regex = Self.emojiLocalizationRegex
        let nsString = text as NSString
        let matches = regex?.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length)) ?? []
        var result = text
        for match in matches.reversed() {
            let emojiCode = nsString.substring(with: match.range)
            if let faceGroup = EmojiConfig.shared.emojiGroups.first,
               let emojiData = faceGroup.emojis?.first(where: { $0.name == emojiCode }),
               let localizedName = emojiData.localizableName
            {
                result = (result as NSString).replacingCharacters(in: match.range, with: localizedName)
            }
        }
        return result
    }

    private func getStickerFromCache(_ path: String) -> UIImage {
        return EmojiCache.shared.getImageFromCache(path) ?? UIImage()
    }

    private static func getEmojiRegex() -> String {
        return "\\[[a-zA-Z0-9_\\u4e00-\\u9fa5]+\\]"
    }
}

extension EmojiManager {
    private static let kRecentEmojiKey = "recent_emoji_list"

    private static let chineseElementEmojiKeys: Set<String> = [
        "[TUIEmoji_Rich]", "[TUIEmoji_Bless]", "[TUIEmoji_Fortune]",
        "[TUIEmoji_Convinced]", "[TUIEmoji_Prohibit]", "[TUIEmoji_666]", "[TUIEmoji_857]"
    ]

    private var userDefaults: UserDefaults { UserDefaults.standard }

    private var maxRecentCount: Int { 8 }

    func getAllEmojis() -> [EmojiData] {
        return EmojiConfig.shared.emojiGroups.flatMap { $0.emojis ?? [] }
    }

    func pickerVisibleEmojis(in group: EmojiGroup?) -> [EmojiData] {
        guard let group = group else { return [] }
        let emojis = group.emojis ?? []
        guard !LanguageHelper.getCurrentLanguage().hasPrefix("zh") else { return emojis }
        return emojis.filter { !EmojiManager.chineseElementEmojiKeys.contains($0.name ?? "") }
    }

    func getReactionEmojis() -> [EmojiData] {
        return pickerVisibleEmojis(in: EmojiConfig.shared.emojiGroups.first)
    }

    func getPickerEmojis() -> [EmojiData] {
        return getReactionEmojis()
    }

    func reactionGroupID() -> String {
        return EmojiConfig.builtInGroupID
    }

    func getRecentEmojiDataList(groupID: String = EmojiConfig.builtInGroupID) -> [EmojiData] {
        let visible = pickerVisibleEmojis(in: EmojiConfig.shared.emojiGroups.first)
        return getRecentEmojis(groupID: groupID).compactMap { id in
            visible.first(where: { $0.name == id })
        }
    }

    func getRecentEmojis(groupID: String = EmojiConfig.builtInGroupID) -> [String] {
        return userDefaults.stringArray(forKey: EmojiManager.recentKey(for: groupID)) ?? []
    }

    func addRecentEmoji(_ emoji: EmojiData, groupID: String = EmojiConfig.builtInGroupID) {
        guard let id = emoji.name else { return }
        var list = getRecentEmojis(groupID: groupID)
        list.removeAll { $0 == id }
        list.insert(id, at: 0)
        if list.count > maxRecentCount {
            list = Array(list.prefix(maxRecentCount))
        }
        userDefaults.set(list, forKey: EmojiManager.recentKey(for: groupID))
    }

    private static func recentKey(for groupID: String) -> String {
        if groupID == EmojiConfig.builtInGroupID { return kRecentEmojiKey }
        return "\(kRecentEmojiKey)_\(groupID)"
    }
}

public class EmojiData: NSObject {
    public var name: String?
    public var localizableName: String?
    public var path: String?
}

public class EmojiTextAttachment: NSTextAttachment {
    public var faceCellData: EmojiData?
    public var emojiTag: String?
    public var emojiSize: CGSize = .zero
    override public func attachmentBounds(for textContainer: NSTextContainer?, proposedLineFragment lineFrag: CGRect, glyphPosition position: CGPoint, characterIndex charIndex: Int) -> CGRect {
        return CGRect(x: 0, y: -0.4 * lineFrag.size.height, width: defaultEmojiSize.width, height: defaultEmojiSize.height)
    }
}

public class EmojiManager {
    public static let shared = EmojiManager()
    private init() {}
    public func createAttributedStringFromEmojiData(_ emoji: EmojiData) -> NSAttributedString {
        let emojiTextAttachment = EmojiTextAttachment()
        emojiTextAttachment.faceCellData = emoji
        emojiTextAttachment.emojiTag = emoji.name
        emojiTextAttachment.image = getStickerFromCache(emoji.path ?? "")
        emojiTextAttachment.emojiSize = defaultEmojiSize
        return NSAttributedString(attachment: emojiTextAttachment)
    }

    // "abc[TUIEmoji_smile]def" -> "abc<The Image of [TUIEmoji_Smile]>def" in specified style
    public func createAttributedStringWithTextAndStyle(text: String, withFont textFont: UIFont, textColor: UIColor) -> NSMutableAttributedString {
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
        let regexEmoji = EmojiManager.getEmojiRegex()
        do {
            let regex = try NSRegularExpression(pattern: regexEmoji, options: .caseInsensitive)
            let results = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.count))
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
        } catch {
            print("Regex error: \(error.localizedDescription)")
        }
        return attributeString
    }

    // "abc[TUIEmoji_smile]def" -> "abc<The Image of [TUIEmoji_Smile]>def"
    public func createAttributedStringFromEmojiCodes(from text: String) -> NSAttributedString {
        let pattern = "\\[TUIEmoji_[^\\]]+\\]"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
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
                let attachment = NSTextAttachment()
                attachment.image = image
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

    // "abc[TUIEmoji_Smile]def" -> "abc[smile]def" in English.
    public func createLocalizedStringFromEmojiCodes(_ text: String) -> String {
        let regex = try? NSRegularExpression(pattern: EmojiManager.getEmojiRegex(), options: [])
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
    private var userDefaults: UserDefaults { UserDefaults.standard }
    private var maxRecentCount: Int { 8 }
    func getRecentEmojis() -> [String] {
        userDefaults.stringArray(forKey: EmojiManager.kRecentEmojiKey) ?? []
    }

    func addRecentEmoji(_ emoji: EmojiData) {
        guard let id = emoji.name else { return }
        var list = getRecentEmojis()
        list.removeAll { $0 == id }
        list.insert(id, at: 0)
        if list.count > maxRecentCount {
            list = Array(list.prefix(maxRecentCount))
        }
        userDefaults.set(list, forKey: EmojiManager.kRecentEmojiKey)
    }
}

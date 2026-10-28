import Foundation
import UIKit

public class EmojiData: NSObject {
    public var name: String?
    public var localizableName: String?
    public var path: String?
}

public class EmojiGroup: NSObject {
    public var id: String = ""
    public var isLittleEmoji: Bool = true
    public var supportReaction: Bool = true
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

public class EmojiTextAttachment: NSTextAttachment {
    public var faceCellData: EmojiData?
    public var emojiTag: String?
    public var emojiSize: CGSize = .zero
    override public func attachmentBounds(for textContainer: NSTextContainer?, proposedLineFragment lineFrag: CGRect, glyphPosition position: CGPoint, characterIndex charIndex: Int) -> CGRect {
        return CGRect(x: 0, y: -0.4 * lineFrag.size.height, width: defaultEmojiSize.width, height: defaultEmojiSize.height)
    }
}

import Foundation
import UIKit

public class EmojiManager {
    public static let shared = EmojiManager()
    private let implementation = EmojiManagerImpl.shared

    private init() {}

    public func createAttributedStringFromEmojiData(_ emoji: EmojiData) -> NSAttributedString {
        implementation.createAttributedStringFromEmojiData(emoji)
    }

    public func createAttributedStringWithTextAndStyle(text: String, withFont textFont: UIFont, textColor: UIColor) -> NSMutableAttributedString {
        implementation.createAttributedStringWithTextAndStyle(text: text, withFont: textFont, textColor: textColor)
    }

    public func createAttributedStringFromEmojiCodes(from text: String) -> NSAttributedString {
        implementation.createAttributedStringFromEmojiCodes(from: text)
    }

    public func createStyledAttributedString(fromEmojiCodes text: String, font: UIFont, textColor: UIColor) -> NSAttributedString {
        implementation.createStyledAttributedString(fromEmojiCodes: text, font: font, textColor: textColor)
    }

    public func createLocalizedStringFromEmojiCodes(_ text: String) -> String {
        implementation.createLocalizedStringFromEmojiCodes(text)
    }
}

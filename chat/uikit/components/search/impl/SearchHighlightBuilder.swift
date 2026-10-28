import UIKit

enum SearchHighlightBuilder {
    static func attributedTextWithEmoji(text: String,
                                        keyword: String,
                                        fontSize: CGFloat,
                                        normalColor: UIColor,
                                        highlightColor: UIColor) -> NSAttributedString {
        let font = UIFont.systemFont(ofSize: fontSize)
        let base = NSMutableAttributedString(
            attributedString: EmojiManager.shared.createStyledAttributedString(
                fromEmojiCodes: text, font: font, textColor: normalColor
            )
        )
        let lowercasedText = base.string.lowercased()
        let lowercasedKeyword = keyword.lowercased()
        guard !lowercasedKeyword.isEmpty, lowercasedText.contains(lowercasedKeyword) else {
            return base
        }
        let nsText = lowercasedText as NSString
        var searchRange = NSRange(location: 0, length: nsText.length)
        while searchRange.location < nsText.length {
            let foundRange = nsText.range(of: lowercasedKeyword, options: [], range: searchRange)
            if foundRange.location == NSNotFound {
                break
            }
            base.addAttributes([.foregroundColor: highlightColor], range: foundRange)
            let nextLocation = foundRange.location + foundRange.length
            searchRange = NSRange(location: nextLocation, length: nsText.length - nextLocation)
        }
        return base
    }
}

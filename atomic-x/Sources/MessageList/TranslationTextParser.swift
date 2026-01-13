import AtomicXCore
import Foundation

/// Parser for text translation that handles emoji and @ mentions.
/// This implementation mirrors UIKit's TUITranslationDataProvider and String+TUIEmoji logic.
class TranslationTextParser {
    static let kSplitStringResultKey = "result"
    static let kSplitStringTextKey = "text"
    static let kSplitStringTextIndexKey = "textIndex"
    
    // MARK: - Public API
    
    /// Parse text message and return components for translation.
    /// - Parameters:
    ///   - text: The original text to parse
    ///   - atUserNames: List of @ user names (without @ prefix)
    /// - Returns: Dictionary with "result", "text", and "textIndex" keys
    static func splitTextByEmojiAndAtUsers(_ text: String, atUserNames: [String]?) -> [String: Any]? {
        guard !text.isEmpty else { return nil }
        var result = [String]()
        
        // Build @user strings with @ prefix and trailing space
        var atUsers = [String]()
        atUserNames?.forEach { user in
            let atUser = "@\(user) "
            atUsers.append(atUser)
        }
        
        // Find @user ranges in string
        let atUserRanges = rangeOfAtUsers(atUsers, in: text)
        
        // Split text using @user ranges
        guard let splitResult = splitArrayWithRanges(atUserRanges, in: text),
              let splitArrayByAtUser = splitResult.first as? [String],
              let atUserIndexArray = splitResult.last as? [Int]
        else {
            return nil
        }
        let atUserIndex: Set<Int> = Set(atUserIndexArray)
        
        // Iterate split array to match emoji in non-@ parts
        var k = -1
        var textIndexArray = [Int]()
        
        for (i, str) in splitArrayByAtUser.enumerated() {
            if atUserIndex.contains(i) {
                // str is @user info, keep as-is
                result.append(str)
                k += 1
            } else {
                // str is not @user info, parse emoji
                let emojiRanges = matchTextByEmoji(str)
                if let emojiSplitResult = splitArrayWithRanges(emojiRanges, in: str),
                   let splitArrayByEmoji = emojiSplitResult.first as? [String],
                   let emojiIndex = emojiSplitResult.last as? [Int]
                {
                    for j in 0 ..< splitArrayByEmoji.count {
                        let tmp = splitArrayByEmoji[j]
                        result.append(tmp)
                        k += 1
                        if !emojiIndex.contains(j) {
                            // This is text that needs translation
                            textIndexArray.append(k)
                        }
                    }
                }
            }
        }
        
        // Extract text array from result using indices
        var textArray = [String]()
        for n in textIndexArray {
            if n < result.count {
                textArray.append(result[n])
            }
        }
        
        return [
            kSplitStringResultKey: result,
            kSplitStringTextKey: textArray,
            kSplitStringTextIndexKey: textIndexArray
        ]
    }
    
    /// Reconstruct translated text by replacing text segments with translations.
    /// - Parameters:
    ///   - array: The result array from splitTextByEmojiAndAtUsers
    ///   - indexArray: The textIndex array from splitTextByEmojiAndAtUsers
    ///   - replaceDict: Dictionary mapping original text to translated text
    /// - Returns: Reconstructed string with translations
    static func replacedStringWithArray(_ array: [String], index indexArray: [Int], replaceDict: [String: String]?) -> String? {
        guard let replaceDict = replaceDict else { return nil }
        var mutableArray = array
        
        for value in indexArray {
            if value < 0 || value >= mutableArray.count {
                continue
            }
            if let replacement = replaceDict[mutableArray[value]] {
                mutableArray[value] = replacement
            }
        }
        
        return mutableArray.joined()
    }
    
    // MARK: - @ User Handling
    
    /// Get @ user names from message's atUserList.
    /// - Parameters:
    ///   - messageInfo: The MessageInfo
    ///   - completion: Callback with user names array
    static func getAtUserNames(from messageInfo: MessageInfo?, completion: @escaping ([String]?) -> Void) {
        guard let messageInfo = messageInfo,
              !messageInfo.atUserList.isEmpty
        else {
            completion(nil)
            return
        }
        
        let atUserIDs = messageInfo.atUserList
        
        // Separate @All from regular users
        var regularUserIDs = [String]()
        var atAllIndexes = IndexSet()
        
        for (i, userID) in atUserIDs.enumerated() {
            if userID == MentionInfo.atAllUserID {
                atAllIndexes.insert(i)
            } else {
                regularUserIDs.append(userID)
            }
        }
        
        // If only @All
        if regularUserIDs.isEmpty {
            let atAllNames = Array(repeating: LocalizedChatString("All"), count: atAllIndexes.count)
            completion(atAllNames)
            return
        }
        
        // Fetch user info using C2CSettingStore
        var names = [String](repeating: "", count: regularUserIDs.count)
        let group = DispatchGroup()
        
        for (index, userID) in regularUserIDs.enumerated() {
            group.enter()
            let settingStore = C2CSettingStore.create(userID: userID)
            settingStore.fetchUserInfo(completion: { result in
                switch result {
                case .success:
                    let nickname = settingStore.state.value.nickname
                    names[index] = nickname.isEmpty ? userID : nickname
                case .failure:
                    names[index] = userID
                }
                group.leave()
            })
        }
        
        group.notify(queue: .main) {
            // Restore @All at original positions
            var finalNames = names
            for idx in atAllIndexes {
                if idx <= finalNames.count {
                    finalNames.insert(LocalizedChatString("All"), at: idx)
                }
            }
            completion(finalNames)
        }
    }
    
    // MARK: - Private Helpers
    
    /// Find ranges of @user strings in text.
    private static func rangeOfAtUsers(_ atUsers: [String], in string: String) -> [NSValue] {
        // Find all '@' positions
        var atIndex = IndexSet()
        for (i, char) in string.enumerated() {
            if char == "@" {
                atIndex.insert(i)
            }
        }
        
        var result = [NSValue]()
        for user in atUsers {
            for idx in atIndex {
                if string.count >= user.count, idx <= string.count - user.count {
                    let range = NSRange(location: idx, length: user.count)
                    if (string as NSString).substring(with: range) == user {
                        result.append(NSValue(range: range))
                        atIndex.remove(idx)
                    }
                }
            }
        }
        return result
    }
    
    /// Split string into substrings by given ranges.
    /// Returns [result array, indexes of special elements in result].
    private static func splitArrayWithRanges(_ ranges: [NSValue], in string: String) -> [Any]? {
        guard !ranges.isEmpty else { return [[string], [Int]()] }
        guard !string.isEmpty else { return nil }
        
        let sortedRanges = ranges.sorted { $0.rangeValue.location < $1.rangeValue.location }
        
        var result = [String]()
        var indexes = [Int]()
        var prev = 0
        var j = -1
        var i = 0
        
        while i < sortedRanges.count {
            let cur = sortedRanges[i].rangeValue
            
            // Add text before current range
            if cur.location > prev {
                let str = (string as NSString).substring(with: NSRange(location: prev, length: cur.location - prev))
                result.append(str)
                j += 1
            }
            
            // Add content within current range (special element)
            let str = (string as NSString).substring(with: cur)
            result.append(str)
            j += 1
            indexes.append(j)
            
            prev = cur.location + cur.length
            
            // Handle text after last range
            if i == sortedRanges.count - 1, prev < string.utf16.count {
                let last = (string as NSString).substring(with: NSRange(location: prev, length: string.utf16.count - prev))
                result.append(last)
            }
            
            i += 1
        }
        
        return [result, indexes]
    }
    
    /// Match emoji in text (both TUIKit custom and Unicode emoji).
    private static func matchTextByEmoji(_ text: String) -> [NSValue] {
        var result = [NSValue]()
        
        // TUIKit custom emoji: \[[a-zA-Z0-9_\u4e00-\u9fa5]+\]
        let regexOfCustomEmoji = getRegexEmoji()
        do {
            let regex = try NSRegularExpression(pattern: regexOfCustomEmoji, options: .caseInsensitive)
            let matchResult = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.count))
            
            for match in matchResult {
                let substring = (text as NSString).substring(with: match.range)
                // Validate against registered emoji
                if isRegisteredEmoji(substring) {
                    result.append(NSValue(range: match.range))
                }
            }
        } catch {
            print(">>>>> TUIKit Emoji Regex error: \(error.localizedDescription)")
        }
        
        // Unicode emoji
        let regexOfUnicodeEmoji = unicodeEmojiReString()
        do {
            let regex = try NSRegularExpression(pattern: regexOfUnicodeEmoji, options: .caseInsensitive)
            let matchResult = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.count))
            for match in matchResult {
                result.append(NSValue(range: match.range))
            }
        } catch {
            print(">>>>> Unicode Emoji Regex error: \(error.localizedDescription)")
        }
        
        return result
    }
    
    /// Check if a string is a registered TUIKit emoji.
    private static func isRegisteredEmoji(_ name: String) -> Bool {
        // Check against EmojiManager's registered emoji
        // For now, assume all matches are valid emoji
        // TODO: Integrate with EmojiManager to validate
        return true
    }
    
    /// Regex pattern for TUIKit custom emoji.
    static func getRegexEmoji() -> String {
        return "\\[[a-zA-Z0-9_\\u4e00-\\u9fa5]+\\]"
    }
    
    /// Regex pattern for Unicode emoji.
    static func unicodeEmojiReString() -> String {
        let ri = "[\u{0001F1E6}-\u{0001F1FF}]"
        
        let unsupport = String(format: "%C|%C|[%C-%C]|", 0x0023, 0x002a, 0x0030, 0x0039)
        let support = "\u{000000A9}|\u{000000AE}|\u{203C}|\u{2049}|\u{2122}|\u{2139}|[\u{2194}-\u{2199}]|[\u{21A9}-\u{21AA}]|[\u{231A}-\u{231B}]|\u{2328}|\u{23CF}|[\u{23E9}-\u{23EF}]|[\u{23F0}-\u{23F3}]|[\u{23F8}-\u{23FA}]|\u{24C2}|[\u{25AA}-\u{25AB}]|\u{25B6}|\u{25C0}|[\u{25FB}-\u{25FE}]|[\u{2600}-\u{2604}]|\u{260E}|\u{2611}|[\u{2614}-\u{2615}]|\u{2618}|\u{261D}|\u{2620}|[\u{2622}-\u{2623}]|\u{2626}|\u{262A}|[\u{262E}-\u{262F}]|[\u{2638}-\u{263A}]|\u{2640}|\u{2642}|[\u{2648}-\u{264F}]|[\u{2650}-\u{2653}]|\u{265F}|\u{2660}|\u{2663}|[\u{2665}-\u{2666}]|\u{2668}|\u{267B}|[\u{267E}-\u{267F}]|[\u{2692}-\u{2697}]|\u{2699}|[\u{269B}-\u{269C}]|[\u{26A0}-\u{26A1}]|\u{26A7}|[\u{26AA}-\u{26AB}]|[\u{26B0}-\u{26B1}]|[\u{26BD}-\u{26BE}]|[\u{26C4}-\u{26C5}]|\u{26C8}|[\u{26CE}-\u{26CF}]|\u{26D1}|[\u{26D3}-\u{26D4}]|[\u{26E9}-\u{26EA}]|[\u{26F0}-\u{26F5}]|[\u{26F7}-\u{26FA}]|\u{26FD}|\u{2702}|\u{2705}|[\u{2708}-\u{270D}]|\u{270F}|\u{2712}|\u{2714}|\u{2716}|\u{271D}|\u{2721}|\u{2728}|[\u{2733}-\u{2734}]|\u{2744}|\u{2747}|\u{274C}|\u{274E}|[\u{2753}-\u{2755}]|\u{2757}|[\u{2763}-\u{2764}]|[\u{2795}-\u{2797}]|\u{27A1}|\u{27B0}|\u{27BF}|[\u{2934}-\u{2935}]|[\u{2B05}-\u{2B07}]|[\u{2B1B}-\u{2B1C}]|\u{2B50}|\u{2B55}|\u{3030}|\u{303D}|\u{3297}|\u{3299}|\u{1F004}|\u{1F0CF}|[\u{1F170}-\u{1F171}]|[\u{1F17E}-\u{1F17F}]|\u{1F18E}|[\u{1F191}-\u{1F19A}]|[\u{1F1E6}-\u{1F1FF}]|[\u{1F201}-\u{1F202}]|\u{1F21A}|\u{1F22F}|[\u{1F232}-\u{1F23A}]|[\u{1F250}-\u{1F251}]|[\u{1F300}-\u{1F30F}]|[\u{1F310}-\u{1F31F}]|[\u{1F320}-\u{1F321}]|[\u{1F324}-\u{1F32F}]|[\u{1F330}-\u{1F33F}]|[\u{1F340}-\u{1F34F}]|[\u{1F350}-\u{1F35F}]|[\u{1F360}-\u{1F36F}]|[\u{1F370}-\u{1F37F}]|[\u{1F380}-\u{1F38F}]|[\u{1F390}-\u{1F393}]|[\u{1F396}-\u{1F397}]|[\u{1F399}-\u{1F39B}]|[\u{1F39E}-\u{1F39F}]|[\u{1F3A0}-\u{1F3AF}]|[\u{1F3B0}-\u{1F3BF}]|[\u{1F3C0}-\u{1F3CF}]|[\u{1F3D0}-\u{1F3DF}]|[\u{1F3E0}-\u{1F3EF}]|\u{1F3F0}|[\u{1F3F3}-\u{1F3F5}]|[\u{1F3F7}-\u{1F3FF}]|[\u{1F400}-\u{1F40F}]|[\u{1F410}-\u{1F41F}]|[\u{1F420}-\u{1F42F}]|[\u{1F430}-\u{1F43F}]|[\u{1F440}-\u{1F44F}]|[\u{1F450}-\u{1F45F}]|[\u{1F460}-\u{1F46F}]|[\u{1F470}-\u{1F47F}]|[\u{1F480}-\u{1F48F}]|[\u{1F490}-\u{1F49F}]|[\u{1F4A0}-\u{1F4AF}]|[\u{1F4B0}-\u{1F4BF}]|[\u{1F4C0}-\u{1F4CF}]|[\u{1F4D0}-\u{1F4DF}]|[\u{1F4E0}-\u{1F4EF}]|[\u{1F4F0}-\u{1F4FF}]|[\u{1F500}-\u{1F50F}]|[\u{1F510}-\u{1F51F}]|[\u{1F520}-\u{1F52F}]|[\u{1F530}-\u{1F53D}]|[\u{1F549}-\u{1F54E}]|[\u{1F550}-\u{1F55F}]|[\u{1F560}-\u{1F567}]|\u{1F56F}|\u{1F570}|[\u{1F573}-\u{1F57A}]|\u{1F587}|[\u{1F58A}-\u{1F58D}]|\u{1F590}|[\u{1F595}-\u{1F596}]|[\u{1F5A4}-\u{1F5A5}]|\u{1F5A8}|[\u{1F5B1}-\u{1F5B2}]|\u{1F5BC}|[\u{1F5C2}-\u{1F5C4}]|[\u{1F5D1}-\u{1F5D3}]|[\u{1F5DC}-\u{1F5DE}]|\u{1F5E1}|\u{1F5E3}|\u{1F5E8}|\u{1F5EF}|\u{1F5F3}|[\u{1F5FA}-\u{1F5FF}]|[\u{1F600}-\u{1F60F}]|[\u{1F610}-\u{1F61F}]|[\u{1F620}-\u{1F62F}]|[\u{1F630}-\u{1F63F}]|[\u{1F640}-\u{1F64F}]|[\u{1F650}-\u{1F65F}]|[\u{1F660}-\u{1F66F}]|[\u{1F670}-\u{1F67F}]|[\u{1F680}-\u{1F68F}]|[\u{1F690}-\u{1F69F}]|[\u{1F6A0}-\u{1F6AF}]|[\u{1F6B0}-\u{1F6BF}]|[\u{1F6C0}-\u{1F6C5}]|[\u{1F6CB}-\u{1F6CF}]|[\u{1F6D0}-\u{1F6D2}]|[\u{1F6D5}-\u{1F6D7}]|[\u{1F6DD}-\u{1F6DF}]|[\u{1F6E0}-\u{1F6E5}]|\u{1F6E9}|[\u{1F6EB}-\u{1F6EC}]|\u{1F6F0}|[\u{1F6F3}-\u{1F6FC}]|[\u{1F7E0}-\u{1F7EB}]|\u{1F7F0}|[\u{1F90C}-\u{1F90F}]|[\u{1F910}-\u{1F91F}]|[\u{1F920}-\u{1F92F}]|[\u{1F930}-\u{1F93A}]|[\u{1F93C}-\u{1F93F}]|[\u{1F940}-\u{1F945}]|[\u{1F947}-\u{1F94C}]|[\u{1F94D}-\u{1F94F}]|[\u{1F950}-\u{1F95F}]|[\u{1F960}-\u{1F96F}]|[\u{1F970}-\u{1F97F}]|[\u{1F980}-\u{1F98F}]|[\u{1F990}-\u{1F99F}]|[\u{1F9A0}-\u{1F9AF}]|[\u{1F9B0}-\u{1F9BF}]|[\u{1F9C0}-\u{1F9CF}]|[\u{1F9D0}-\u{1F9DF}]|[\u{1F9E0}-\u{1F9EF}]|[\u{1F9F0}-\u{1F9FF}]|[\u{1FA70}-\u{1FA74}]|[\u{1FA78}-\u{1FA7C}]|[\u{1FA80}-\u{1FA86}]|[\u{1FA90}-\u{1FA9F}]|[\u{1FAA0}-\u{1FAAC}]|[\u{1FAB0}-\u{1FABA}]|[\u{1FAC0}-\u{1FAC5}]|[\u{1FAD0}-\u{1FAD9}]|[\u{1FAE0}-\u{1FAE7}]|[\u{1FAF0}-\u{1FAF6}]"
        let emoji = "[\(unsupport)\(support)]"
        
        let eMod = "[\u{0001F3FB}-\u{0001F3FF}]"
        let variationSelector = "\u{FE0F}"
        let keycap = "\u{20E3}"
        let tags = "[\u{000E0020}-\u{000E007E}]"
        let termTag = "\u{000E007F}"
        let zwj = "\u{200D}"
        
        let riSequence = "[\(ri)][\(ri)]"
        let element = "[\(emoji)]([\(eMod)]|\(variationSelector)\(keycap)?|[\(tags)]+\(termTag))?"
        
        let regexEmoji = "\(riSequence)|\(element)(\(zwj)(\(riSequence)|\(element)))*"
        return regexEmoji
    }
}

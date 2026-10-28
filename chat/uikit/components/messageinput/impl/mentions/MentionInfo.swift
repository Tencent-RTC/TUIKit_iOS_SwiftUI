import Foundation

internal struct MentionInfo {
    internal let userID: String
    
    internal let displayName: String
    
    internal var startIndex: Int
    
    internal let length: Int
    
    internal var isAtAll: Bool {
        return userID == MessageInputView.mentionAllUserID
    }
    
    internal var endIndex: Int {
        return startIndex + length
    }
    
    internal var mentionText: String {
        return "@\(displayName) "
    }
    
    internal init(userID: String, displayName: String, startIndex: Int, length: Int) {
        self.userID = userID
        self.displayName = displayName
        self.startIndex = startIndex
        self.length = length
    }
    
    internal static func create(userID: String, displayName: String, atPosition: Int) -> MentionInfo {
        let mentionText = "@\(displayName) "
        return MentionInfo(
            userID: userID,
            displayName: displayName,
            startIndex: atPosition,
            length: mentionText.count
        )
    }
}

import Foundation

/// Data model for @ mention information
public struct MentionInfo {
    /// Special user ID for @All
    /// This constant is defined by IM SDK
    public static let atAllUserID = "__kImSDK_MesssageAtALL__"
    
    /// User ID of the mentioned user
    public let userID: String
    
    /// Display name shown in the input (e.g., "John" for "@John ")
    public let displayName: String
    
    /// Start index of the mention in the text (position of "@")
    public var startIndex: Int
    
    /// Length of the mention text including "@" and trailing space
    public let length: Int
    
    /// Whether this mention is @All
    public var isAtAll: Bool {
        return userID == Self.atAllUserID
    }
    
    /// End index of the mention (startIndex + length)
    public var endIndex: Int {
        return startIndex + length
    }
    
    /// The full mention text (e.g., "@John ")
    public var mentionText: String {
        return "@\(displayName) "
    }
    
    public init(userID: String, displayName: String, startIndex: Int, length: Int) {
        self.userID = userID
        self.displayName = displayName
        self.startIndex = startIndex
        self.length = length
    }
    
    /// Create a MentionInfo from a selected member
    /// - Parameters:
    ///   - userID: User ID
    ///   - displayName: Display name
    ///   - atPosition: Position where "@" was typed
    /// - Returns: MentionInfo with calculated length
    public static func create(userID: String, displayName: String, atPosition: Int) -> MentionInfo {
        let mentionText = "@\(displayName) "
        return MentionInfo(
            userID: userID,
            displayName: displayName,
            startIndex: atPosition,
            length: mentionText.count
        )
    }
}

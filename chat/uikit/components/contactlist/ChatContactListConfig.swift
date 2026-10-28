import AtomicXCore
import Combine
import Foundation
import SwiftUI

public typealias ContactListItemCustomizer = (CustomEditor<ContactCustomItem>) -> Void

public struct ContactCustomItem: CustomItem {
    public var ID: String
    public let title: String
    public let iconName: String
    public let badgeCount: AnyPublisher<Int, Never>?
    public let onClick: () -> Void

    public init(ID: String,
                title: String,
                iconName: String,
                badgeCount: AnyPublisher<Int, Never>? = nil,
                onClick: @escaping () -> Void) {
        self.ID = ID
        self.title = title
        self.iconName = iconName
        self.badgeCount = badgeCount
        self.onClick = onClick
    }
}

public enum ContactListItemIDs {
    public static let newContacts = "contactList.newContacts"
    public static let groupApplications = "contactList.groupApplications"
    public static let myGroups = "contactList.myGroups"
    public static let blacklist = "contactList.blacklist"
}

public struct ChatContactListConfig {
    public var userShowNewContacts: Bool? = nil
    public var userShowGroupApplications: Bool? = nil
    public var userShowMyGroups: Bool? = nil
    public var userShowBlacklist: Bool? = nil
    public var userShowSearchBar: Bool? = nil
    public var userItemCustomizer: ContactListItemCustomizer? = nil
}

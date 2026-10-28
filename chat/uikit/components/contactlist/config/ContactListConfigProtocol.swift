import AtomicXCore
import Combine
import Foundation

internal protocol ContactListConfigProtocol {
    var showNewContacts: Bool { get }
    var showGroupApplications: Bool { get }
    var showMyGroups: Bool { get }
    var showBlacklist: Bool { get }
    var showSearchBar: Bool { get }
    var itemCustomizer: ContactListItemCustomizer? { get }
}

internal extension ContactListConfigProtocol {
    var showNewContacts: Bool { true }
    var showGroupApplications: Bool { true }
    var showMyGroups: Bool { true }
    var showBlacklist: Bool { true }
    var showSearchBar: Bool { true }
    var itemCustomizer: ContactListItemCustomizer? { nil }
}

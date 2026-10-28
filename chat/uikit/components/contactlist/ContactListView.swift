import AtomicXCore
import Combine
import SwiftUI

public struct ContactListView: View {
    private let implementation: ContactListImpl

    public init(
        config: ChatContactListConfig? = nil,
        onContactClick: ((AZOrderedListItem) -> Void)? = nil,
        onGroupClick: ((AZOrderedListItem) -> Void)? = nil
    ) {
        implementation = ContactListImpl(
            config: config ?? ChatContactListConfig(),
            onContactClick: onContactClick,
            onGroupClick: onGroupClick
        )
    }

    public var body: some View { implementation }
}

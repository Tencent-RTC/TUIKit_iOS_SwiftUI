import SwiftUI

public struct ContactsPage: View {
    private let implementation: ContactsPageImpl

    public init(
        config: ChatContactListConfig? = nil,
        onContactClick: ((AZOrderedListItem) -> Void)? = nil,
        onGroupClick: ((AZOrderedListItem) -> Void)? = nil
    ) {
        implementation = ContactsPageImpl(
            config: config ?? ChatContactListConfig(),
            onContactClick: onContactClick,
            onGroupClick: onGroupClick
        )
    }

    public var body: some View { implementation }
}

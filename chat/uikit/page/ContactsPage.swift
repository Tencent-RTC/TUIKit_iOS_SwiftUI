import AtomicXCore
import SwiftUI

public struct ContactsPage: View {
    private let implementation: ContactsPageImpl

    public init(
        config: ContactListConfig? = nil,
        onContactClick: ((ContactInfo) -> Void)? = nil,
        onGroupClick: ((GroupInfo) -> Void)? = nil
    ) {
        implementation = ContactsPageImpl(
            config: config ?? ContactListConfig(),
            onContactClick: onContactClick,
            onGroupClick: onGroupClick
        )
    }

    public var body: some View { implementation }
}

import AtomicXCore
import Combine
import SwiftUI

public struct ContactListView: View {
    private let implementation: ContactListImpl

    public init(
        config: ContactListConfig? = nil,
        onContactClick: ((ContactInfo) -> Void)? = nil,
        onGroupClick: ((GroupInfo) -> Void)? = nil
    ) {
        implementation = ContactListImpl(
            config: config ?? ContactListConfig(),
            onContactClick: onContactClick,
            onGroupClick: onGroupClick
        )
    }

    public var body: some View { implementation }
}

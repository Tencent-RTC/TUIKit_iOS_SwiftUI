import AtomicXCore
import Combine
import SwiftUI

internal struct GroupListView: View {
    private let implementation: GroupListViewImpl

    internal init(
        onGroupClick: ((AZOrderedListItem) -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        implementation = GroupListViewImpl(
            onGroupClick: onGroupClick,
            onDismiss: onDismiss
        )
    }

    internal var body: some View { implementation }
}

import AtomicXCore
import Combine
import SwiftUI

internal struct BlackListView: View {
    private let implementation: BlackListViewImpl

    internal init(
        onContactClick: ((AZOrderedListItem) -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        implementation = BlackListViewImpl(
            onContactClick: onContactClick,
            onDismiss: onDismiss
        )
    }

    internal var body: some View { implementation }
}

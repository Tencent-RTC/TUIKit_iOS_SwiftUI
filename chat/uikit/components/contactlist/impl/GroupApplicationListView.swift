import AtomicXCore
import Combine
import SwiftUI

internal struct GroupApplicationListView: View {
    private let implementation: GroupApplicationListViewImpl

    internal init(onDismiss: (() -> Void)? = nil) {
        implementation = GroupApplicationListViewImpl(
            onDismiss: onDismiss
        )
    }

    internal var body: some View { implementation }
}

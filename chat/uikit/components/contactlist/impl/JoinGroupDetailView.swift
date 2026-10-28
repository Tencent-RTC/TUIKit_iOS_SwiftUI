import AtomicXCore
import SwiftUI

internal struct JoinGroupDetailView: View {
    private let implementation: JoinGroupDetailViewImpl

    internal init(groupInfo: GroupInfo, dismissAll: @escaping () -> Void) {
        implementation = JoinGroupDetailViewImpl(
            groupInfo: groupInfo,
            dismissAll: dismissAll
        )
    }

    internal var body: some View { implementation }
}

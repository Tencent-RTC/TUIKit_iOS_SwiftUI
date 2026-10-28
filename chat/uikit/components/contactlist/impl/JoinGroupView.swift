import AtomicXCore
import SwiftUI

internal struct JoinGroupView: View {
    private let implementation: JoinGroupViewImpl

    internal init(
        onEnterGroupChat: ((GroupInfo) -> Void)? = nil
    ) {
        implementation = JoinGroupViewImpl(
            onEnterGroupChat: onEnterGroupChat
        )
    }

    internal var body: some View { implementation }
}

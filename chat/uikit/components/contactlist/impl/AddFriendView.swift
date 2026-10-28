import AtomicXCore
import SwiftUI

internal struct AddFriendView: View {
    private let implementation: AddFriendViewImpl

    internal init() {
        implementation = AddFriendViewImpl()
    }

    internal var body: some View { implementation }
}

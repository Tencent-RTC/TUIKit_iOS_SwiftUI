import AtomicXCore
import SwiftUI

struct MessageReadReceiptView: View {
    private let implementation: MessageReadReceiptViewImpl

    init(
        messageActionStore: MessageActionStore,
        message: MessageInfo,
        embedInNavigationView: Bool = false,
        onUserClick: ((String) -> Void)? = nil
    ) {
        implementation = MessageReadReceiptViewImpl(
            messageActionStore: messageActionStore,
            message: message,
            embedInNavigationView: embedInNavigationView,
            onUserClick: onUserClick
        )
    }

    var body: some View { implementation }
}

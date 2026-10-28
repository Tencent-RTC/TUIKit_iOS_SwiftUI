import AtomicXCore
import SwiftUI

internal struct AddContactDetailView: View {
    private let implementation: AddContactDetailViewImpl

    internal init(userID: String, contactInfo: ContactInfo? = nil, onFinished: (() -> Void)? = nil) {
        implementation = AddContactDetailViewImpl(
            userID: userID,
            contactInfo: contactInfo,
            onFinished: onFinished
        )
    }

    internal var body: some View { implementation }
}

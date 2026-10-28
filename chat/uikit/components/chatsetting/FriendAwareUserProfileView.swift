import AtomicXCore
import SwiftUI

public struct FriendAwareUserProfileView<FriendContent: View>: View {
    private let implementation: FriendAwareUserProfileViewImpl<FriendContent>

    public init(userID: String, @ViewBuilder friendContent: @escaping (String) -> FriendContent) {
        implementation = FriendAwareUserProfileViewImpl(
            userID: userID,
            friendContent: friendContent
        )
    }

    public var body: some View { implementation }
}

public extension FriendAwareUserProfileView where FriendContent == C2CChatSettingView {
    init(userID: String) {
        self.init(userID: userID) { C2CChatSettingView(userID: $0) }
    }
}

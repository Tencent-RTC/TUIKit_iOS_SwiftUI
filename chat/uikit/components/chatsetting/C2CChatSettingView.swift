import AtomicXCore
import SwiftUI

public struct C2CChatSettingView: View {
    private let implementation: C2CChatSettingImpl

    public init(
        userID: String,
        config: C2CChatSettingConfig? = nil,
        onSendMessageClick: (() -> Void)? = nil,
        onContactDelete: (() -> Void)? = nil,
        onBack: (() -> Void)? = nil
    ) {
        implementation = C2CChatSettingImpl(
            userID: userID,
            config: config,
            onSendMessageClick: onSendMessageClick,
            onContactDelete: onContactDelete,
            onBack: onBack
        )
    }

    public var body: some View { implementation }
}

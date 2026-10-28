import AtomicXCore
import SwiftUI

internal struct ConfigGroupInfoView: View {
    private let implementation: ConfigGroupInfoViewImpl

    internal init(members: [UserPickerItem], onComplete: @escaping (String?, String?, String?) -> Void, onBack: @escaping () -> Void) {
        implementation = ConfigGroupInfoViewImpl(
            members: members,
            onComplete: onComplete,
            onBack: onBack
        )
    }

    internal var body: some View { implementation }
}

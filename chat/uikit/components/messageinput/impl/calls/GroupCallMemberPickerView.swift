import AtomicXCore
import SwiftUI

internal struct GroupCallMemberPickerView: View {
    private let implementation: GroupCallMemberPickerViewImpl

    internal init(groupID: String, title: String, onConfirm: @escaping ([String]) -> Void) {
        implementation = GroupCallMemberPickerViewImpl(
            groupID: groupID,
            title: title,
            onConfirm: onConfirm
        )
    }

    internal var body: some View { implementation }
}

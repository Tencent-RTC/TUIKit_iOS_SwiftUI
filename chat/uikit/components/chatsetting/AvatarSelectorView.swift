import SwiftUI

public struct AvatarSelectorView: View {
    private let implementation: AvatarSelectorImpl

    public init(
        imageUrlList: [String],
        column: Int = 3,
        onComplete: @escaping (String?) -> Void
    ) {
        implementation = AvatarSelectorImpl(
            imageUrlList: imageUrlList,
            column: column,
            onComplete: onComplete
        )
    }

    public var body: some View { implementation }
}

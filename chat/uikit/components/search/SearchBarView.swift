import AtomicXCore
import SwiftUI

public struct SearchBarView: View {
    private let implementation: SearchBarImpl

    public init(onTapItem: @escaping (Any) -> Void, chatDestination: ((NavigationInfo) -> AnyView)? = nil) {
        implementation = SearchBarImpl(
            onTapItem: onTapItem,
            chatDestination: chatDestination
        )
    }

    public init(onTapItem: @escaping (Any) -> Void, preservesSearchOnSelection: Bool) {
        implementation = SearchBarImpl(onTapItem: onTapItem, preservesSearchOnSelection: preservesSearchOnSelection)
    }

    public var body: some View { implementation }
}

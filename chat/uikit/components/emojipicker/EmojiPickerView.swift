import Kingfisher
import SwiftUI
import UIKit

public struct EmojiPickerView: View {
    private let implementation: EmojiPickerImpl

    public init(onEmojiClick: @escaping (EmojiData) -> Void,
                onSendClick: @escaping () -> Void,
                onDeleteClick: @escaping () -> Void,
                onCustomEmojiSelected: ((EmojiGroup, EmojiData) -> Void)? = nil) {
        implementation = EmojiPickerImpl(
            onEmojiClick: onEmojiClick,
            onSendClick: onSendClick,
            onDeleteClick: onDeleteClick,
            onCustomEmojiSelected: onCustomEmojiSelected
        )
    }

    public var body: some View { implementation }
}

import AtomicXCore
import AVFoundation
import Combine
import Foundation
import Kingfisher
import SwiftUI

struct MessageCustomAction {
    let title: String
    let iconName: String
    let systemIconFallback: String
    let action: (MessageInfo) -> Void

    init(
        title: String,
        iconName: String = "",
        systemIconFallback: String = "ellipsis",
        action: @escaping (MessageInfo) -> Void
    ) {
        self.title = title
        self.iconName = iconName
        self.systemIconFallback = systemIconFallback
        self.action = action
    }
}

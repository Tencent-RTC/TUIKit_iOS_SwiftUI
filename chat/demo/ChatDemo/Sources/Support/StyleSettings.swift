import TUIChatKit_Swift
import SwiftUI

class AppStyleSettings: ObservableObject {
    @Published var MessageListConfigProtocol: ChatMessageListConfig = ChatMessageListConfig()
    @Published var MessageInputConfigProtocol: ChatMessageInputConfig = ChatMessageInputConfig()
}

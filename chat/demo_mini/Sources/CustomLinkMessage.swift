import AtomicXCore
import TUIChatKit_Swift
import SwiftUI

struct CustomLinkMessage {
    static let businessID = "text_link"
    let text: String?
    let link: String?
    static func from(_ s: String?) -> CustomLinkMessage? {
        guard let s = s, let d = s.data(using: .utf8),
              let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return nil }
        return CustomLinkMessage(text: j["text"] as? String, link: j["link"] as? String)
    }

    static func from(_ p: CustomMessagePayload) -> CustomLinkMessage? { from(p.customData) }
}

enum CustomLinkMessageManager {
    static func register() {
        MessageListView.registerCustomMessageCell(
            businessID: CustomLinkMessage.businessID,
            summaryProvider: { CustomLinkMessage.from($0)?.text },
            contentViewBuilder: { AnyView(LinkBubble(payload: $0)) }
        )
    }

    static func send(conversationID: String) {
        let text = LocalizedChatString("DemoChatCustomMessageContent")
        let payload: [String: Any] = [
            "businessID": CustomLinkMessage.businessID,
            "text": text,
            "link": "https://cloud.tencent.com/document/product/269/3794",
        ]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: jsonData, encoding: .utf8) else { return }
        let customPayload = CustomSendMessagePayload(customData: json, description: text)
        var option = SendMessageOption()
        option.needReadReceipt = ChatMessageInputConfig().enableReadReceipt
        MessageInputStore.create(conversationID: conversationID)
            .sendMessage(payload: .custom(customPayload), option: option, completion: nil)
    }

    private static func makeMenuIcon() -> UIImage? {
        guard let symbol = UIImage(systemName: "paperplane.fill") else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        return UIGraphicsImageRenderer(size: symbol.size, format: format).image { _ in
            symbol.draw(at: .zero, blendMode: .normal, alpha: 140.0 / 255.0)
        }.withRenderingMode(.alwaysTemplate)
    }

    static func makeInputConfig(conversationID: String) -> ChatMessageInputConfig {
        ChatMessageInputConfig(actionCustomizer: { editor in
            editor.add(MessageInputMenuAction(
                ID: "demo.messageInput.customLink",
                title: LocalizedChatString("DemoChatCustomMessageMenuTitle"),
                iconName: "",
                icon: makeMenuIcon(),
                onClick: {
                    CustomLinkMessageManager.send(conversationID: conversationID)
                }
            ))
        })
    }
}

struct LinkBubble: View {
    @EnvironmentObject var themeState: ThemeState
    let payload: CustomMessagePayload
    private var linkLabel: some View {
        let link = CustomLinkMessage.from(payload)?.link ?? ""
        return Group {
            if !link.isEmpty {
                Text(LocalizedChatString("DemoChatCustomMessageViewDetails"))
                    .font(FontScheme.caption2Regular)
                    .foregroundColor(themeState.colors.textColorLink)
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CGFloat(SpacingScheme.smallSpacing)) {
            Text(CustomLinkMessage.from(payload)?.text ?? "")
                .font(FontScheme.caption1Regular)
                .foregroundColor(themeState.colors.textColorPrimary)
            linkLabel
        }
        .padding(.horizontal, CGFloat(SpacingScheme.bubbleSpacing))
        .padding(.vertical, CGFloat(SpacingScheme.iconIconSpacing))
        .contentShape(Rectangle())
        .onTapGesture {
            guard let raw = CustomLinkMessage.from(payload)?.link?
                .trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty,
                let url = URL(string: raw) else { return }
            UIApplication.shared.open(url)
        }
    }
}

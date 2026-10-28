import AtomicXCore
import SwiftUI
import UIKit

enum MessageInputQuoteSummaryFormatter {
    static func format(message: MessageInfo) -> String {
        guard let payload = message.messagePayload else { return "" }
        switch payload {
        case .text(let textPayload):
            return EmojiManager.shared.createLocalizedStringFromEmojiCodes(textPayload.text)
        case .image:
            return LocalizedChatString("MessageTypeImage")
        case .video:
            return LocalizedChatString("MessageTypeVideo")
        case .audio:
            return LocalizedChatString("MessageTypeVoice")
        case .file(let filePayload):
            if let fileName = filePayload.fileName, !fileName.isEmpty {
                return fileName
            }
            return LocalizedChatString("MessageTypeFile")
        case .merged:
            return LocalizedChatString("MessageTypeMergedHistory")
        case .face(let facePayload):
            if let faceData = facePayload.faceData, !faceData.isEmpty {
                return faceData
            }
            return LocalizedChatString("MessageTypeCustom")
        case .custom(let customPayload):
            if let summary = CustomMessageSummaryRegistry.shared.summary(for: customPayload), !summary.isEmpty {
                return summary
            }
            return LocalizedChatString("MessageTypeCustom")
        case .tips:
            return ""
        case .stream:
            return LocalizedChatString("MessageTypeCustom")
        default:
            return LocalizedChatString("MessageTypeCustom")
        }
    }
}

struct MessageInputQuotePreviewBar: View {
    private static let separatorHeight: CGFloat = 0.5
    private static let contentLeadingInset: CGFloat = CGFloat(SpacingScheme.iconIconSpacing)
    private static let contentTrailingGap: CGFloat = CGFloat(SpacingScheme.smallSpacing)
    private static let closeButtonSize: CGFloat = 32
    private static let closeButtonTrailingInset: CGFloat = CGFloat(SpacingScheme.iconIconSpacing)

    @EnvironmentObject var themeState: ThemeState
    let senderName: String
    let summary: String
    let onClose: () -> Void

    private var contentText: Text {
        var text = Text(senderName)
            .font(FontScheme.caption2Medium)
            .foregroundColor(themeState.colors.textColorSecondary)
        if !summary.isEmpty {
            text = text + Text("：")
                .font(FontScheme.caption2Medium)
                .foregroundColor(themeState.colors.textColorSecondary)
                + Text(summary)
                .font(FontScheme.caption2Regular)
                .foregroundColor(themeState.colors.textColorTertiary)
        }
        return text
    }

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(themeState.colors.strokeColorPrimary)
                .frame(height: Self.separatorHeight)
            HStack(spacing: 0) {
                contentText
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: Self.contentTrailingGap)
                Button(action: onClose) {
                    Text("×")
                        .font(FontScheme.body3Regular)
                        .foregroundColor(themeState.colors.textColorSecondary)
                        .frame(width: Self.closeButtonSize, height: Self.closeButtonSize)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, Self.contentLeadingInset)
            .padding(.trailing, Self.closeButtonTrailingInset)
            .frame(maxHeight: .infinity)
        }
        .background(themeState.colors.bgColorDefault)
    }
}

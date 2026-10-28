import AtomicXCore
import SwiftUI

struct MessageCallContentView: View {
    let message: MessageInfo
    let isLeft: Bool
    let isSelf: Bool
    let shouldHighlight: Bool

    @EnvironmentObject var themeState: ThemeState

    private static let audioIconSize = CGSize(width: 22, height: 8)
    private static let videoIconSize = CGSize(width: 22, height: 15)
    private static let iconTextSpacing = CGFloat(SpacingScheme.smallSpacing)

    var body: some View {
        if let callModel = CallMessageParser.parse(message) {
            content(callModel: callModel)
                .padding(.horizontal, CGFloat(SpacingScheme.iconIconSpacing))
                .padding(.vertical, CGFloat(SpacingScheme.smallSpacing))
                .bubbleBackground(isSelf: isSelf, isLeft: isLeft, shouldHighlight: shouldHighlight, message: message)
                .contentShape(Rectangle())
                .onTapGesture {
                    handleTap(callModel: callModel)
                }
        } else {
            EmptyView()
        }
    }

    private func content(callModel: CallMessageModel) -> some View {
        let contentColor = isSelf ? themeState.colors.textColorAntiPrimary : themeState.colors.textColorPrimary
        return HStack(spacing: Self.iconTextSpacing) {
            if isSelf {
                textLabel(callModel: callModel, contentColor: contentColor)
                iconView(callModel: callModel, contentColor: contentColor)
            } else {
                iconView(callModel: callModel, contentColor: contentColor)
                textLabel(callModel: callModel, contentColor: contentColor)
            }
        }
    }

    private func textLabel(callModel: CallMessageModel, contentColor: Color) -> some View {
        Text(callModel.displayString(senderShowName: MessageListHelper.senderShowName(of: message)))
            .font(themeState.fonts.caption1Regular)
            .foregroundColor(contentColor)
            .lineLimit(2)
    }

    @ViewBuilder
    private func iconView(callModel: CallMessageModel, contentColor: Color) -> some View {
        switch callModel.streamMediaType {
        case .voice:
            callIcon(name: "message_call_audio", size: Self.audioIconSize, contentColor: contentColor)
        case .video:
            callIcon(name: "message_call_video", size: Self.videoIconSize, contentColor: contentColor)
        default:
            EmptyView()
        }
    }

    private func callIcon(name: String, size: CGSize, contentColor: Color) -> some View {
        Image(name, bundle: AtomicXChatResources.resourceBundle)
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .frame(width: size.width, height: size.height)
            .foregroundColor(contentColor)
            .scaleEffect(x: isSelf ? 1 : -1, y: 1)
    }

    private func handleTap(callModel: CallMessageModel) {
        let targetUserID: String
        if callModel.isCaller {
            targetUserID = callModel.inviteeList.first ?? message.to.trimmingCharacters(in: .whitespaces)
        } else {
            targetUserID = callModel.caller.trimmingCharacters(in: .whitespaces)
        }
        guard !targetUserID.isEmpty else { return }
        let mediaType: ChatCallEventPublisher.MediaType = callModel.streamMediaType == .video ? .video : .audio
        ChatCallEventPublisher.publishStartCall(participantIDs: [targetUserID], mediaType: mediaType)
    }
}

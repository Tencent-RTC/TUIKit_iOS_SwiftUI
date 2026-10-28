import AtomicXCore
import AVFoundation
import QuickLook
import SwiftUI

enum MessageDisplayMode {
    case normal
    case merged
}

private enum MessageMainBubbleBottomID: AlignmentID {
    static func defaultValue(in dimensions: ViewDimensions) -> CGFloat {
        dimensions[.bottom]
    }
}

private extension VerticalAlignment {
    static let messageMainBubbleBottom = VerticalAlignment(MessageMainBubbleBottomID.self)
}

struct MessageView: View {
    @EnvironmentObject private var menuManager: MessageMenuManager
    @Environment(\.messageCustomActions) private var customActions: [MessageCustomAction]
    @Environment(\.messageListBounds) private var messageListBounds: CGRect
    @EnvironmentObject var themeState: ThemeState
    @EnvironmentObject private var multiSelectManager: MultiSelectManager
    @Environment(\.messageListConfigProtocol) var config: MessageListConfigProtocol
    @Environment(\.locateMessageID) private var locateMessageID: String?
    @Environment(\.toggleMessageSelection) private var toggleMessageSelection: ((MessageInfo) -> Void)?
    // 宿主共享预览管理器与全屏弹层，避免每个单元重复订阅 Store。
    private let imageViewerManager: ImageViewerManager
    @State private var isShowingEditView = false
    @State private var longPressed = false
    @State private var messageBubbleFrame: CGRect = .zero
    @State private var showReactionDetail = false

    @State private var messageInputStore: MessageInputStore?
    let message: MessageInfo
    let onUserClick: ((String) -> Void)?
    let parentMessageList: [MessageInfo]
    let displayMode: MessageDisplayMode
    private let staticMessagesProvider: (() -> [MessageInfo])?
    private let precomputedTimeHeader: String??
    private var messageListStore: MessageListStore
    private var audioPlayer: AudioPlayer
    private var audioPlaybackManager: AudioPlaybackManager

    private var isSelected: Bool {
        let msgID = message.msgID
        guard !msgID.isEmpty else { return false }
        return multiSelectManager.selectedMessageIDs.contains(msgID)
    }

    private var isMultiSelectMode: Bool {
        return multiSelectManager.isMultiSelectMode
    }

    private func shouldHighlightMessage(_ message: MessageInfo) -> Bool {
        let shouldHighlight = locateMessageID == message.id
        return shouldHighlight
    }

    private func locateMessage(msgID: String) {
        var userInfo: [String: Any] = ["msgID": msgID, "returnMsgID": message.msgID]
        if let quoteInfo = message.quoteInfo {
            userInfo["quoteInfo"] = quoteInfo
        }
        NotificationCenter.default.post(
            name: NSNotification.Name("locateMessageNotification"),
            object: nil,
            userInfo: userInfo
        )
    }

    var isLeft: Bool {
        if displayMode == .merged {
            return true
        }
        switch config.alignment {
        case .left:
            return true
        case .right:
            return false
        case .twoSided:
            return !message.isSentBySelf
        }
    }

    private var shouldShowAvatar: Bool {
        if displayMode == .merged {
            return true
        }
        return isLeft ? config.isShowLeftAvatar : config.isShowRightAvatar
    }

    init(message: MessageInfo, messageListStore: MessageListStore, conversationID: String, audioPlayer: AudioPlayer, audioPlaybackManager: AudioPlaybackManager = AudioPlaybackManager(), onUserClick: ((String) -> Void)? = nil, parentMessageList: [MessageInfo], displayMode: MessageDisplayMode = .normal, mergedMediaSource: MergedMediaMessagesBox? = nil, imageViewerManager: ImageViewerManager, precomputedTimeHeader: String?? = nil) {
        self.message = message
        self.messageListStore = messageListStore
        self.onUserClick = onUserClick
        self.audioPlayer = audioPlayer
        self.audioPlaybackManager = audioPlaybackManager
        self.parentMessageList = parentMessageList
        self.displayMode = displayMode
        self.imageViewerManager = imageViewerManager
        self.precomputedTimeHeader = precomputedTimeHeader
        self._messageInputStore = State(initialValue: nil)
        self.staticMessagesProvider = displayMode == .merged ? { [weak mergedMediaSource] in
            mergedMediaSource?.messages ?? parentMessageList
        } : nil
    }

    private var isMenuEligible: Bool {
        if message.status == .revoked { return false }
        if case .tips = message.messagePayload { return false }
        if case .custom(let payload) = message.messagePayload, isCustomSystemMessage(payload) { return false }
        if CallMessageParser.parse(message)?.isGroup == true { return false }
        return true
    }

    var body: some View {
        Group {
            if displayMode == .merged || !isMenuEligible {
                mainContent
            } else {
                mainContent
                    .modifier(MessageViewModifiers(
                        messageBubbleFrame: $messageBubbleFrame,
                        longPressed: $longPressed,
                        menuManager: menuManager,
                        message: message,
                        style: config
                    ))
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 0) {
            timeDisplayView
            contentView
        }
    }

    @ViewBuilder
    private var timeDisplayView: some View {
        if displayMode != .merged, let timeString = getTimeString(), config.isShowTimeMessage {
            Text(timeString)
                .font(themeState.fonts.caption2Regular)
                .foregroundColor(themeState.colors.textColorSecondary)
                .frame(maxWidth: .infinity)
                .padding(.top, Self.timeVerticalMargin)
                .padding(.bottom, max(max(Self.timeVerticalMargin - config.cellSpacing, 0) - config.cellSpacing, 0))
        }
    }

    private static let timeVerticalMargin = CGFloat(SpacingScheme.contentSpacing)

    @ViewBuilder
    private var contentView: some View {
        if message.status == .revoked {
            revokedMessageView
        } else if case .tips(let payload) = message.messagePayload {
            systemMessageView(payload)
        } else if case .custom(let payload) = message.messagePayload, isCustomSystemMessage(payload) {
            customSystemMessageView(payload)
        } else if let callModel = CallMessageParser.parse(message), callModel.isGroup {
            if config.isShowSystemMessage {
                centeredTipText(callModel.displayString(senderShowName: MessageListHelper.senderShowName(of: message)))
                    .accessibilityIdentifier("chat_group_call_tip_\(message.msgID)")
            }
        } else {
            messageContentWrapper
        }
    }

    @ViewBuilder
    private var revokedMessageView: some View {
        centeredTipText(MessageListHelper.getMessageAbstract(message))
    }

    private func centeredTipText(_ text: String) -> some View {
        Text(text)
            .font(themeState.fonts.caption2Regular)
            .foregroundColor(themeState.colors.textColorSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, CGFloat(themeState.spacing.normalSpacing))
            .padding(.vertical, CGFloat(themeState.spacing.contentSpacing))
    }

    private func getTimeString() -> String? {
        if let precomputed = precomputedTimeHeader {
            return precomputed
        }
        guard let currentIndex = parentMessageList.firstIndex(where: { $0.msgID == message.msgID }) else {
            return nil
        }
        return Self.getMessageTimeString(for: message, at: currentIndex, messageList: parentMessageList)
    }

    static func getMessageTimeString(for message: MessageInfo, at index: Int, messageList: [MessageInfo]) -> String? {
        guard let messageDate = date(from: message.timestamp) else { return nil }
        if index == 0 {
            return DateHelper.convertDateToMessageTimeStr(messageDate)
        }
        let prev = index - 1
        guard prev >= 0, prev < messageList.count else { return nil }
        let previousMessage = messageList[prev]
        guard let previousDate = date(from: previousMessage.timestamp) else { return nil }
        let timeDifference = messageDate.timeIntervalSince(previousDate)
        let timeThreshold: TimeInterval = 300
        if timeDifference > timeThreshold {
            return DateHelper.convertDateToMessageTimeStr(messageDate)
        }
        return nil
    }

    @ViewBuilder
    private var messageContentWrapper: some View {
        Group {
            if isLeft {
                HStack(alignment: .top, spacing: 0) {
                    if isMultiSelectMode {
                        MessageCheckBox(isSelected: isSelected)
                            .fixedSize()
                            .layoutPriority(Self.selectionLayoutPriority)
                            .padding(.trailing, CGFloat(themeState.spacing.smallSpacing))
                            .onTapGesture {
                                toggleMessageSelection?(message)
                            }
                    }

                    userAvatar(isShow: shouldShowAvatar, isRight: false)
                    if displayMode == .merged {
                        mergedDetailBody
                    } else if shouldShowGroupNickname {
                        VStack(alignment: .leading, spacing: CGFloat(themeState.spacing.iconTextSpacing)) {
                            groupNicknameView
                            messageContent(alignment: .leading)
                        }
                        Spacer(minLength: config.horizontalPadding)
                    } else {
                        messageContent(alignment: .leading)
                        Spacer(minLength: config.horizontalPadding)
                    }
                }
            } else {
                HStack(alignment: .top, spacing: 0) {
                    if isMultiSelectMode {
                        MessageCheckBox(isSelected: isSelected)
                            .fixedSize()
                            .layoutPriority(Self.selectionLayoutPriority)
                            .padding(.trailing, CGFloat(themeState.spacing.smallSpacing))
                            .onTapGesture {
                                toggleMessageSelection?(message)
                            }
                    }

                    Spacer(minLength: config.horizontalPadding)
                    messageContent(alignment: .trailing)
                    userAvatar(isShow: shouldShowAvatar, isRight: true)
                }
            }
        }
        .padding(.horizontal, config.horizontalPadding)
        .padding(.vertical, config.cellSpacing)
        .frame(maxWidth: .infinity, alignment: isLeft ? .leading : .trailing)
        .contentShape(Rectangle())
        .onTapGesture {
            if isMultiSelectMode {
                toggleMessageSelection?(message)
            }
        }
    }

    private func userAvatar(isShow: Bool, isRight: Bool) -> some View {
        Group {
            if isShow {
                AvatarView(url: message.from.avatarURL ?? "", name: (message.from.nickname?.isEmpty ?? true) ? message.from.userID : (message.from.nickname ?? ""), shape: .roundedRectangle, cornerRadius: CGFloat(themeState.radius.tipsRadius))
                    .frame(width: Self.avatarSize, height: Self.avatarSize)
                    .padding(isRight ? .leading : .trailing, config.avatarSpacing)
                    .contentShape(Rectangle())
                    .scaleEffect(message.isSentBySelf ? 1.0 : 1.0)
                    .onTapGesture {
                        if !message.isSentBySelf {
                            onUserClick?(message.from.userID)
                        }
                    }
                    .onLongPressGesture {
                        if !message.isSentBySelf {
                            NotificationCenter.default.post(
                                name: NSNotification.Name("mentionUserNotification"),
                                object: nil,
                                userInfo: [
                                    "userID": message.from.userID,
                                    "nickname": message.from.nickname ?? ""
                                ]
                            )
                        }
                    }
            }
        }
    }

    private var mergedDetailBody: some View {
        VStack(alignment: .leading, spacing: CGFloat(themeState.spacing.iconTextSpacing)) {
            HStack(alignment: .center, spacing: CGFloat(themeState.spacing.iconTextSpacing)) {
                Text(Self.senderDisplayName(of: message.from))
                    .font(themeState.fonts.caption3Regular)
                    .foregroundColor(themeState.colors.textColorSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
                if let date = Self.date(from: message.timestamp) {
                    Text(DateHelper.convertDateToMessageTimeStr(date))
                        .font(themeState.fonts.caption3Regular)
                        .foregroundColor(themeState.colors.textColorSecondary)
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            messageContent(alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static func senderDisplayName(of sender: MessageSenderInfo) -> String {
        if let nameCard = sender.nameCard, !nameCard.isEmpty { return nameCard }
        if let friendRemark = sender.friendRemark, !friendRemark.isEmpty { return friendRemark }
        if let nickname = sender.nickname, !nickname.isEmpty { return nickname }
        return sender.userID
    }

    private var shouldShowGroupNickname: Bool {
        config.isShowLeftNickname && message.conversationType == .group
    }

    private var groupNicknameView: some View {
        Text(Self.senderDisplayName(of: message.from))
            .font(themeState.fonts.caption3Regular)
            .foregroundColor(themeState.colors.textColorSecondary)
            .lineLimit(1)
            .truncationMode(.tail)
    }

    private var sendFailIcon: some View {
        Image(systemName: "exclamationmark.circle.fill")
            .font(themeState.fonts.caption1Regular)
            .foregroundColor(themeState.colors.textColorError)
            .padding(.bottom, 2)
            .onTapGesture {
                print("MessageView: Send fail icon tapped")
                WindowAlertManager.shared.showAlert(
                    title: LocalizedChatString("TipsConfirmResendMessage"),
                    cancelText: LocalizedChatString("Cancel"),
                    confirmText: LocalizedChatString("Confirm"),
                    onConfirm: {
                        print("MessageView: Resend confirmed")
                        self.resendMessage(message)
                    }
                )
            }
    }

    private var sendingLoadingIcon: some View {
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: themeState.colors.textColorSecondary))
            .scaleEffect(0.8)
            .padding(.bottom, 2)
    }

    private var violationIcon: some View {
        Image(systemName: "exclamationmark.circle.fill")
            .font(themeState.fonts.caption1Regular)
            .foregroundColor(themeState.colors.textColorError)
            .padding(.bottom, 2)
    }

    private var violationHintText: some View {
        Text(LocalizedChatString("MessageTypeSecurityStrikeInfo"))
            .font(themeState.fonts.caption3Regular)
            .foregroundColor(themeState.colors.textColorError)
    }

    private var readReceiptStatusText: some View {
        Text(MessageListHelper.receiptText(message: message))
            .font(themeState.fonts.caption3Regular)
            .foregroundColor(themeState.colors.textColorSecondary)
            .fixedSize(horizontal: true, vertical: true)
            .accessibilityIdentifier("chat_read_receipt_\(message.msgID)")
            .onTapGesture {
                guard !isMultiSelectMode, message.conversationType == .group else { return }
                let actionStore = MessageActionStore.create(message: message)
                NotificationCenter.default.post(
                    name: NSNotification.Name("kShowMessageReadReceiptNotification"),
                    object: nil,
                    userInfo: ["message": message, "messageActionStore": actionStore]
                )
            }
    }

    private static let statusSlotGap = CGFloat(SpacingScheme.smallSpacing)
    private static let avatarSize: CGFloat = 40
    private static let statusIconWidth: CGFloat = 20
    private static let minimumTextContentWidth: CGFloat = 1
    private static let selectionLayoutPriority: Double = 1
    private static let horizontalPaddingCount: CGFloat = 3

    private var messageRowWidth: CGFloat {
        messageListBounds.width > 0 ? messageListBounds.width : UIScreen.main.bounds.width
    }

    private var availableMessageColumnWidth: CGFloat {
        let avatarWidth = shouldShowAvatar ? Self.avatarSize + config.avatarSpacing : 0
        let selectionWidth = isMultiSelectMode ? MessageCheckBox.size + CGFloat(themeState.spacing.smallSpacing) : 0
        return max(0, messageRowWidth - config.horizontalPadding * Self.horizontalPaddingCount - avatarWidth - selectionWidth - statusSlotWidth)
    }

    private var statusSlotWidth: CGFloat {
        if message.isSentBySelf {
            if message.status == .sendFail || message.status == .violation {
                return Self.statusIconWidth + Self.statusSlotGap
            }
            if message.status == .sending {
                return message.messageType == .video ? 0 : Self.statusIconWidth + Self.statusSlotGap
            }
        }
        if MessageListHelper.shouldShowReadReceipt(message: message, isInMergedDetailView: displayMode == .merged) {
            let width = ceil((MessageListHelper.receiptText(message: message) as NSString)
                .size(withAttributes: [.font: UIKitFontScheme.caption3Regular]).width)
            return width + Self.statusSlotGap
        }
        return 0
    }

    private var maxMessageBubbleWidth: CGFloat {
        let ratio = config.bubbleMaxWidthRatio.isFinite ? min(1, max(0, config.bubbleMaxWidthRatio)) : ChatMessageListConfig.defaultBubbleMaxWidthRatio
        return max(Self.minimumTextContentWidth, min(messageRowWidth * ratio, availableMessageColumnWidth))
    }

    private var maxAttributedTextContentWidth: CGFloat {
        let reactionPadding = hasVisibleReactions ? reactionBarInsets.contentPadding * 2 : 0
        return max(Self.minimumTextContentWidth, maxMessageBubbleWidth - TextBubbleMetrics.horizontalInset * 2 - reactionPadding)
    }

    @ViewBuilder
    private var statusSlot: some View {
        if message.isSentBySelf && message.status == .sendFail {
            sendFailIcon
        } else if message.isSentBySelf && message.status == .violation {
            violationIcon
        } else if message.isSentBySelf && message.status == .sending {
            if message.messageType != .video {
                sendingLoadingIcon
            }
        } else if MessageListHelper.shouldShowReadReceipt(message: message, isInMergedDetailView: displayMode == .merged) {
            readReceiptStatusText
        }
    }

    private func messageContent(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: CGFloat(themeState.spacing.iconTextSpacing)) {
            HStack(alignment: .messageMainBubbleBottom, spacing: Self.statusSlotGap) {
                if !isLeft {
                    statusSlot
                        .alignmentGuide(.messageMainBubbleBottom) { $0[.bottom] }
                }

                let hasReactions = hasVisibleReactions
                VStack(alignment: isLeft ? .leading : .trailing, spacing: CGFloat(themeState.spacing.iconTextSpacing)) {
                    if hasReactions {
                        let insets = reactionBarInsets
                        VStack(alignment: isLeft ? .leading : .trailing, spacing: 0) {
                            messageContentBody
                                .opacity(message.status == .sending ? 0.7 : 1.0)
                                .padding(.top, insets.contentPadding)
                                .padding(.horizontal, insets.contentPadding)
                            MessageReactionBar(
                                reactionList: message.reactionList,
                                isLeft: isLeft,
                                isSentBySelf: message.isSentBySelf,
                                onClick: {
                                    showReactionDetail = true
                                },
                                maxWidth: max(0, maxMessageBubbleWidth - insets.horizontal * 2)
                            )
                            .environmentObject(themeState)
                            .padding(.top, insets.top)
                            .padding(.bottom, insets.bottom)
                            .padding(.horizontal, insets.horizontal)
                        }
                        .frame(maxWidth: maxMessageBubbleWidth, alignment: isLeft ? .leading : .trailing)
                        .modifier(ReactionBubbleContainer(
                            kind: reactionBubbleKind,
                            isSelf: message.isSentBySelf,
                            isLeft: isLeft,
                            shouldHighlight: shouldHighlightMessage(message),
                            message: message
                        ))
                        .alignmentGuide(.messageMainBubbleBottom) { $0[.bottom] }
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("chat_main_bubble_\(message.msgID)")
                    } else {
                        messageContentBody
                            .opacity(message.status == .sending ? 0.7 : 1.0)
                            .alignmentGuide(.messageMainBubbleBottom) { $0[.bottom] }
                            .accessibilityElement(children: .contain)
                            .accessibilityIdentifier("chat_main_bubble_\(message.msgID)")
                    }

                    if let quoteInfo = message.quoteInfo {
                        MessageQuoteBubbleView(quoteInfo: quoteInfo, maxWidth: maxMessageBubbleWidth) {
                            locateMessage(msgID: quoteInfo.msgID)
                        }
                        .environmentObject(themeState)
                        .allowsHitTesting(!isMultiSelectMode)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("chat_quote_bubble_\(message.msgID)")
                    }

                }
                .scaleEffect(longPressed ? 0.97 : 1.0)
                .animation(.spring(response: 0.3), value: longPressed)
                .background(
                    Group {
                        if displayMode != .merged && isMenuEligible {
                            BubbleLongPressBridge(bubbleFrame: messageBubbleFrame) {
                                longPressed = true
                                menuManager.showMenu(for: message, bubbleFrame: messageBubbleFrame, messageListBounds: messageListBounds, config: config as? MessageActionConfigProtocol, customActions: customActions)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    longPressed = false
                                }
                            }
                        }
                    }
                )

                if isLeft {
                    statusSlot
                        .alignmentGuide(.messageMainBubbleBottom) { $0[.bottom] }
                }
            }

            // 辅助文本须在回应容器外，避免与主气泡合并。
            auxiliaryBubbleView

            if message.status == .violation {
                violationHintText
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .sheet(isPresented: $showReactionDetail) {
            if config.isSupportReaction && !message.reactionList.isEmpty {
                let actionStore = MessageActionStore.create(
                    message: message
                )
                ReactionDetailSheet(
                    reactionList: message.reactionList,
                    currentUserID: LoginStore.shared.state.value.loginUserInfo?.userID ?? "",
                    onFetchUsers: { reactionID in
                        actionStore.loadReactionUsers(
                            reactionID: reactionID,
                            count: 100,
                            completion: nil
                        )
                    },
                    onRemoveReaction: { reactionID in
                        actionStore.removeReaction(reactionID: reactionID) { result in
                            if case .failure(let error) = result {
                                print(">>>>> removeMessageReaction failed: \(error.code), \(error.message)")
                            }
                            DispatchQueue.main.async {
                                showReactionDetail = false
                            }
                        }
                    }
                )
                .environmentObject(themeState)
                .bottomSheet()
            }
        }
        .onChange(of: message.reactionList.isEmpty) { isEmpty in
            if isEmpty {
                showReactionDetail = false
            } else {
                NotificationCenter.default.post(
                    name: NSNotification.Name("reactionBarAppeared"),
                    object: nil,
                    userInfo: ["msgID": message.msgID]
                )
            }
        }
    }

    private func systemMessageView(_ payload: TipsMessagePayload) -> some View {
        guard let groupTips = payload.groupTips, config.isShowSystemMessage else {
            return AnyView(EmptyView())
        }
        return AnyView(centeredTipText(MessageListHelper.getGroupTipsDisplayString(groupTips)))
    }

    private func isCustomSystemMessage(_ payload: CustomMessagePayload) -> Bool {
        guard let data = payload.customData.data(using: .utf8),
              let customInfo = ChatUtil.jsonData2Dictionary(jsonData: data),
              let businessID = customInfo["businessID"] as? String
        else {
            return false
        }
        return businessID == "group_create"
    }

    private func customSystemMessageView(_ payload: CustomMessagePayload) -> some View {
        if config.isShowSystemMessage == false {
            return AnyView(EmptyView())
        }
        guard let data = payload.customData.data(using: .utf8),
              let customInfo = ChatUtil.jsonData2Dictionary(jsonData: data),
              let businessID = customInfo["businessID"] as? String,
              businessID == "group_create"
        else {
            return AnyView(EmptyView())
        }
        let groupType = customInfo["groupType"] as? String ?? ""
        let isCommunity = groupType.caseInsensitiveCompare("Community") == .orderedSame || (customInfo["cmd"] as? Int ?? 0) == 1
        let localContent = LocalizedChatString(isCommunity ? "TUICommunityCreateTipsMessage" : "TUIGroupCreateTipsMessage")
        let displayText: String
        if message.isSentBySelf {
            displayText = localContent
        } else {
            let opUser = MessageListHelper.senderShowName(of: message)
            let content = customInfo["content"] as? String ?? ""
            displayText = content.isEmpty ? "\(opUser) \(localContent)" : "\(opUser) \(content)"
        }
        guard !displayText.isEmpty else { return AnyView(EmptyView()) }
        return AnyView(centeredTipText(displayText))
    }

    private var reactionBubbleKind: ReactionBubbleContainer.Kind {
        switch message.messagePayload {
        case .merged: return .mergedCard
        case .image, .video: return .media
        default: return .bubble
        }
    }

    private var hasVisibleReactions: Bool {
        config.isSupportReaction && !message.reactionList.isEmpty
    }

    private var reactionBarInsets: (contentPadding: CGFloat, top: CGFloat, bottom: CGFloat, horizontal: CGFloat) {
        let small = CGFloat(themeState.spacing.smallSpacing)
        let icon = CGFloat(themeState.spacing.iconTextSpacing)
        let icons = CGFloat(themeState.spacing.iconIconSpacing)
        switch reactionBubbleKind {
        case .mergedCard: return (0, icon, icons, icons)
        case .media: return (icon, 2, icons, icons)
        case .bubble: return (0, 2, small, small)
        }
    }

    @ViewBuilder
    private var auxiliaryBubbleView: some View {
        switch message.messagePayload {
        case .text?:
            TranslationBubbleView(message: message, isSelf: message.isSentBySelf, maxWidth: maxMessageBubbleWidth)
                .padding(.top, 2)
                .allowsHitTesting(!isMultiSelectMode)
        case .audio(let payload)?:

            AsrTextBubbleView(
                payload: payload,
                message: message,
                messageListStore: messageListStore,
                isSelf: message.isSentBySelf,
                maxWidth: maxMessageBubbleWidth
            )
            .padding(.top, CGFloat(themeState.spacing.smallSpacing))
            .allowsHitTesting(!isMultiSelectMode)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var messageContentBody: some View {
        Group {
            if let payload = message.messagePayload {
                switch payload {
                case .merged:
                    MergeMessageView(
                        message: message,
                        conversationID: messageListStore.conversationID,
                        hideCardChrome: config.isSupportReaction && !message.reactionList.isEmpty
                    )
                        .allowsHitTesting(!isMultiSelectMode)
                case .text(let payload):
                    TextMessageView(
                        payload: payload,
                        message: message,
                        isLeft: isLeft,
                        isSelf: message.isSentBySelf,
                        shouldHighlight: shouldHighlightMessage(message),
                        maxContentWidth: maxAttributedTextContentWidth
                    )
                case .image(let payload):
                    ImageMessageView(
                        payload: payload,
                        message: message,
                        messageListStore: messageListStore,
                        onImageTap: { imageViewerManager.showImageViewer(for: message, staticMessagesProvider: staticMessagesProvider) }
                    )
                    .allowsHitTesting(!isMultiSelectMode)
                    .modifier(LocateFlashOverlay(
                        shouldHighlight: shouldHighlightMessage(message) && !hasVisibleReactions,
                        isSelf: message.isSentBySelf,
                        radii: [16, 16, 16, 16]
                    ))
                case .video(let payload):
                    VideoMessageView(
                        payload: payload,
                        message: message,
                        messageListStore: messageListStore,
                        onVideoTap: { imageViewerManager.showImageViewer(for: message, staticMessagesProvider: staticMessagesProvider) }
                    )
                    .allowsHitTesting(!isMultiSelectMode)
                    .modifier(LocateFlashOverlay(
                        shouldHighlight: shouldHighlightMessage(message) && !hasVisibleReactions,
                        isSelf: message.isSentBySelf,
                        radii: [16, 16, 16, 16]
                    ))
                case .file(let payload):
                    FileMessageView(
                        payload: payload,
                        message: message,
                        messageListStore: messageListStore,
                        isLeft: isLeft,
                        isSelf: message.isSentBySelf,
                        shouldHighlight: shouldHighlightMessage(message)
                    )
                    .allowsHitTesting(!isMultiSelectMode)
                case .audio(let payload):
                    AudioMessageView(
                        payload: payload,
                        message: message,
                        messageListStore: messageListStore,
                        isLeft: isLeft,
                        isSelf: message.isSentBySelf,
                        shouldHighlight: shouldHighlightMessage(message),
                        audioPlayer: audioPlayer,
                        audioPlaybackManager: audioPlaybackManager
                    )
                    .allowsHitTesting(!isMultiSelectMode)
                case .custom(let customPayload):
                    if CallMessageParser.parse(message) != nil {
                        MessageCallContentView(
                            message: message,
                            isLeft: isLeft,
                            isSelf: message.isSentBySelf,
                            shouldHighlight: shouldHighlightMessage(message)
                        )
                        .allowsHitTesting(!isMultiSelectMode)
                    } else if let registeredCell = MessageCellRegistry.shared.customContentView(for: customPayload) {
                        registeredCell
                            .bubbleBackground(isSelf: message.isSentBySelf, isLeft: isLeft, shouldHighlight: shouldHighlightMessage(message), message: message)
                            .allowsHitTesting(!isMultiSelectMode)
                    } else if config.isShowUnsupportMessage {
                        Text(LocalizedChatString("NotSupportThisMessage"))
                            .font(themeState.fonts.caption2Regular)
                            .padding(CGFloat(themeState.spacing.iconIconSpacing))
                            .foregroundColor(themeState.colors.textColorPrimary)
                    }
                default:
                    if config.isShowUnsupportMessage {
                        Text(LocalizedChatString("NotSupportThisMessage"))
                            .font(themeState.fonts.caption2Regular)
                            .padding(CGFloat(themeState.spacing.iconIconSpacing))
                            .foregroundColor(themeState.colors.textColorPrimary)
                    }
                }
            } else {
                Text(LocalizedChatString("NoMessageContent"))
                    .font(themeState.fonts.caption2Regular)
                    .padding(CGFloat(themeState.spacing.iconIconSpacing))
                    .foregroundColor(themeState.colors.textColorPrimary)
            }
        }
        .background(
            GeometryReader { contentGeometry in
                Color.clear
                    .preference(
                        key: ViewPositionKey.self,
                        value: [contentGeometry.frame(in: .global)]
                    )
            }
        )
    }

    private func resendMessage(_ messageToResend: MessageInfo) {
        guard let payload = sendPayload(from: messageToResend) else { return }
        var option = SendMessageOption()
        option.needReadReceipt = messageToResend.needReadReceipt
        option.atUserList = messageToResend.atUserList.isEmpty ? nil : messageToResend.atUserList
        option.isExtensionEnabled = messageToResend.isExtensionEnabled
        option.offlinePushInfo = messageToResend.offlinePushInfo
        messageListStore.deleteMessages(messageList: [messageToResend]) { _ in }
        messageInputStore = MessageInputStore.create(conversationID: messageListStore.conversationID)
        messageInputStore?.sendMessage(payload: payload, option: option) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("Message resent successfully")
                case .failure(let error):
                    print("Failed to resend message: \(error.code), \(error.message)")
                }
            }
        }
    }

    private static func date(from timestamp: Int64?) -> Date? {
        guard let timestamp = timestamp else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(timestamp))
    }

    private func sendPayload(from message: MessageInfo) -> SendMessagePayload? {
        guard let payload = message.messagePayload else { return nil }
        switch payload {
        case .text(let text):
            return .text(TextSendMessagePayload(text: text.text))
        case .custom(let custom):
            return .custom(CustomSendMessagePayload(
                customData: custom.customData,
                description: custom.description,
                extensionInfo: custom.extensionInfo
            ))
        case .image(let image):
            guard let imagePath = image.originalImagePath else { return nil }
            return .image(ImageSendMessagePayload(
                imagePath: imagePath,
                imageWidth: image.originalImageWidth,
                imageHeight: image.originalImageHeight
            ))
        case .audio(let audio):
            guard let audioPath = audio.audioPath else { return nil }
            return .audio(AudioSendMessagePayload(audioFilePath: audioPath, duration: audio.audioDuration))
        case .video(let video):
            guard let videoPath = video.videoPath,
                  let snapshotPath = video.videoSnapshotPath else { return nil }
            return .video(VideoSendMessagePayload(
                videoFilePath: videoPath,
                videoType: video.videoType ?? "mp4",
                duration: video.videoDuration,
                snapshotPath: snapshotPath,
                snapshotWidth: video.videoSnapshotWidth,
                snapshotHeight: video.videoSnapshotHeight
            ))
        case .file(let file):
            guard let filePath = file.filePath else { return nil }
            return .file(FileSendMessagePayload(
                filePath: filePath,
                fileName: file.fileName ?? URL(fileURLWithPath: filePath).lastPathComponent,
                fileSize: file.fileSize
            ))
        case .face(let face):
            return .face(FaceSendMessagePayload(index: face.faceIndex, data: face.faceData ?? ""))
        case .tips, .merged, .stream:
            return nil
        }
    }
}

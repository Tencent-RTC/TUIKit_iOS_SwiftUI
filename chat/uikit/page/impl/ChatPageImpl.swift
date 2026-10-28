import AtomicXCore
import Foundation
import Kingfisher
import SwiftUI

extension MessageInfo {
    var contentText: String? {
        if case .text(let payload) = messagePayload {
            return payload.text
        }
        return nil
    }

    var imageInfo: (image: UIImage?, size: CGSize?) {
        guard case .image(let payload) = messagePayload else {
            return (nil, nil)
        }
        let size = CGSize(width: payload.originalImageWidth, height: payload.originalImageHeight)
        if let imagePath = payload.originalImagePath, let image = UIImage(contentsOfFile: imagePath) {
            return (image, size)
        }
        return (nil, size)
    }

    var videoInfo: (snapshot: UIImage?, duration: Int?) {
        guard case .video(let payload) = messagePayload else {
            return (nil, nil)
        }
        if let snapshotPath = payload.videoSnapshotPath {
            return (UIImage(contentsOfFile: snapshotPath), payload.videoDuration)
        } else {
            return (nil, payload.videoDuration)
        }
    }
}

struct ChatPageImpl: View {
    @EnvironmentObject var themeState: ThemeState
    @StateObject private var toast = Toast()
    @State private var isInMultiSelectMode = false
    @State private var isPeerTyping: Bool = false
    @State private var totalUnreadCount: Int = 0
    @State private var sendFailureReason: String? = nil
    @State private var mergedDetailMessage: MessageInfo? = nil
    @State private var showMergedDetail = false
    @State private var readReceiptMessage: MessageInfo? = nil
    @State private var readReceiptStore: MessageActionStore? = nil
    @State private var showReadReceiptDetail = false
    @State private var conversationStore = ConversationListStore.create()
    let onBack: (() -> Void)?
    let onUserClick: ((String) -> Void)?
    let onMoreClick: (() -> Void)?
    let locateMessage: MessageInfo?
    let isShowMoreButton: Bool
    let messageListConfig: ChatMessageListConfig?
    let messageInputConfig: ChatMessageInputConfig
    let topBannerView: AnyView?
    let showsNavigationBar: Bool
    private var conversation: ConversationInfo

    init(
        conversation: ConversationInfo,
        locateMessage: MessageInfo? = nil,
        messageListConfig: ChatMessageListConfig? = nil,
        messageInputConfig: ChatMessageInputConfig? = nil,
        isShowMoreButton: Bool = true,
        showsNavigationBar: Bool = true,
        topBannerView: AnyView? = nil,
        onBack: (() -> Void)? = nil,
        onUserClick: ((String) -> Void)? = nil,
        onMoreClick: (() -> Void)? = nil
    ) {
        self.conversation = conversation
        self.locateMessage = locateMessage
        self.messageListConfig = messageListConfig
        self.messageInputConfig = messageInputConfig ?? ChatMessageInputConfig(isShowAudioRecorder: nil)
        self.isShowMoreButton = isShowMoreButton
        self.showsNavigationBar = showsNavigationBar
        self.topBannerView = topBannerView
        self.onBack = onBack
        self.onUserClick = onUserClick
        self.onMoreClick = onMoreClick
    }

    var body: some View {
        return GeometryReader { geometry in
        VStack(spacing: 0) {
            if showsNavigationBar {
                self.navigationBarView
                self.navigationDivider
            }

            if let topBannerView = topBannerView {
                topBannerView
            }

            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    MessageListView(
                        conversationID: self.conversation.id,
                        config: resolvedMessageListConfig(),
                        locateMessage: self.locateMessage,
                        onUserClick: { userID in
                            onUserClick?(userID)
                        },
                        onMultiSelectModeChange: { isMultiSelect in
                            if isMultiSelect {
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            }
                            self.isInMultiSelectMode = isMultiSelect
                        }
                    )
                    .environment(\.openMergedMessageDetail, { message in
                        mergedDetailMessage = message
                        showMergedDetail = true
                    })
                    .environment(\.openReadReceiptDetail, { message, actionStore in
                        openReadReceiptDetailPage(message: message, actionStore: actionStore)
                    })

                    if !isInMultiSelectMode {
                        self.messageInputAreaView
                            .overlay(alignment: .top) {
                                if let reason = sendFailureReason {
                                    sendFailureBar(reason)
                                        .alignmentGuide(.top) { d in d.height + Self.failureBarBottomGap }
                                        .transition(.opacity)
                                }
                            }
                    }
                }
            }
        }
        .padding(.top, max(0, Self.windowTopSafeAreaInset - geometry.safeAreaInsets.top))
        .padding(.bottom, max(0, Self.windowBottomSafeAreaInset - geometry.safeAreaInsets.bottom))
        }
        .ignoresSafeArea(.keyboard)
        .background(
            themeState.colors.bgColorOperate
                .ignoresSafeArea()
        )
        .background(
            NavigationLink(destination: mergedDetailDestination, isActive: $showMergedDetail) { EmptyView() }
                .hidden()
        )
        .background(
            NavigationLink(destination: readReceiptDestination, isActive: $showReadReceiptDetail) { EmptyView() }
                .hidden()
        )
        .toast(toast)
        .onReceive(NotificationCenter.default.publisher(for: MessageInputView.typingStatusDidChangeNotification)) { notification in
            guard let cid = notification.userInfo?["conversationID"] as? String,
                  cid == conversation.id,
                  let isTyping = notification.userInfo?["isTyping"] as? Bool
            else { return }
            isPeerTyping = isTyping && (messageListConfig?.enableTyping ?? true)
        }
        .onReceive(conversationStore.state.subscribe(StatePublisherSelector(keyPath: \ConversationListState.totalUnreadCount))) { count in
            totalUnreadCount = Int(count)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("sendMessageFailureNotification"))) { notification in
            guard let reason = notification.userInfo?["reason"] as? String, !reason.isEmpty else { return }
            sendFailureReason = reason
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.failureBarDisplayDuration) {
                if sendFailureReason == reason {
                    sendFailureReason = nil
                }
            }
        }
        .animation(.easeInOut(duration: Self.failureBarFadeDuration), value: sendFailureReason)
    }

    private static let failureBarBottomGap: CGFloat = CGFloat(SpacingScheme.smallSpacing)
    private static let failureBarHorizontalPadding: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)
    private static let failureBarVerticalPadding: CGFloat = CGFloat(SpacingScheme.smallSpacing)
    private static let failureBarMinHeight: CGFloat = 40
    private static let failureBarIconSize: CGFloat = 16
    private static let failureBarIconTextGap: CGFloat = CGFloat(SpacingScheme.iconTextSpacing)
    private static let failureBarMaxTextWidth: CGFloat = 340
    private static let failureBarCornerRadius: CGFloat = CGFloat(RadiusScheme.smallRadius)
    private static let failureBarMaxLineCount: Int = 3
    private static let failureBarDisplayDuration: TimeInterval = 3
    private static let failureBarFadeDuration: TimeInterval = 0.25

    private static var windowTopSafeAreaInset: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.safeAreaInsets.top ?? 0
    }

    private static var windowBottomSafeAreaInset: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.safeAreaInsets.bottom ?? 0
    }

    private func sendFailureBar(_ reason: String) -> some View {
        HStack(spacing: Self.failureBarIconTextGap) {
            if let icon = AtomicXChatResources.image(named: "message_toast_error") {
                Image(uiImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: Self.failureBarIconSize, height: Self.failureBarIconSize)
            } else {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(themeState.fonts.caption1Regular)
                    .foregroundColor(themeState.colors.textColorError)
            }
            Text(reason)
                .font(themeState.fonts.caption2Regular)
                .foregroundColor(themeState.colors.textColorPrimary)
                .lineLimit(Self.failureBarMaxLineCount)
                .frame(width: failureTextWidth(reason), alignment: .leading)
        }
        .padding(.horizontal, Self.failureBarHorizontalPadding)
        .padding(.vertical, Self.failureBarVerticalPadding)
        .frame(minHeight: Self.failureBarMinHeight)
        .background(themeState.colors.bgColorOperate)
        .cornerRadius(Self.failureBarCornerRadius)
    }

    private func failureTextWidth(_ reason: String) -> CGFloat {
        let rect = (reason as NSString).boundingRect(
            with: CGSize(width: Self.failureBarMaxTextWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin],
            attributes: [.font: UIKitFontScheme.caption2Regular],
            context: nil
        )
        return min(ceil(rect.width), Self.failureBarMaxTextWidth)
    }

    private static let navBarHeight: CGFloat = 48
    private static let navHorizontalInset: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)
    private static let backButtonSize: CGFloat = 28
    private static let moreButtonSize: CGFloat = 24
    private static let backIconSlotWidth: CGFloat = 16
    private static let unreadBadgeLeadingGap: CGFloat = 2
    private static let unreadBadgeSize: CGFloat = 22

    private var navigationBarView: some View {
        ZStack {
            if !isInMultiSelectMode {
                Button(action: {
                    onMoreClick?()
                }) {
                    Text(isPeerTyping ? LocalizedChatString("Typing") : (conversation.title ?? conversation.conversationID))
                        .font(themeState.fonts.body4Bold)
                        .foregroundColor(themeState.colors.textColorPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, Self.navHorizontalInset * 2 + Self.backButtonSize)
            }

            HStack(spacing: 0) {
                if isInMultiSelectMode {
                    Button(action: {
                        NotificationCenter.default.post(name: NSNotification.Name("exitMultiSelectMode"), object: nil)
                    }) {
                        Text(LocalizedChatString("Cancel"))
                            .font(themeState.fonts.caption1Regular)
                            .foregroundColor(themeState.colors.textColorLink)
                    }
                    .frame(height: Self.backButtonSize)
                } else {
                    Button(action: {
                        onBack?()
                    }) {
                        Image("contact_info_back", bundle: AtomicXChatResources.resourceBundle)
                            .renderingMode(.template)
                            .foregroundColor(themeState.colors.textColorPrimary)
                            .frame(width: Self.backButtonSize, height: Self.backButtonSize, alignment: .leading)
                    }
                    .overlay(alignment: .leading) {
                        if totalUnreadCount > 0 {
                            unreadBadge
                                .padding(.leading, Self.backIconSlotWidth + Self.unreadBadgeLeadingGap)
                                .fixedSize()
                        }
                    }
                }

                Spacer()

                if !isInMultiSelectMode && isShowMoreButton {
                    Button(action: {
                        onMoreClick?()
                    }) {
                        Image(systemName: "ellipsis")
                            .font(themeState.fonts.body3Medium)
                            .foregroundColor(themeState.colors.textColorSecondary)
                            .frame(width: Self.moreButtonSize, height: Self.moreButtonSize)
                    }
                }
            }
            .padding(.horizontal, Self.navHorizontalInset)
        }
        .frame(height: Self.navBarHeight)
    }

    private var navigationDivider: some View {
        Rectangle()
            .fill(themeState.colors.strokeColorPrimary)
            .frame(height: 0.5)
    }

    private var unreadBadge: some View {
        Text(totalUnreadCount > 99 ? "99+" : "\(totalUnreadCount)")
            .font(themeState.fonts.caption3Regular)
            .foregroundColor(themeState.colors.textColorButton)
            .padding(.horizontal, CGFloat(SpacingScheme.smallSpacing))
            .frame(minWidth: Self.unreadBadgeSize, minHeight: Self.unreadBadgeSize)
            .background(themeState.colors.buttonColorOff)
            .clipShape(Capsule())
    }

    @ViewBuilder
    private var mergedDetailDestination: some View {
        if let message = mergedDetailMessage {
            MessageListView.makeMergedMessageDetailView(message: message, conversationID: conversation.id)
                .environmentObject(themeState)
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private var readReceiptDestination: some View {
        if let message = readReceiptMessage, let actionStore = readReceiptStore {
            MessageListView.makeReadReceiptDetailView(
                message: message,
                actionStore: actionStore,
                onUserClick: { userID in onUserClick?(userID) }
            )
            .environmentObject(themeState)
        } else {
            EmptyView()
        }
    }

    // iOS 15 连续激活程序化 NavigationLink 会弹出回执页，此处使用 UIKit push。
    private func openReadReceiptDetailPage(message: MessageInfo, actionStore: MessageActionStore) {
        guard let nav = ChatUIKitNavigation.topNavigationController() else {
            readReceiptMessage = message
            readReceiptStore = actionStore
            showReadReceiptDetail = true
            return
        }
        let root = MessageListView.makeReadReceiptDetailView(
            message: message,
            actionStore: actionStore,
            onUserClick: { userID in onUserClick?(userID) }
        )
        .environmentObject(themeState)
        nav.pushViewController(UIHostingController(rootView: root), animated: true)
    }

    private var messageInputAreaView: some View {
        VStack(spacing: 0) {
            MessageInputView(
                conversationID: conversation.id,
                config: messageInputConfig
            )
        }
    }

    private func resolvedMessageListConfig() -> ChatMessageListConfig {
        var config = messageListConfig ?? ChatMessageListConfig(isShowRightAvatar: true)
        config.excludeCustomMessagesByBusinessID(MessageInputView.typingStatusBusinessID)
        return config
    }

}

enum ChatUIKitNavigation {
    static func topNavigationController() -> UINavigationController? {
        let root = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.rootViewController
        return deepestVisibleNavigationController(from: root)
    }

    private static func deepestVisibleNavigationController(from base: UIViewController?) -> UINavigationController? {
        if let nav = base as? UINavigationController {
            return deepestVisibleNavigationController(from: nav.visibleViewController) ?? nav
        }
        if let presented = base?.presentedViewController {
            return deepestVisibleNavigationController(from: presented)
        }
        for child in base?.children ?? [] {
            if let found = deepestVisibleNavigationController(from: child) {
                return found
            }
        }
        return nil
    }
}

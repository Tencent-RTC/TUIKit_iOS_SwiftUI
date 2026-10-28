import TUIChatKit_Swift
import AtomicXCore
import ImSDK_Plus
import SwiftUI
import UIKit

public struct HomePage: View {
    @EnvironmentObject var themeState: ThemeState
    @EnvironmentObject var appStyleSettings: AppStyleSettings
    @EnvironmentObject var languageState: LanguageState
    @Environment(\.layoutDirection) private var layoutDirection
    @StateObject private var homeToast = Toast()
    @State private var selectedTab: Tab = .chats
    @StateObject private var storeHolder = HomePageStoreHolder()
    @State private var totalUnreadCount: UInt = 0
    @State private var friendApplicationUnreadCount: Int = 0
    @State private var groupApplicationUnreadCount: Int = 0

    @State private var showChatPage: Bool = false
    @State private var showC2CChatSetting: Bool = false

    @State private var currentConversation: ConversationInfo? = nil
    @State private var currentLocateMessage: MessageInfo? = nil
    @State private var currentContactUser: AZOrderedListItem? = nil
    @State private var contactsHostViewController: UIViewController?
    @State private var chatsHostViewController: UIViewController?

    private var conversationListStore: ConversationListStore {
        storeHolder.conversationListStore
    }

    public init() {}

    private var chatsTab: some View {
        ConversationsPage(
            onConversationClick: { navigationInfo in
                pushChat(navigationInfo, from: chatsHostViewController)
            }
        )
        .background(ViewControllerBeacon { chatsHostViewController = $0 })
        .navigationTitle("")
        .navigationBarHidden(true)
        .tabItem {
            tabLabel(title: LocalizedChatString("TabChats"), baseName: "tab_chat", tab: .chats)
        }
        .tag(Tab.chats)
    }

    private func pushBadgeCounts() {
        TabBadgeManager.shared.updateCounts(
            message: totalUnreadCount,
            contacts: UInt(max(0, friendApplicationUnreadCount + groupApplicationUnreadCount))
        )
    }

    private var contactsTab: some View {
        ContactsPage(
            onContactClick: { user in
                pushContactChat(createConversationFromUser(user))
            },
            onGroupClick: { group in
                pushContactChat(createConversationFromGroup(group))
            }
        )
        .background(ViewControllerBeacon { contactsHostViewController = $0 })
        .tabItem {
            tabLabel(title: LocalizedChatString("TabContacts"), baseName: "tab_contact", tab: .contacts)
        }
        .tag(Tab.contacts)
        .navigationTitle("")
        .navigationBarHidden(true)
    }

    private var settingsTab: some View {
        SettingsPage()
            .tabItem {
                tabLabel(title: LocalizedChatString("TabSettings"), baseName: "tab_setting", tab: .settings)
            }
            .tag(Tab.settings)
            .navigationTitle("")
            .navigationBarHidden(true)
    }

    public var body: some View {
        ZStack {
            TabView(selection: self.$selectedTab) {
                chatsTab
                contactsTab
                settingsTab
            }
            .id("TabView-\(themeState.currentTheme.mode)")
            .background(themeState.colors.bgColorOperate)
            .onAppear {
                updateTabBarAppearance()
            }
            .onChange(of: themeState.currentTheme.mode) { _ in
                updateTabBarAppearance()
            }
            .navigationBarHidden(true)
            .navigationTitle("")

            ZStack {
                if let conversation = currentConversation {
                    NavigationLink(
                        destination: ChatNavPage(
                            conversation: conversation,
                            locateMessage: currentLocateMessage,
                            onBack: {
                                dismissChatPage()
                            },
                            onContactDelete: {
                                dismissChatPage()
                            },
                            onGroupDelete: {
                                dismissChatPage()
                            },
                            onNavigateToChat: { newConversation in
                                // 关闭旧聊天与打开新聊天须在同一更新中完成，避免导航栈竞态。
                                dismissChatPage()
                                showChatPage(conversation: newConversation)
                            }
                        )
                        .navigationBarHidden(true),
                        isActive: $showChatPage
                    ) {
                        EmptyView()
                    }
                    .hidden()
                }

                if let contactUser = currentContactUser {
                    NavigationLink(
                        destination: C2CChatSettingView(
                            userID: contactUser.userID,
                            onSendMessageClick: {
                                let newConversation = createConversationFromUser(contactUser)
                                dismissContactDetail()
                                showChatPage(conversation: newConversation)
                            }
                        )
                        .navigationBarTitle(LocalizedChatString("ProfileDetails"), displayMode: .inline),
                        isActive: $showC2CChatSetting
                    ) {
                        EmptyView()
                    }
                    .hidden()
                }
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .accentColor(themeState.colors.buttonColorPrimaryDefault)
        .toast(homeToast)
        .id("HomePage-\(languageState.currentLanguage)")
        .onReceive(storeHolder.unreadCounter.$totalUnreadCount.receive(on: RunLoop.main)) { unreadCount in
            self.totalUnreadCount = unreadCount
            self.pushBadgeCounts()
        }
        .onReceive(ContactStore.shared.state.subscribe(StatePublisherSelector(keyPath: \ContactState.friendApplicationUnreadCount)).receive(on: RunLoop.main)) { count in
            self.friendApplicationUnreadCount = count
            self.pushBadgeCounts()
        }
        .onReceive(GroupStore.shared.state.subscribe(StatePublisherSelector(keyPath: \GroupState.unreadApplicationCount)).receive(on: RunLoop.main)) { count in
            self.groupApplicationUnreadCount = count
            self.pushBadgeCounts()
        }
        .onAppear {
            storeHolder.unreadCounter.refresh()
            conversationListStore.loadConversations(option: nil, completion: nil)
            ContactStore.shared.loadFriendApplications(completion: nil)
            GroupStore.shared.loadApplications(completion: nil)
        }
    }

    private func pushContactChat(_ conversation: ConversationInfo) {
        pushChat(NavigationInfo(conversation: conversation), from: contactsHostViewController)
    }

    private func pushChat(_ info: NavigationInfo, from hostViewController: UIViewController?) {
        guard let navigationController = hostViewController?.navigationController,
              let sourceController = navigationController.topViewController,
              !(sourceController is ContactChatHostingController),
              navigationController.transitionCoordinator == nil else { return }
        let returnToSource = { [weak navigationController, weak sourceController] in
            guard let navigationController = navigationController,
                  let sourceController = sourceController,
                  navigationController.viewControllers.contains(where: { $0 === sourceController }) else { return }
            navigationController.popToViewController(sourceController, animated: true)
        }
        let root = NavigationView {
            ChatNavPage(
                conversation: info.conversation,
                locateMessage: info.locateMessage,
                onBack: returnToSource,
                onContactDelete: returnToSource,
                onGroupDelete: returnToSource,
                onNavigateToChat: nil
            )
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .environmentObject(themeState)
        .environmentObject(languageState)
        .environmentObject(appStyleSettings)
        .environment(\.layoutDirection, layoutDirection)
        .preferredColorScheme(themeState.isDarkMode ? .dark : .light)
        .accentColor(themeState.colors.buttonColorPrimaryDefault)
        .navigationBarHidden(true)
        let controller = ContactChatHostingController(rootView: AnyView(root))
        controller.hidesBottomBarWhenPushed = true
        navigationController.pushViewController(controller, animated: true)
    }

    private func showChatPage(conversation: ConversationInfo, locateMessage: MessageInfo? = nil) {
        currentConversation = conversation
        currentLocateMessage = locateMessage
        showChatPage = true
    }

    private func updateTabBarAppearance() {
        let titleFont = UIKitFontScheme.caption4Regular
        let tertiary = UIColor(themeState.colors.textColorTertiary)
        let link = UIColor(themeState.colors.textColorLink)
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = UIColor(themeState.colors.bgColorTopBar)
        appearance.shadowColor = .clear
        appearance.selectionIndicatorTintColor = .clear
        let itemAppearances = [
            appearance.stackedLayoutAppearance,
            appearance.inlineLayoutAppearance,
            appearance.compactInlineLayoutAppearance
        ]
        for itemAppearance in itemAppearances {
            itemAppearance.normal.titleTextAttributes = [.foregroundColor: tertiary, .font: titleFont]
            itemAppearance.selected.titleTextAttributes = [.foregroundColor: link, .font: titleFont]
        }
        UITabBar.appearance().isTranslucent = false
        UITabBar.appearance().tintColor = link
        UITabBar.appearance().unselectedItemTintColor = tertiary
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        DispatchQueue.main.async {
            self.renderTabIcons()
        }
    }

    private static let tabIconSize: CGFloat = 24
    private static let tabIconGradientStart = CGPoint(x: 0.66, y: -0.33)
    private static let tabIconGradientEnd = CGPoint(x: -0.24, y: 0.6875)
    private func renderTabIcons() {
        guard let tabBarController = findTabBarController() else { return }
        TabBadgeManager.shared.attach(tabBarController: tabBarController, contactsTabIndex: 1, conversationListStore: conversationListStore) {
            selectedTab = .chats
        }
    }

    private func tabLabel(title: String, baseName: String, tab: Tab) -> some View {
        Label {
            Text(title)
        } icon: {
            if let image = renderTabIcon(baseName: baseName, cutoutName: tab == .chats ? "tab_chat_lines" : nil, selected: selectedTab == tab) {
                Image(uiImage: image).renderingMode(.original)
            } else {
                Image(baseName)
            }
        }
        .transaction { $0.animation = nil }
    }

    private func findTabBarController() -> UITabBarController? {
        if let tabBarController = chatsHostViewController?.tabBarController { return tabBarController }
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else { return nil }
        var queue: [UIViewController] = [root]
        while !queue.isEmpty {
            let vc = queue.removeFirst()
            if let tab = vc as? UITabBarController { return tab }
            queue.append(contentsOf: vc.children)
            if let presented = vc.presentedViewController { queue.append(presented) }
        }
        return nil
    }

    private func renderTabIcon(baseName: String, cutoutName: String?, selected: Bool) -> UIImage? {
        let colors = themeState.colors
        let key = HomeTabIconKey(
            baseName: baseName, cutoutName: cutoutName, selected: selected,
            normal: UIColor(colors.textColorTertiary), gradient: UIColor(colors.bgColorBubbleOwn),
            selectedColor: UIColor(colors.textColorLink), background: UIColor(colors.bgColorBottomBar),
            scale: UIScreen.main.scale
        )
        if let image = storeHolder.tabIcons[key] { return image }
        guard let base = UIImage(named: baseName)?.cgImage else { return nil }
        let size = CGSize(width: Self.tabIconSize, height: Self.tabIconSize)
        let fill: UIImage
        if selected {
            fill = gradientFillImage(size: size, colors: [UIColor(colors.bgColorBubbleOwn).cgColor, UIColor(colors.textColorLink).cgColor])
        } else {
            fill = solidFillImage(size: size, color: UIColor(colors.textColorTertiary))
        }
        var image = maskedImage(fill: fill, mask: base, size: size)
        if let cutoutName = cutoutName, let cutout = UIImage(named: cutoutName)?.cgImage {
            let cutoutFill = solidFillImage(size: size, color: UIColor(colors.bgColorBottomBar))
            let cutoutImage = maskedImage(fill: cutoutFill, mask: cutout, size: size)
            image = compositeImage(bottom: image, top: cutoutImage, size: size)
        }
        let rendered = image.withRenderingMode(.alwaysOriginal)
        storeHolder.tabIcons[key] = rendered
        return rendered
    }

    private func solidFillImage(size: CGSize, color: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    private func gradientFillImage(size: CGSize, colors: [CGColor]) -> UIImage {
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = CGRect(origin: .zero, size: size)
        gradientLayer.colors = colors
        gradientLayer.startPoint = Self.tabIconGradientStart
        gradientLayer.endPoint = Self.tabIconGradientEnd
        return UIGraphicsImageRenderer(size: size).image { context in
            gradientLayer.render(in: context.cgContext)
        }
    }

    private func maskedImage(fill: UIImage, mask: CGImage, size: CGSize) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { context in
            let cgContext = context.cgContext
            cgContext.translateBy(x: 0, y: size.height)
            cgContext.scaleBy(x: 1, y: -1)
            let rect = CGRect(origin: .zero, size: size)
            cgContext.clip(to: rect, mask: mask)
            if let fillImage = fill.cgImage {
                cgContext.draw(fillImage, in: rect)
            }
        }
    }

    private func compositeImage(bottom: UIImage, top: UIImage, size: CGSize) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { _ in
            bottom.draw(in: CGRect(origin: .zero, size: size))
            top.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    private func showC2CChatSetting(    _ user: AZOrderedListItem) {
        currentContactUser = user
        showC2CChatSetting = true
    }

    private func dismissChatPage() {
        showChatPage = false
    }

    private func dismissContactDetail() {
        showC2CChatSetting = false
    }

    private func createConversationFromUser(_ user: AZOrderedListItem) -> ConversationInfo {
        var conversation = ConversationInfo(conversationID: ChatUtil.getC2CConversationID(user.id))
        conversation.avatarURL = user.avatarURL
        conversation.type = .c2c
        conversation.title = user.title ?? user.id
        return conversation
    }

    private func createConversationFromGroup(_ group: AZOrderedListItem) -> ConversationInfo {
        var conversation = ConversationInfo(conversationID: ChatUtil.getGroupConversationID(group.id))
        conversation.avatarURL = group.avatarURL
        conversation.type = .group
        conversation.title = group.title ?? group.id
        return conversation
    }


}

private final class ContactChatHostingController: UIHostingController<AnyView> {
    private var previousNavigationBarHidden: Bool?

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard let navigationController = navigationController else { return }
        if previousNavigationBarHidden == nil {
            previousNavigationBarHidden = navigationController.isNavigationBarHidden
        }
        navigationController.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        guard let navigationController = navigationController,
              let previousNavigationBarHidden = previousNavigationBarHidden else { return }
        navigationController.setNavigationBarHidden(previousNavigationBarHidden, animated: animated)
        self.previousNavigationBarHidden = nil
    }
}

    enum Tab {
        case chats, contacts, settings
    }


private final class TabUnreadBadgeView: UIView {
    private static let bubbleHeight: CGFloat = 16
    private static let bubbleMinWidth: CGFloat = 16
    private static let bubbleTextHorizontalPadding = CGFloat(SpacingScheme.iconTextSpacing)
    private static let touchAreaSize: CGFloat = 44
    private static let touchSlop: CGFloat = 6

    private let bubbleView = UIView()
    private let textLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: CGRect(x: 0, y: 0, width: Self.touchAreaSize, height: Self.touchAreaSize))
        bubbleView.backgroundColor = UIColor(ThemeState.shared.colors.textColorError)
        bubbleView.layer.cornerRadius = CGFloat(RadiusScheme.smallRadius)
        bubbleView.layer.masksToBounds = true
        textLabel.textColor = UIColor(ThemeState.shared.colors.textColorButton)
        textLabel.font = UIKitFontScheme.caption4Medium
        textLabel.textAlignment = .center
        addSubview(bubbleView)
        bubbleView.addSubview(textLabel)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard !isHidden, alpha > 0.01, isUserInteractionEnabled else { return nil }
        let hotFrame = bubbleView.frame.insetBy(dx: -Self.touchSlop, dy: -Self.touchSlop)
        return hotFrame.contains(point) ? self : nil
    }

    func setText(_ text: String) {
        guard textLabel.text != text else { return }
        textLabel.text = text
        textLabel.sizeToFit()
        let bubbleWidth = max(Self.bubbleMinWidth, textLabel.bounds.width + Self.bubbleTextHorizontalPadding * 2)
        bubbleView.frame = CGRect(
            x: (bounds.width - bubbleWidth) / 2,
            y: (bounds.height - Self.bubbleHeight) / 2,
            width: bubbleWidth,
            height: Self.bubbleHeight
        )
        textLabel.frame = bubbleView.bounds
    }
}

@MainActor
private enum HomeUnreadClearer {
    static func clear(using store: ConversationListStore) async throws {
        let markedStore = ConversationListStore.create()
        var option = ConversationLoadOption()
        option.markType = .unread
        try await perform { markedStore.loadConversations(option: option, completion: $0) }
        while markedStore.state.value.hasMoreConversations {
            let previousIDs = Set(markedStore.state.value.conversationList.map { $0.conversationID })
            try await perform { markedStore.loadMoreConversations(completion: $0) }
            let currentIDs = Set(markedStore.state.value.conversationList.map { $0.conversationID })
            if markedStore.state.value.hasMoreConversations, currentIDs == previousIDs {
                throw ErrorInfo(code: -1, message: "Unread conversation pagination did not advance")
            }
        }
        let markedIDs = Array(Set(markedStore.state.value.conversationList
            .filter { $0.conversationMarkList.contains(.unread) }
            .map { $0.conversationID }))
        let affectedIDs = Set(markedIDs + store.state.value.conversationList
            .filter { $0.unreadCount > 0 }
            .map { $0.conversationID })
        try await perform { store.clearConversationUnreadCount(conversationID: "", completion: $0) }
        for start in stride(from: 0, to: markedIDs.count, by: 100) {
            let batch = Array(markedIDs[start..<min(start + 100, markedIDs.count)])
            try await perform {
                store.markConversation(conversationIDList: batch, markType: .unread, enable: false, completion: $0)
            }
        }
        for conversationID in affectedIDs {
            NotificationCenter.default.post(
                name: Notification.Name("ChatConversationUnreadDidClear"),
                object: nil,
                userInfo: ["conversationID": conversationID]
            )
        }
    }

    private static func perform(_ operation: (@escaping CompletionClosure) -> Void) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            operation { continuation.resume(with: $0.mapError { $0 as Error }) }
        }
    }
}

private final class TabBadgeOverlayView: UIView {
    weak var tabBar: UITabBar?

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard !isHidden, alpha > 0.01, isUserInteractionEnabled,
              let tabBar = tabBar, tabBar.window != nil else { return nil }
        var ancestor: UIView? = tabBar
        while let view = ancestor {
            if view.isHidden || view.alpha <= 0.01 { return nil }
            ancestor = view.superview
        }
        for badge in subviews.reversed() {
            if let hit = badge.hitTest(badge.convert(point, from: self), with: event) { return hit }
        }
        return nil
    }
}

private final class TabBadgeManager: NSObject, UIGestureRecognizerDelegate {
    static let shared = TabBadgeManager()

    private static let badgeVerticalOffset: CGFloat = 4
    private static let tabBarContentTopInset = CGFloat(SpacingScheme.smallSpacing)
    private static let tabIconSize: CGFloat = 24
    private static let badgeClearDragThreshold: CGFloat = 48
    private static let badgePressScale: CGFloat = 1.08
    private static let badgeDragMaxScaleGain: CGFloat = 0.2
    private static let badgeClearEndScale: CGFloat = 0.6
    private static let badgeClearFlyDistanceFactor: CGFloat = 1.5
    private static let badgePressAnimationDuration: TimeInterval = 0.12
    private static let badgeDragAnimationDuration: TimeInterval = 0.18

    private let messageBadge = TabUnreadBadgeView()
    private let contactsBadge = TabUnreadBadgeView()
    private weak var tabBar: UITabBar?
    private var conversationListStore: ConversationListStore?
    private var messageCount: UInt = 0
    private var contactsCount: UInt = 0
    private var itemCount = 0
    private var contactsTabIndex = 1
    private var isDraggingMessageBadge = false
    private var isClearingUnread = false
    private var isMessageBadgeGestureInstalled = false
    private let overlay = TabBadgeOverlayView()
    private var onMessageBadgeTap: (() -> Void)?
    private var tabBarObservations: [NSKeyValueObservation] = []

    func attach(tabBarController: UITabBarController, contactsTabIndex: Int, conversationListStore: ConversationListStore, onMessageBadgeTap: @escaping () -> Void) {
        TabBarLayoutHook.install()
        let tabBar = tabBarController.tabBar
        self.contactsTabIndex = contactsTabIndex
        self.conversationListStore = conversationListStore
        self.onMessageBadgeTap = onMessageBadgeTap
        itemCount = tabBar.items?.count ?? 0
        if self.tabBar !== tabBar {
            messageBadge.isHidden = true
            messageBadge.isAccessibilityElement = true
            messageBadge.accessibilityIdentifier = "demo_message_tab_unread"
            contactsBadge.isHidden = true
            overlay.addSubview(messageBadge)
            overlay.addSubview(contactsBadge)
            overlay.tabBar = tabBar
            self.tabBar = tabBar
            tabBarObservations = [
                tabBar.observe(\.isHidden) { [weak self] _, _ in self?.syncOverlayVisibility() },
                tabBar.observe(\.alpha) { [weak self] _, _ in self?.syncOverlayVisibility() },
                tabBar.observe(\.center) { [weak self] _, _ in self?.syncOverlayVisibility() }
            ]
        }
        if !isMessageBadgeGestureInstalled {
            isMessageBadgeGestureInstalled = true
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handleMessageBadgePan(_:)))
            pan.delegate = self
            messageBadge.addGestureRecognizer(pan)
            let tap = UITapGestureRecognizer(target: self, action: #selector(handleMessageBadgeTap(_:)))
            tap.require(toFail: pan)
            messageBadge.addGestureRecognizer(tap)
            contactsBadge.isUserInteractionEnabled = false
        }
        relayout()
    }

    @objc private func handleMessageBadgeTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended, !isClearingUnread else { return }
        onMessageBadgeTap?()
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return otherGestureRecognizer.view !== messageBadge
    }

    @objc private func handleMessageBadgePan(_ gesture: UIPanGestureRecognizer) {
        guard let tabBar = tabBar else { return }
        switch gesture.state {
        case .began:
            isDraggingMessageBadge = true
            messageBadge.layer.removeAllAnimations()
            UIView.animate(withDuration: Self.badgePressAnimationDuration) {
                self.messageBadge.transform = CGAffineTransform(scaleX: Self.badgePressScale, y: Self.badgePressScale)
            }
        case .changed:
            let translation = gesture.translation(in: tabBar)
            let dragUpDistance = max(0, -translation.y)
            let progress = min(dragUpDistance / Self.badgeClearDragThreshold, 1)
            let scale = 1 + progress * Self.badgeDragMaxScaleGain
            messageBadge.transform = CGAffineTransform(translationX: translation.x, y: -dragUpDistance)
                .scaledBy(x: scale, y: scale)
        case .ended:
            let translation = gesture.translation(in: tabBar)
            isDraggingMessageBadge = false
            if -translation.y >= Self.badgeClearDragThreshold {
                clearAllUnreadByBadgeDrag()
            } else {
                resetMessageBadgeDrag()
            }
        case .cancelled, .failed:
            isDraggingMessageBadge = false
            resetMessageBadgeDrag()
        default:
            break
        }
    }

    private func resetMessageBadgeDrag() {
        messageBadge.layer.removeAllAnimations()
        UIView.animate(withDuration: Self.badgeDragAnimationDuration) {
            self.messageBadge.transform = .identity
            self.messageBadge.alpha = 1
        }
    }

    private func clearAllUnreadByBadgeDrag() {
        guard !isClearingUnread, let store = conversationListStore else {
            resetMessageBadgeDrag()
            return
        }
        isClearingUnread = true
        messageBadge.isUserInteractionEnabled = false
        let flyDistance = Self.badgeClearDragThreshold * Self.badgeClearFlyDistanceFactor
        UIView.animate(withDuration: Self.badgeDragAnimationDuration, animations: {
            self.messageBadge.transform = CGAffineTransform(translationX: 0, y: -flyDistance)
                .scaledBy(x: Self.badgeClearEndScale, y: Self.badgeClearEndScale)
            self.messageBadge.alpha = 0
        }) { _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                defer {
                    self.isClearingUnread = false
                    self.messageBadge.isUserInteractionEnabled = true
                    self.resetMessageBadgeDrag()
                    self.relayout()
                }
                do {
                    try await HomeUnreadClearer.clear(using: store)
                    guard self.conversationListStore === store else { return }
                    WindowToastManager.shared.success(LocalizedChatString("ClearAllUnreadSuccess"))
                } catch {
                    guard self.conversationListStore === store else { return }
                    let description = (error as? ErrorInfo)?.message ?? ""
                    WindowToastManager.shared.error(description.isEmpty ? LocalizedChatString("TipsSystemError") : description)
                }
            }
        }
    }

    func handleTabBarLayout(_ tabBar: UITabBar) {
        guard self.tabBar === tabBar else { return }
        relayout()
    }

    func updateCounts(message: UInt, contacts: UInt) {
        messageCount = message
        contactsCount = contacts
        relayout()
    }

    private func syncOverlayVisibility() {
        guard let tabBar = tabBar, let host = overlay.superview else { return }
        let wasHidden = overlay.isHidden
        overlay.isHidden = tabBar.isHidden || tabBar.alpha <= 0.01
            || !host.bounds.intersects(tabBar.convert(tabBar.bounds, to: host))
        if wasHidden, !overlay.isHidden { relayout() }
    }

    private func relayout() {
        guard tabBar != nil else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let tabBar = self.tabBar, let host = tabBar.superview else { return }
            self.itemCount = tabBar.items?.count ?? 0
            guard self.itemCount > 0, tabBar.bounds.width > 0, tabBar.bounds.height > 0 else { return }
            if self.overlay.superview !== host {
                self.overlay.removeFromSuperview()
                self.overlay.frame = host.bounds
                self.overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                host.addSubview(self.overlay)
            }
            self.syncOverlayVisibility()
            guard !self.overlay.isHidden else { return }
            if host.subviews.last !== self.overlay { host.bringSubviewToFront(self.overlay) }
            self.apply(self.messageBadge, count: self.messageCount, tabIndex: 0, in: tabBar)
            self.apply(self.contactsBadge, count: self.contactsCount, tabIndex: self.contactsTabIndex, in: tabBar)
        }
    }

    private func apply(_ badge: TabUnreadBadgeView, count: UInt, tabIndex: Int, in tabBar: UITabBar) {
        if badge === messageBadge && (isDraggingMessageBadge || isClearingUnread) { return }
        guard count > 0, let items = tabBar.items, items.indices.contains(tabIndex) else {
            if !badge.isHidden { badge.isHidden = true }
            return
        }
        let icon = iconFrame(tabIndex: tabIndex, in: tabBar)
        UIView.performWithoutAnimation {
            if badge === messageBadge {
                if badge.transform != .identity { badge.transform = .identity }
                if badge.alpha != 1 { badge.alpha = 1 }
            }
            badge.setText(count > 99 ? "99+" : "\(count)")
            let value = "\(count)"
            if badge.accessibilityValue != value { badge.accessibilityValue = value }
            if badge.isHidden { badge.isHidden = false }
            let isRTL = tabBar.effectiveUserInterfaceLayoutDirection == .rightToLeft
            let tabBarCenter = CGPoint(x: isRTL ? icon.minX : icon.maxX, y: icon.minY + Self.badgeVerticalOffset)
            let center = overlay.convert(tabBarCenter, from: tabBar)
            if badge.center != center { badge.center = center }
        }
    }

    private func iconFrame(tabIndex: Int, in tabBar: UITabBar) -> CGRect {
        let isRTL = tabBar.effectiveUserInterfaceLayoutDirection == .rightToLeft
        let visualIndex = isRTL ? itemCount - 1 - tabIndex : tabIndex
        var frames: [CGRect] = []
        collectIconFrames(in: tabBar, tabBar: tabBar, into: &frames)
        frames.sort { $0.midX < $1.midX }
        var distinctFrames: [CGRect] = []
        for frame in frames {
            if !distinctFrames.contains(where: { abs($0.midX - frame.midX) < 1 && abs($0.midY - frame.midY) < 1 }) {
                distinctFrames.append(frame)
            }
        }
        if distinctFrames.count == itemCount { return distinctFrames[visualIndex] }
        let contentWidth = max(0, tabBar.bounds.width - tabBar.safeAreaInsets.left - tabBar.safeAreaInsets.right)
        let tabWidth = contentWidth / CGFloat(itemCount)
        return CGRect(
            x: tabBar.bounds.minX + tabBar.safeAreaInsets.left + (CGFloat(visualIndex) + 0.5) * tabWidth - Self.tabIconSize / 2,
            y: tabBar.bounds.minY + Self.tabBarContentTopInset,
            width: Self.tabIconSize,
            height: Self.tabIconSize
        )
    }

    private func collectIconFrames(in view: UIView, tabBar: UITabBar, into frames: inout [CGRect]) {
        guard !view.isHidden, view.alpha > 0.01, !(view is TabUnreadBadgeView) else { return }
        if let imageView = view as? UIImageView, imageView.image != nil,
           abs(view.bounds.width - Self.tabIconSize) <= 8,
           abs(view.bounds.height - Self.tabIconSize) <= 8 {
            let frame = imageView.convert(imageView.bounds, to: tabBar)
            if tabBar.bounds.intersects(frame) { frames.append(frame) }
        }
        for child in view.subviews {
            collectIconFrames(in: child, tabBar: tabBar, into: &frames)
        }
    }
}

private enum TabBarLayoutHook {
    private static var installed = false

    static func install() {
        guard !installed else { return }
        installed = true
        guard let original = class_getInstanceMethod(UITabBar.self, #selector(UITabBar.layoutSubviews)),
              let swizzled = class_getInstanceMethod(UITabBar.self, #selector(UITabBar.tabBadge_layoutSubviews)) else { return }
        method_exchangeImplementations(original, swizzled)
    }
}

private extension UITabBar {
    @objc func tabBadge_layoutSubviews() {
        tabBadge_layoutSubviews()
        TabBadgeManager.shared.handleTabBarLayout(self)
    }
}


extension HomePage {
    static func checkIsFriend(userID: String, completion: @escaping (Bool) -> Void) {
        ContactStore.shared.getContactInfo(
            userIDList: [userID],
            completion: HomeContactInfoHandler(
                onSuccess: { contactInfoList in
                    completion(contactInfoList.first?.isFriend ?? false)
                },
                onFailure: { _, _ in
                    completion(false)
                }
            )
        )
    }
}

private struct HomeTabIconKey: Hashable {
    let baseName: String
    let cutoutName: String?
    let selected: Bool
    let normal: UIColor
    let gradient: UIColor
    let selectedColor: UIColor
    let background: UIColor
    let scale: CGFloat
}

// 保持 Store 随主页身份存活，避免重建时重复注册监听。
private final class HomePageStoreHolder: ObservableObject {
    let conversationListStore: ConversationListStore
    let unreadCounter = HomeUnreadCounter()
    var tabIcons: [HomeTabIconKey: UIImage] = [:]

    init() {
        self.conversationListStore = ConversationListStore.create()
    }
}

// 避免在 deinit 中把 self 交给 SDK 异步撤监听；代理随进程存活，仅弱引用计数器。
private final class HomeUnreadListenerProxy: NSObject, V2TIMConversationListener {
    static let shared = HomeUnreadListenerProxy()
    private let lock = NSLock()
    private weak var target: HomeUnreadCounter?
    private var generation = 0

    private override init() {
        super.init()
        V2TIMManager.sharedInstance().addConversationListener(listener: self)
    }

    func attach(_ target: HomeUnreadCounter) {
        lock.lock()
        generation += 1
        self.target = target
        lock.unlock()
    }

    func detach(_ target: HomeUnreadCounter) {
        lock.lock()
        if self.target === target {
            generation += 1
            self.target = nil
        }
        lock.unlock()
    }

    private func forward(_ action: @escaping (HomeUnreadCounter) -> Void) {
        lock.lock()
        let receiver = target
        let version = generation
        lock.unlock()
        guard let receiver = receiver else { return }
        DispatchQueue.main.async {
            self.lock.lock()
            let current = self.generation == version && self.target === receiver
            self.lock.unlock()
            guard current else { return }
            action(receiver)
        }
    }

    func onNewConversation(conversationList: [V2TIMConversation]) {
        forward { $0.onNewConversation(conversationList: conversationList) }
    }

    func onConversationChanged(conversationList: [V2TIMConversation]) {
        forward { $0.onConversationChanged(conversationList: conversationList) }
    }

    func onConversationDeleted(conversationIDList: [String]) {
        forward { $0.onConversationDeleted(conversationIDList: conversationIDList) }
    }

    func onTotalUnreadMessageCountChanged(totalUnreadCount: UInt64) {
        forward { $0.onTotalUnreadMessageCountChanged(totalUnreadCount: totalUnreadCount) }
    }

    func onSyncServerFinish() {
        forward { $0.onSyncServerFinish() }
    }
}

private final class HomeUnreadCounter: NSObject, ObservableObject {
    @Published private(set) var totalUnreadCount: UInt = 0
    private var refreshTask: Task<Void, Never>?
    private var session = 0
    private var accountID: String?
    private var sdkCount: Int64 = 0
    private var sdkCountRevision = 0
    private var snapshots: [String: Snapshot] = [:]
    private var pendingChanges: [String: Snapshot] = [:]
    private var pendingDeletes: Set<String> = []
    private var eventSequence = 0
    private var eventRevisions: [String: Int] = [:]
    private var needsFullRefresh = false
    private var didLoadSnapshot = false
    private var operationSequence = 0
    private var pendingChecks: [String: MarkCheck] = [:]
    private var observers: [NSObjectProtocol] = []
    private var isActive = true

    private struct MarkCheck {
        let enabled: Bool?
        let sequence: Int
    }

    private struct Snapshot {
        let count: Int64
        let contributes: Bool
        let markedUnread: Bool
        let excluded: Bool
        let allowsManualUnread: Bool

        init(_ conversation: V2TIMConversation) {
            count = Int64(max(0, conversation.unreadCount))
            let option = conversation.recvOpt.rawValue
            contributes = option != 1 && option != 2 && option != 3
            allowsManualUnread = contributes || (conversation.groupType == GroupType.meeting.rawValue && option == 2)
            let marks = conversation.markList?.reduce(Int64(0)) { $0 | $1.int64Value } ?? 0
            markedUnread = marks & ConversationMarkType.unread.rawValue != 0
            excluded = marks & (ConversationMarkType.hide.rawValue | ConversationMarkType.fold.rawValue) != 0
        }
    }

    override init() {
        super.init()
        HomeUnreadListenerProxy.shared.attach(self)
        for name in ["ChatConversationUnreadDidClear", "ChatConversationUnreadMarkDidChange"] {
            observers.append(NotificationCenter.default.addObserver(
                forName: Notification.Name(name), object: nil, queue: .main
            ) { [weak self] notification in
                guard let self = self else { return }
                if let id = notification.userInfo?["conversationID"] as? String {
                    self.checkConversation(id, enabled: notification.userInfo?["enabled"] as? Bool)
                } else {
                    self.refresh()
                }
            })
        }
        for name in ["ChatDemoWillLogout", "ChatDemoLogoutFailed"] {
            observers.append(NotificationCenter.default.addObserver(
                forName: Notification.Name(name), object: nil, queue: .main
            ) { [weak self] notification in
                if notification.name.rawValue == "ChatDemoWillLogout" {
                    self?.stop()
                } else {
                    self?.resume()
                }
            })
        }
    }

    deinit {
        refreshTask?.cancel()
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    private func stop() {
        guard isActive else { return }
        isActive = false
        HomeUnreadListenerProxy.shared.detach(self)
        session += 1
        refreshTask?.cancel()
        refreshTask = nil
        accountID = nil
        sdkCount = 0
        sdkCountRevision = 0
        snapshots.removeAll()
        pendingChanges.removeAll()
        pendingDeletes.removeAll()
        pendingChecks.removeAll()
        eventRevisions.removeAll()
        didLoadSnapshot = false
        needsFullRefresh = false
        totalUnreadCount = 0
    }

    private func resume() {
        guard !isActive else { return }
        isActive = true
        HomeUnreadListenerProxy.shared.attach(self)
        refresh()
    }

    func refresh() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.ensureAccount() else { return }
            self.needsFullRefresh = true
            self.startRefreshIfNeeded()
        }
    }

    private func ensureAccount() -> Bool {
        guard isActive else { return false }
        let userID = LoginStore.shared.state.value.loginUserInfo?.userID
        if userID != accountID {
            session += 1
            refreshTask?.cancel()
            refreshTask = nil
            accountID = userID
            sdkCount = 0
            sdkCountRevision = 0
            snapshots.removeAll()
            pendingChanges.removeAll()
            pendingDeletes.removeAll()
            pendingChecks.removeAll()
            eventRevisions.removeAll()
            didLoadSnapshot = false
            needsFullRefresh = false
            totalUnreadCount = 0
        }
        return userID?.isEmpty == false
    }

    private func publishCount() {
        var manualCount = 0
        var excludedCount: Int64 = 0
        for snapshot in snapshots.values {
            if snapshot.allowsManualUnread && snapshot.markedUnread && !snapshot.excluded && (!snapshot.contributes || snapshot.count == 0) {
                manualCount += 1
            }
            if snapshot.contributes && snapshot.excluded {
                excludedCount += snapshot.count
            }
        }
        let count = UInt(max(0, sdkCount + Int64(manualCount) - excludedCount))
        if totalUnreadCount != count { totalUnreadCount = count }
    }

    private func applyChanges(_ changes: [String: Snapshot]) {
        for (id, snapshot) in changes {
            snapshots[id] = snapshot
            pendingChanges[id] = snapshot
            pendingDeletes.remove(id)
            eventSequence += 1
            eventRevisions[id] = eventSequence
        }
        publishCount()
    }

    private func checkConversation(_ id: String, enabled: Bool?) {
        guard ensureAccount() else { return }
        if enabled == nil, pendingChecks[id] != nil { return }
        operationSequence += 1
        pendingChecks[id] = MarkCheck(enabled: enabled, sequence: operationSequence)
        startRefreshIfNeeded()
    }

    private func startRefreshIfNeeded() {
        guard refreshTask == nil else { return }
        let currentSession = session
        refreshTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            defer {
                if self.session == currentSession {
                    self.refreshTask = nil
                }
            }
            do {
                try await Task.sleep(nanoseconds: 100_000_000)
                while self.session == currentSession && (self.needsFullRefresh || !self.pendingChecks.isEmpty || !self.didLoadSnapshot) {
                    try Task.checkCancellation()
                    guard self.ensureAccount(), self.session == currentSession else { return }
                    if self.needsFullRefresh || !self.didLoadSnapshot {
                        self.needsFullRefresh = false
                        var fetched: [String: Snapshot] = [:]
                        for mark in [ConversationMarkType.unread, .hide, .fold] {
                            fetched.merge(try await self.fetchMarkedConversations(mark)) { _, latest in latest }
                            try Task.checkCancellation()
                        }
                        let baseRevision = self.sdkCountRevision
                        let count = try await self.fetchTotalUnreadCount()
                        try Task.checkCancellation()
                        guard self.session == currentSession, self.ensureAccount() else { return }
                        if self.sdkCountRevision == baseRevision { self.sdkCount = count }
                        fetched.merge(self.pendingChanges) { _, event in event }
                        self.pendingDeletes.forEach { fetched.removeValue(forKey: $0) }
                        self.snapshots = fetched
                        self.didLoadSnapshot = true
                        self.publishCount()
                    }
                    let checks = self.pendingChecks
                    for (id, check) in checks {
                        for attempt in 0..<3 {
                            let eventRevision = self.eventRevisions[id]
                            let conversation = try await self.fetchConversation(id)
                            try Task.checkCancellation()
                            guard self.session == currentSession, self.ensureAccount() else { return }
                            guard self.pendingChecks[id]?.sequence == check.sequence else { break }
                            if self.eventRevisions[id] != eventRevision {
                                if let latest = self.snapshots[id], check.enabled == nil || latest.markedUnread == check.enabled {
                                    self.pendingChecks.removeValue(forKey: id)
                                    break
                                }
                                continue
                            }
                            let snapshot = Snapshot(conversation)
                            if check.enabled == nil || snapshot.markedUnread == check.enabled {
                                self.applyChanges([id: snapshot])
                                self.pendingChecks.removeValue(forKey: id)
                                break
                            }
                            if attempt == 2 {
                                self.pendingChecks.removeValue(forKey: id)
                                print("Unread mark confirmation did not converge")
                            } else {
                                try await Task.sleep(nanoseconds: 150_000_000)
                            }
                        }
                    }
                    if !checks.isEmpty {
                        let baseRevision = self.sdkCountRevision
                        let count = try await self.fetchTotalUnreadCount()
                        try Task.checkCancellation()
                        guard self.session == currentSession, self.ensureAccount() else { return }
                        if self.sdkCountRevision == baseRevision { self.sdkCount = count }
                        self.publishCount()
                    }
                }
            } catch {
                if !Task.isCancelled { print("Unread count refresh failed: \(error)") }
            }
        }
    }

    @MainActor
    private func fetchConversation(_ id: String) async throws -> V2TIMConversation {
        try await withCheckedThrowingContinuation { continuation in
            V2TIMManager.sharedInstance().getConversation(conversationID: id) { conversation in
                guard let conversation = conversation else {
                    continuation.resume(throwing: ErrorInfo(code: -1, message: "Unread conversation query returned no data"))
                    return
                }
                continuation.resume(returning: conversation)
            } fail: { code, desc in
                continuation.resume(throwing: ErrorInfo(code: Int(code), message: desc ?? ""))
            }
        }
    }

    @MainActor
    private func fetchMarkedConversations(_ mark: ConversationMarkType) async throws -> [String: Snapshot] {
        let filter = V2TIMConversationListFilter()
        filter.markType = UInt(mark.rawValue)
        var cursor: UInt64 = 0
        var snapshots: [String: Snapshot] = [:]
        while true {
            try Task.checkCancellation()
            let page: ([V2TIMConversation], UInt64, Bool) = try await withCheckedThrowingContinuation { continuation in
                V2TIMManager.sharedInstance().getConversationListByFilter(filter: filter, nextSeq: cursor, count: 100) { list, nextSeq, finished in
                    guard let list = list else {
                        continuation.resume(throwing: ErrorInfo(code: -1, message: "Unread count query returned no data"))
                        return
                    }
                    continuation.resume(returning: (list, nextSeq, finished))
                } fail: { code, desc in
                    continuation.resume(throwing: ErrorInfo(code: Int(code), message: desc ?? ""))
                }
            }
            for conversation in page.0 {
                if let id = conversation.conversationID, !id.isEmpty {
                    snapshots[id] = Snapshot(conversation)
                }
            }
            if page.2 { return snapshots }
            guard page.1 != cursor else {
                throw ErrorInfo(code: -1, message: "Unread count pagination did not advance")
            }
            cursor = page.1
        }
    }

    @MainActor
    private func fetchTotalUnreadCount() async throws -> Int64 {
        try await withCheckedThrowingContinuation { continuation in
            V2TIMManager.sharedInstance().getTotalUnreadMessageCount { count in
                continuation.resume(returning: Int64(clamping: count))
            } fail: { code, desc in
                continuation.resume(throwing: ErrorInfo(code: Int(code), message: desc ?? ""))
            }
        }
    }

    private func receiveConversations(_ conversations: [V2TIMConversation]) {
        var changes: [String: Snapshot] = [:]
        for conversation in conversations {
            if let id = conversation.conversationID, !id.isEmpty { changes[id] = Snapshot(conversation) }
        }
        let currentSession = session
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.session == currentSession, self.ensureAccount() else { return }
            self.applyChanges(changes)
            if !self.didLoadSnapshot { self.startRefreshIfNeeded() }
        }
    }

    func onNewConversation(conversationList: [V2TIMConversation]) { receiveConversations(conversationList) }
    func onConversationChanged(conversationList: [V2TIMConversation]) { receiveConversations(conversationList) }
    func onConversationDeleted(conversationIDList: [String]) {
        let currentSession = session
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.session == currentSession, self.ensureAccount() else { return }
            for id in conversationIDList {
                self.snapshots.removeValue(forKey: id)
                self.pendingChanges.removeValue(forKey: id)
                self.pendingChecks.removeValue(forKey: id)
                self.pendingDeletes.insert(id)
                self.eventSequence += 1
                self.eventRevisions[id] = self.eventSequence
            }
            self.publishCount()
        }
    }
    func onTotalUnreadMessageCountChanged(totalUnreadCount: UInt64) {
        let currentSession = session
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.session == currentSession, self.ensureAccount() else { return }
            self.sdkCountRevision += 1
            let count = Int64(clamping: totalUnreadCount)
            if self.sdkCount != count {
                self.sdkCount = count
                self.publishCount()
            }
        }
    }
    func onSyncServerFinish() { refresh() }
}

private final class HomeContactInfoHandler: GetContactInfoCompletionHandler {
    private let onSuccessBlock: ([ContactInfo]) -> Void
    private let onFailureBlock: (Int, String) -> Void

    init(onSuccess: @escaping ([ContactInfo]) -> Void, onFailure: @escaping (Int, String) -> Void) {
        self.onSuccessBlock = onSuccess
        self.onFailureBlock = onFailure
    }

    func onSuccess(contactInfoList: [ContactInfo]) {
        onSuccessBlock(contactInfoList)
    }

    func onFailure(code: Int, desc: String) {
        onFailureBlock(code, desc)
    }
}

import AtomicXCore
import TUIChatKit_Swift
import RTCRoomEngine
import SwiftUI
import UIKit
import ObjectiveC
import TUICallKit_Swift

enum MiniTestAccount {
    static let userID = "test1"
    static let c2cChatUserID = "test2"
    static let chatGroupID = "testGroup"

    static var userSig: String {
        GenerateTestUserSig.genTestUserSig(identifier: userID)
    }
}

@main
struct ChatDemoMiniApp: App {
    init() {
        CustomLinkMessageManager.register()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @StateObject private var themeState = ThemeState.shared
    @StateObject private var languageState = LanguageState()
    @State private var didLogin = false

    var body: some View {
        NavigationView {
            HomePage()
                .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .environmentObject(themeState)
        .environmentObject(languageState)
        .preferredColorScheme(preferredColorScheme)
        .onAppear {
            login()
            InteractivePopGestureEnabler.shared.scheduleInstall()
        }
    }

    private var preferredColorScheme: ColorScheme? {
        switch themeState.currentMode {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            return themeState.isDarkMode ? .dark : .light
        }
    }

    private func login() {
        guard !didLogin else { return }
        didLogin = true
        LoginStore.shared.login(sdkAppID: GenerateTestUserSig.sdkAppID, userID: MiniTestAccount.userID, userSig: MiniTestAccount.userSig) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    MiniCallService.initEngine()
                case .failure(let error):
                    print("login failed: \(error.code) \(error.message)")
                }
            }
        }
    }
}

enum MiniCallService {
    static func initEngine() {
        TUICallEngine.createInstance().`init`(GenerateTestUserSig.sdkAppID, userId: MiniTestAccount.userID, userSig: MiniTestAccount.userSig) {
            TUICallEngine.createInstance().enableMultiDeviceAbility(enable: true) {
            } fail: { code, message in
                print("enableMultiDeviceAbility failed: \(code), \(message ?? "")")
            }
            TUICallKit.createInstance().enableIncomingBanner(enable: true)
        } fail: { code, message in
            print("initCallEngine failed: \(code), \(message ?? "")")
        }
    }
}

struct HomePage: View {
    @EnvironmentObject var themeState: ThemeState

    @State private var showConversationList = false
    @State private var showContacts = false
    @State private var showChat = false
    @State private var currentConversation: ConversationInfo?

    var body: some View {
        ZStack {
            themeState.colors.bgColorOperate.ignoresSafeArea()
            VStack(spacing: CGFloat(SpacingScheme.bubbleSpacing)) {
                entryButton(title: NSLocalizedString("ShowConversationList", comment: "")) {
                    showConversationList = true
                }
                entryButton(title: NSLocalizedString("ShowC2CChat", comment: "")) {
                    var conversation = ConversationInfo(conversationID: ChatUtil.getC2CConversationID(MiniTestAccount.c2cChatUserID))
                    conversation.type = .c2c
                    conversation.title = "与 \(MiniTestAccount.c2cChatUserID) 聊天"
                    showDirectChat(conversation)
                }
                entryButton(title: NSLocalizedString("ShowGroupChat", comment: "")) {
                    var conversation = ConversationInfo(conversationID: ChatUtil.getGroupConversationID(MiniTestAccount.chatGroupID))
                    conversation.type = .group
                    conversation.title = "测试群：\(MiniTestAccount.chatGroupID)"
                    showDirectChat(conversation)
                }
                entryButton(title: NSLocalizedString("ShowContacts", comment: "")) {
                    showContacts = true
                }
                entryButton(title: NSLocalizedString("StartVideoCall", comment: "")) {
                    TUICallKit.createInstance().calls(userIdList: [MiniTestAccount.c2cChatUserID], mediaType: .video, params: nil, completion: nil)
                }
            }
            .padding(.horizontal, CGFloat(SpacingScheme.cardSpacing))

            NavigationLink(destination: ConversationsDestination().navigationBarHidden(true), isActive: $showConversationList) {
                EmptyView()
            }
            .hidden()
            NavigationLink(destination: ContactsDestination().navigationBarHidden(true), isActive: $showContacts) {
                EmptyView()
            }
            .hidden()
            if let conversation = currentConversation {
                NavigationLink(destination: MiniChatPage(conversation: conversation, onBack: { showChat = false }).navigationBarHidden(true), isActive: $showChat) {
                    EmptyView()
                }
                .hidden()
            }
        }
    }

    private func showDirectChat(_ conversation: ConversationInfo) {
        currentConversation = conversation
        showChat = true
    }

    private func entryButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(FontScheme.caption1Regular)
                .foregroundColor(themeState.colors.textColorButton)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(themeState.colors.buttonColorPrimaryDefault)
                .cornerRadius(CGFloat(RadiusScheme.smallRadius))
        }
    }
}

private struct ConversationsDestination: View {
    @EnvironmentObject private var themeState: ThemeState
    @EnvironmentObject private var languageState: LanguageState
    @Environment(\.layoutDirection) private var layoutDirection
    @State private var hostViewController: UIViewController?

    var body: some View {
        ConversationsPage(onConversationClick: openChat)
            .background(MiniViewControllerBeacon { hostViewController = $0 })
    }

    private func openChat(_ info: NavigationInfo) {
        guard let navigationController = hostViewController?.navigationController,
              let sourceController = navigationController.topViewController,
              !(sourceController is MiniContactChatHostingController),
              navigationController.transitionCoordinator == nil else { return }
        let returnToSource = { [weak navigationController, weak sourceController] in
            guard let navigationController = navigationController,
                  let sourceController = sourceController,
                  navigationController.viewControllers.contains(where: { $0 === sourceController }) else { return }
            navigationController.popToViewController(sourceController, animated: true)
        }
        let root = NavigationView {
            MiniChatPage(conversation: info.conversation, locateMessage: info.locateMessage, onBack: returnToSource)
                .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .environmentObject(themeState)
        .environmentObject(languageState)
        .environment(\.layoutDirection, layoutDirection)
        .preferredColorScheme(themeState.isDarkMode ? .dark : .light)
        .navigationBarHidden(true)
        let controller = MiniContactChatHostingController(rootView: AnyView(root))
        controller.hidesBottomBarWhenPushed = true
        navigationController.pushViewController(controller, animated: true)
    }
}

private struct ContactsDestination: View {
    @EnvironmentObject private var themeState: ThemeState
    @EnvironmentObject private var languageState: LanguageState
    @Environment(\.layoutDirection) private var layoutDirection
    @State private var hostViewController: UIViewController?

    var body: some View {
        ContactsPage(
            onContactClick: { item in
                openChat(makeC2CConversation(item))
            },
            onGroupClick: { item in
                openChat(makeGroupConversation(item))
            }
        )
        .background(MiniViewControllerBeacon { hostViewController = $0 })
    }

    private func openChat(_ conversation: ConversationInfo) {
        guard let navigationController = hostViewController?.navigationController,
              let sourceController = navigationController.topViewController,
              !(sourceController is MiniContactChatHostingController),
              navigationController.transitionCoordinator == nil else { return }
        let returnToSource = { [weak navigationController, weak sourceController] in
            guard let navigationController = navigationController,
                  let sourceController = sourceController,
                  navigationController.viewControllers.contains(where: { $0 === sourceController }) else { return }
            navigationController.popToViewController(sourceController, animated: true)
        }
        let root = NavigationView {
            MiniChatPage(conversation: conversation, onBack: returnToSource)
                .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .environmentObject(themeState)
        .environmentObject(languageState)
        .environment(\.layoutDirection, layoutDirection)
        .preferredColorScheme(themeState.isDarkMode ? .dark : .light)
        .navigationBarHidden(true)
        let controller = MiniContactChatHostingController(rootView: AnyView(root))
        controller.hidesBottomBarWhenPushed = true
        navigationController.pushViewController(controller, animated: true)
    }

    private func makeC2CConversation(_ user: AZOrderedListItem) -> ConversationInfo {
        var conversation = ConversationInfo(conversationID: ChatUtil.getC2CConversationID(user.id))
        conversation.type = .c2c
        conversation.title = user.title ?? user.id
        conversation.avatarURL = user.avatarURL
        return conversation
    }

    private func makeGroupConversation(_ group: AZOrderedListItem) -> ConversationInfo {
        var conversation = ConversationInfo(conversationID: ChatUtil.getGroupConversationID(group.id))
        conversation.type = .group
        conversation.title = group.title ?? group.id
        conversation.avatarURL = group.avatarURL
        return conversation
    }
}

private struct MiniChatPage: View {
    let conversation: ConversationInfo
    var locateMessage: MessageInfo? = nil
    let onBack: () -> Void

    var body: some View {
        ChatPage(
            conversation: conversation,
            locateMessage: locateMessage,
            messageInputConfig: CustomLinkMessageManager.makeInputConfig(conversationID: conversation.conversationID),
            onBack: onBack
        )
    }
}

private final class MiniContactChatHostingController: UIHostingController<AnyView> {
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

private struct MiniViewControllerBeacon: UIViewRepresentable {
    let onFound: (UIViewController) -> Void

    func makeUIView(context: Context) -> BeaconView {
        BeaconView(onFound: onFound)
    }

    func updateUIView(_ uiView: BeaconView, context: Context) {}

    final class BeaconView: UIView {
        private let onFound: (UIViewController) -> Void

        init(onFound: @escaping (UIViewController) -> Void) {
            self.onFound = onFound
            super.init(frame: .zero)
            isHidden = true
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError() }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil else { return }
            var responder = next
            while let current = responder {
                if let controller = current as? UIViewController {
                    onFound(controller)
                    return
                }
                responder = current.next
            }
        }
    }
}

private final class PopGestureDelegateProxy: NSObject, UIGestureRecognizerDelegate {
    private weak var navigationController: UINavigationController?

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
        super.init()
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let navigationController = navigationController,
              navigationController.transitionCoordinator == nil,
              let root = navigationController.viewIfLoaded?.window?.rootViewController else { return false }
        return InteractivePopGestureEnabler.popOwner(in: root) === navigationController
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive event: UIEvent) -> Bool {
        true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        false
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        false
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        !(otherGestureRecognizer.delegate is PopGestureDelegateProxy)
    }
}

private final class InteractivePopGestureEnabler {
    static let shared = InteractivePopGestureEnabler()
    private static let installationDelay: TimeInterval = 0.15
    private static let installationRetries = 20
    private static var proxyKey: UInt8 = 0
    private static let appearanceHook: Void = {
        guard let original = class_getInstanceMethod(UIViewController.self, #selector(UIViewController.viewDidAppear(_:))),
              let replacement = class_getInstanceMethod(UIViewController.self, #selector(UIViewController.chatDemoPopViewDidAppear(_:))) else { return }
        method_exchangeImplementations(original, replacement)
    }()

    private var pendingTransitions = Set<ObjectIdentifier>()

    private init() {}

    func scheduleInstall() {
        _ = Self.appearanceHook
        install(remainingRetries: Self.installationRetries)
    }

    func refresh() {
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) where scene.activationState == .foregroundActive {
            for window in scene.windows where !window.isHidden {
                guard let root = window.rootViewController else { continue }
                Self.visibleNavigationControllers(in: root).forEach { install(on: $0) }
            }
        }
    }

    static func popOwner(in root: UIViewController) -> UINavigationController? {
        visibleNavigationControllers(in: root).last { $0.viewControllers.count > 1 }
    }

    private func install(remainingRetries: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.installationDelay) { [self] in
            refresh()
            if remainingRetries > 0 {
                install(remainingRetries: remainingRetries - 1)
            }
        }
    }

    private func install(on navigationController: UINavigationController, remainingRetries: Int = InteractivePopGestureEnabler.installationRetries) {
        guard let gesture = navigationController.interactivePopGestureRecognizer else { return }
        if let transition = navigationController.transitionCoordinator {
            let identifier = ObjectIdentifier(navigationController)
            guard pendingTransitions.insert(identifier).inserted else { return }
            let registered = transition.animate(alongsideTransition: nil) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.pendingTransitions.remove(identifier)
                    self?.refresh()
                }
            }
            if registered { return }
            pendingTransitions.remove(identifier)
            retryInstall(on: navigationController, remainingRetries: remainingRetries)
            return
        }
        guard gesture.state == .possible else {
            retryInstall(on: navigationController, remainingRetries: remainingRetries)
            return
        }
        let proxy: PopGestureDelegateProxy
        if let existing = objc_getAssociatedObject(gesture, &Self.proxyKey) as? PopGestureDelegateProxy {
            proxy = existing
        } else {
            proxy = PopGestureDelegateProxy(navigationController: navigationController)
            objc_setAssociatedObject(gesture, &Self.proxyKey, proxy, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        gesture.delegate = proxy
        gesture.isEnabled = true
    }

    private func retryInstall(on navigationController: UINavigationController, remainingRetries: Int) {
        guard remainingRetries > 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.installationDelay) { [weak self, weak navigationController] in
            guard let self = self,
                  let navigationController = navigationController,
                  let root = navigationController.viewIfLoaded?.window?.rootViewController,
                  Self.visibleNavigationControllers(in: root).contains(where: { $0 === navigationController }) else { return }
            self.install(on: navigationController, remainingRetries: remainingRetries - 1)
        }
    }

    private static func visibleNavigationControllers(in controller: UIViewController) -> [UINavigationController] {
        if let presented = controller.presentedViewController, !presented.isBeingDismissed {
            return visibleNavigationControllers(in: presented)
        }
        if let navigationController = controller as? UINavigationController {
            return [navigationController] + (navigationController.visibleViewController.map { visibleNavigationControllers(in: $0) } ?? [])
        }
        if let tabController = controller as? UITabBarController {
            return tabController.selectedViewController.map { visibleNavigationControllers(in: $0) } ?? []
        }
        return controller.children.reversed().filter {
            $0.viewIfLoaded?.window != nil && $0.viewIfLoaded?.isHidden == false
        }.lazy.map { visibleNavigationControllers(in: $0) }.first { !$0.isEmpty } ?? []
    }
}

private extension UIViewController {
    @objc func chatDemoPopViewDidAppear(_ animated: Bool) {
        chatDemoPopViewDidAppear(animated)
        DispatchQueue.main.async {
            InteractivePopGestureEnabler.shared.refresh()
        }
    }
}

import AtomicXCore
import TUIChatKit_Swift
import RTCRoomEngine
import SwiftUI
import TUICallKit_Swift
import UIKit

// 替换为自己的测试账号；正式环境的 UserSig 应由业务服务端签发。
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
        CustomLinkMessageManager.register()             // 注册示例自定义消息的摘要和气泡视图。
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
        .preferredColorScheme(themeState.isDarkMode ? .dark : .light)
        .onAppear {
            login()
        }
    }

    private func login() {
        guard !didLogin else { return }
        didLogin = true
        LoginStore.shared.login(sdkAppID: GenerateTestUserSig.sdkAppID, userID: MiniTestAccount.userID, userSig: MiniTestAccount.userSig) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    MiniCallService.initializeCall()     // 初始化通话能力。
                case .failure(let error):
                    print("login failed: \(error.code) \(error.message)")
                }
            }
        }
    }
}

enum MiniCallService {
    static func initializeCall() {
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

    var body: some View {
        ZStack {
            themeState.colors.bgColorOperate.ignoresSafeArea()
            VStack(spacing: CGFloat(SpacingScheme.bubbleSpacing)) {
                NavigationLink(destination: ConversationsDestination()) {
                    entryLabel(title: NSLocalizedString("ShowConversationList", comment: ""))
                }

                NavigationLink(destination: ChatPageDestination(conversation: makeTestC2CConversationInfo(), locateMessage: nil)) {
                    entryLabel(title: NSLocalizedString("ShowC2CChat", comment: ""))
                }

                NavigationLink(destination: ChatPageDestination(conversation: makeTestGroupConversationInfo(), locateMessage: nil)) {
                    entryLabel(title: NSLocalizedString("ShowGroupChat", comment: ""))
                }

                NavigationLink(destination: ContactsDestination()) {
                    entryLabel(title: NSLocalizedString("ShowContacts", comment: ""))
                }

                Button {
                    startVideoCall()
                } label: {
                    entryLabel(title: NSLocalizedString("StartVideoCall", comment: ""))
                }
            }
            .padding(.horizontal, CGFloat(SpacingScheme.cardSpacing))
        }
    }

    private func makeTestC2CConversationInfo() -> ConversationInfo {
        var conversation = ConversationInfo(
            conversationID: ChatUtil.getC2CConversationID(MiniTestAccount.c2cChatUserID)
        )
        conversation.type = .c2c
        conversation.title = "与 \(MiniTestAccount.c2cChatUserID) 聊天"
        return conversation
    }

    private func makeTestGroupConversationInfo() -> ConversationInfo {
        var conversation = ConversationInfo(
            conversationID: ChatUtil.getGroupConversationID(MiniTestAccount.chatGroupID)
        )
        conversation.type = .group
        conversation.title = "测试群：\(MiniTestAccount.chatGroupID)"
        return conversation
    }

    private func startVideoCall() {
        TUICallKit.createInstance().calls(
            userIdList: [MiniTestAccount.c2cChatUserID],
            mediaType: .video,
            params: nil,
            completion: nil
        )
    }

    private func entryLabel(title: String) -> some View {
        Text(title)
            .font(FontScheme.caption1Regular)
            .foregroundColor(themeState.colors.textColorButton)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(themeState.colors.buttonColorPrimaryDefault)
            .cornerRadius(CGFloat(RadiusScheme.smallRadius))
    }
}

private struct ConversationsDestination: View {
    @State private var navigationInfo: NavigationInfo?
    @State private var showChat = false

    var body: some View {
        ConversationsPage(
            config: nil,                      // 会话操作配置，nil 使用默认配置
            onConversationClick: { info in    // 会话打开回调，返回会话及可选的定位消息
                navigationInfo = info
                showChat = true
            }
        )
        .navigationBarHidden(true)
        .background(SwipeBackSupport())
        .background(chatNavigationLink)
    }

    @ViewBuilder
    private var chatNavigationLink: some View {
        if let info = navigationInfo {
            NavigationLink(
                destination: ChatPageDestination(
                    conversation: info.conversation,
                    locateMessage: info.locateMessage              // 保留搜索等入口传入的消息定位信息。
                ),
                isActive: $showChat
            ) { EmptyView() }
            .hidden()
        }
    }
}

private struct ContactsDestination: View {
    @State private var currentConversation: ConversationInfo?
    @State private var showChat = false

    var body: some View {
        ContactsPage(
            config: nil,                      // 联系人列表配置，nil 使用默认配置
            onContactClick: { item in         // 联系人点击回调，返回联系人信息
                openChat(makeC2CConversation(item))
            },
            onGroupClick: { item in           // 群点击回调，返回群信息
                openChat(makeGroupConversation(item))
            }
        )
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(true)
        .background(SwipeBackSupport())
        .background(chatNavigationLink)
    }

    // 联系人或群被点击后，使用同一个隐藏链接打开对应聊天页。
    @ViewBuilder
    private var chatNavigationLink: some View {
        if let conversation = currentConversation {
            NavigationLink(
                destination: ChatPageDestination(
                    conversation: conversation,
                    locateMessage: nil
                ),
                isActive: $showChat
            ) { EmptyView() }
            .hidden()
        }
    }

    private func openChat(_ conversation: ConversationInfo) {
        currentConversation = conversation
        showChat = true
    }

    private func makeC2CConversation(_ contact: ContactInfo) -> ConversationInfo {
        var conversation = ConversationInfo(conversationID: ChatUtil.getC2CConversationID(contact.userID))
        conversation.type = .c2c
        conversation.title = [contact.friendRemark, contact.nickname].compactMap { $0 }.first { !$0.isEmpty } ?? contact.userID
        conversation.avatarURL = contact.avatarURL
        return conversation
    }

    private func makeGroupConversation(_ group: GroupInfo) -> ConversationInfo {
        var conversation = ConversationInfo(conversationID: ChatUtil.getGroupConversationID(group.groupID))
        conversation.type = .group
        conversation.title = [group.groupName].compactMap { $0 }.first { !$0.isEmpty } ?? group.groupID
        conversation.avatarURL = group.avatarURL
        return conversation
    }
}

private struct ChatPageDestination: View {
    @Environment(\.dismiss) private var dismiss
    let conversation: ConversationInfo
    var locateMessage: MessageInfo? = nil


    var body: some View {
        ChatPage(
            conversation: conversation,      // 会话信息
            locateMessage: locateMessage,    // 需要定位的消息，nil 不指定定位消息
            messageListConfig: nil,          // 消息列表配置，nil 使用默认配置
            messageInputConfig: CustomLinkMessageManager.makeInputConfig(
                conversationID: conversation.conversationID
            ),                              // 输入配置，包含示例自定义消息入口
            isShowMoreButton: true,          // 是否显示导航栏的更多按钮
            showsNavigationBar: true,        // 是否显示 SDK 自绘导航栏
            topBannerView: nil,              // 自定义顶部横幅，nil 不显示
            onBack: { dismiss() },           // 返回按钮点击回调
            onUserClick: nil,                // 用户点击回调，返回用户 ID
            onMoreClick: nil                 // 导航栏标题或更多按钮点击回调
        )
        .navigationBarHidden(true)
        .background(SwipeBackSupport())
    }

    private func makeMessageInputConfig () -> ChatMessageInputConfig {
        var inputConfig = ChatMessageInputConfig()
        inputConfig.isShowVideoCall = false
        inputConfig.isShowAudioCall = false
        return inputConfig
    }
}

// 页面级桥接恢复原生左边缘右滑返回，不使用全局 Hook。
private struct SwipeBackSupport: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller {
        Controller()
    }

    func updateUIViewController(_ uiViewController: Controller, context: Context) {}

    final class Controller: UIViewController {
        private weak var popGesture: UIGestureRecognizer?
        private weak var previousDelegate: UIGestureRecognizerDelegate?

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard let navigationController = navigationController,
                  navigationController.viewControllers.count > 1,
                  let gesture = navigationController.interactivePopGestureRecognizer else { return }
            previousDelegate = gesture.delegate
            popGesture = gesture
            gesture.delegate = nil
            gesture.isEnabled = true
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            if let gesture = popGesture, gesture.delegate == nil {
                gesture.delegate = previousDelegate
            }
            popGesture = nil
            previousDelegate = nil
        }
    }
}

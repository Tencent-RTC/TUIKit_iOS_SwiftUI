import TUIChatKit_Swift
import AtomicXCore
import CoreTelephony
import SwiftUI
import UIKit

final class NetworkPermissionHelper {
    static let shared = NetworkPermissionHelper()
    private static let probeURL = "https://cloud.tencent.com"
    private static let probeTimeout: TimeInterval = 5

    private let cellularData = CTCellularData()
    private(set) var cellularRestrictionState: CTCellularDataRestrictedState = .restrictedStateUnknown
    private var started = false

    private init() {}

    func startProbe() {
        guard !started else { return }
        started = true
        triggerSystemNetworkPermissionDialog()
        cellularData.cellularDataRestrictionDidUpdateNotifier = { [weak self] state in
            self?.cellularRestrictionState = state
        }
    }

    private func triggerSystemNetworkPermissionDialog() {
        guard let url = URL(string: Self.probeURL) else { return }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: Self.probeTimeout)
        request.httpMethod = "HEAD"
        URLSession.shared.dataTask(with: request) { _, _, _ in }.resume()
    }

    func showSettingsGuideIfNeeded() {
        guard cellularRestrictionState == .restricted else { return }
        DispatchQueue.main.async {
            let alert = UIAlertController(
                title: LocalizedChatString("LoginNetworkError"),
                message: LocalizedChatString("LoginNetworkPermissionGuide"),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: LocalizedChatString("Settings"), style: .default) { _ in
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            })
            alert.addAction(UIAlertAction(title: LocalizedChatString("Cancel"), style: .cancel))
            guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
                  let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController ?? scene.windows.first?.rootViewController
            else { return }
            var top = root
            while let presented = top.presentedViewController {
                top = presented
            }
            top.present(alert, animated: true)
        }
    }
}

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        setupAppConfiguration()
        CustomLinkMessageManager.register()

        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UIHostingController(rootView: ContentView())
        window?.makeKeyAndVisible()

        return true
    }


    private func setupAppConfiguration() {
        if let configPath = Bundle.main.path(forResource: "appConfig", ofType: "json") {
            print("appConfig.json existed: \(configPath)")
            AppBuilderHelper.setJsonPath(path: configPath)
        } else {
            print("appConfig.json not found")
        }

        CustomLinkMessageManager.register()

        syncUserSettingsToAppConfig()
    }

    private func syncUserSettingsToAppConfig() {
        let readReceiptKey = "com.atomicx.enableReadReceipt"
        if UserDefaults.standard.object(forKey: readReceiptKey) != nil {
            AppBuilderConfig.shared.enableReadReceipt = UserDefaults.standard.bool(forKey: readReceiptKey)
        }

        let translateKey = "com.atomicx.translateTargetLanguage"
        if let saved = UserDefaults.standard.string(forKey: translateKey), !saved.isEmpty {
            AppBuilderConfig.shared.translateTargetLanguage = saved
        } else if AppBuilderConfig.shared.translateTargetLanguage.isEmpty {
            var systemLanguage = LanguageHelper.getCurrentLanguage()
            if systemLanguage == "zh-Hans" {
                systemLanguage = "zh"
            } else if systemLanguage == "zh-Hant" {
                systemLanguage = "zh-TW"
            }
            AppBuilderConfig.shared.translateTargetLanguage = systemLanguage
        }
    }

}

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
            "link": "https://cloud.tencent.com/document/product/269/3794"
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
        let sdkAppID = Int32(LoginStore.shared.sdkAppID)
        let userID = LoginStore.shared.state.value.loginUserInfo?.userID ?? ""
        return ChatMessageInputConfig(actionCustomizer: { editor in
            editor.add(MessageInputMenuAction(
                ID: "demo.messageInput.customLink",
                title: LocalizedChatString("DemoChatCustomMessageMenuTitle"),
                iconName: "",
                icon: makeMenuIcon(),
                onClick: {
                    CustomLinkMessageManager.send(conversationID: conversationID)
                }
            ))
            editor.replace(MessageInputActionIDs.videoCall) { action in
                withCallRedDotIfNeeded(sdkAppID: sdkAppID, userID: userID, action: action)
            }
            editor.replace(MessageInputActionIDs.audioCall) { action in
                withCallRedDotIfNeeded(sdkAppID: sdkAppID, userID: userID, action: action)
            }
        })
    }

    private static func withCallRedDotIfNeeded(
        sdkAppID: Int32,
        userID: String,
        action: MessageInputMenuAction
    ) -> MessageInputMenuAction {
        guard MessageInputCallRedDotStore.shouldShow(sdkAppID: sdkAppID, userID: userID, actionID: action.ID) else {
            return action
        }
        var decorated = action
        decorated.showRedDot = true
        decorated.onClick = {
            MessageInputCallRedDotStore.markClicked(sdkAppID: sdkAppID, userID: userID, actionID: action.ID)
            action.onClick()
        }
        return decorated
    }
}


private enum MessageInputCallRedDotStore {
    private static let clickedKeyPrefix = "message_input_call_red_dot_clicked_"

    static func shouldShow(sdkAppID: Int32, userID: String, actionID: String) -> Bool {
        guard sdkAppID > 0, !userID.isEmpty else { return false }
        return !UserDefaults.standard.bool(forKey: storageKey(sdkAppID: sdkAppID, userID: userID, actionID: actionID))
    }

    static func markClicked(sdkAppID: Int32, userID: String, actionID: String) {
        guard sdkAppID > 0, !userID.isEmpty else { return }
        UserDefaults.standard.set(true, forKey: storageKey(sdkAppID: sdkAppID, userID: userID, actionID: actionID))
    }

    private static func storageKey(sdkAppID: Int32, userID: String, actionID: String) -> String {
        return "\(clickedKeyPrefix)\(sdkAppID)_\(userID)_\(actionID)"
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

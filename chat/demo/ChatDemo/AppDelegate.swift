import AtomicX
import AtomicXCore
import Combine
import SwiftUI
import TIMPush
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate, TIMPushDelegate, TIMPushListener {
    var window: UIWindow?
    var clickNotificationInfo: [String: String] = [:]
    private var cancellables = Set<AnyCancellable>()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        setupAppConfiguration()
        TIMPushManager.addPushListener(listener: self)
        setupLoginObserver()

        // Setup window and root view controller
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UIHostingController(rootView: ContentView())
        window?.makeKeyAndVisible()

        return true
    }

    // MARK: - Login Observer

    private func setupLoginObserver() {
        LoginStore.shared.state
            .subscribe(StatePublisherSelector(keyPath: \LoginState.loginStatus))
            .sink { [weak self] loginStatus in
                guard let self = self else { return }
                if loginStatus == .logined {
                    self.registerTIMPush()
                } else if loginStatus == .unlogin {
                    self.unregisterTIMPush()
                }
            }
            .store(in: &cancellables)
    }

    private func registerTIMPush() {
        let sdkAppID = Int32(LoginStore.shared.sdkAppID)
        if businessID() <= 0 {
            print("TIMPush is not configured. Set kAPNSBusiId and App Group before testing offline push.")
            return
        }
        TIMPushManager.registerPush(sdkAppID, appKey: "", succ: { _ in
        }, fail: { code, desc in
            print("TIMPush registration failed, code: \(code), desc: \(desc)")
        })
    }

    private func unregisterTIMPush() {
        TIMPushManager.unRegisterPush({}, fail: { code, desc in
            print("TIMPush unregistration failed, code: \(code), desc: \(desc)")
        })
    }

    private func setupAppConfiguration() {
        if let configPath = Bundle.main.path(forResource: "appConfig", ofType: "json") {
            print("appConfig.json existed: \(configPath)")
            AppBuilderHelper.setJsonPath(path: configPath)
        } else {
            print("appConfig.json not found")
        }

        // Sync user settings from UserDefaults to AppBuilderConfig
        // This ensures user preferences persist across app restarts
        syncUserSettingsToAppConfig()
    }

    private func syncUserSettingsToAppConfig() {
        // Sync enableReadReceipt
        let readReceiptKey = "com.atomicx.enableReadReceipt"
        if UserDefaults.standard.object(forKey: readReceiptKey) != nil {
            AppBuilderConfig.shared.enableReadReceipt = UserDefaults.standard.bool(forKey: readReceiptKey)
        }

        // Sync translateTargetLanguage
        let translateKey = "com.atomicx.translateTargetLanguage"
        if let saved = UserDefaults.standard.string(forKey: translateKey), !saved.isEmpty {
            AppBuilderConfig.shared.translateTargetLanguage = saved
        } else if AppBuilderConfig.shared.translateTargetLanguage.isEmpty {
            // Use system language as default if not set, map to SDK language codes
            var systemLanguage = LanguageHelper.getCurrentLanguage()
            if systemLanguage == "zh-Hans" {
                systemLanguage = "zh"
            } else if systemLanguage == "zh-Hant" {
                systemLanguage = "zh-TW"
            }
            AppBuilderConfig.shared.translateTargetLanguage = systemLanguage
        }
    }

    // MARK: - TIMPush

    // TIMPushDelegate
    @objc func businessID() -> Int32 {
        let kAPNSBusiIdByType = UserDefaults.standard.integer(forKey: "kAPNSBusiIdByType")
        if kAPNSBusiIdByType > 0 {
            return Int32(kAPNSBusiIdByType)
        }
        return kAPNSBusiId
    }

    @objc func applicationGroupID() -> String {
        return kTIMPushAppGroupKey
    }

    @objc func onRemoteNotificationReceived(_ notice: String?) -> Bool {
        /*
          - If true is returned, TIMPush will no longer execute the built-in TUIKit offline push parsing logic, leaving it entirely to you to handle;
                  let ext = notice
                  let info = OfflinePushExtInfo.create(withExtString: ext)
                  return true

         - If false is returned, TIMPush will continue to execute the built-in TUIKit offline push parsing logic and continue the callback - navigateToBuiltInChatViewController:groupID:
                return false

         */

        return false
    }

    @objc func navigateToBuiltInChatViewController(userID: String?, groupID: String?) {
        if LoginStore.shared.state.value.loginStatus == .logined {
            navigateToBuiltInChatViewControllerImpl(userID, groupID: groupID)
        } else {
            if let userID = userID {
                clickNotificationInfo["userID"] = userID
            }
            if let groupID = groupID {
                clickNotificationInfo["groupID"] = groupID
            }
        }
    }

    @objc func onLoginSucc() {
        let userID = clickNotificationInfo["userID"]
        let groupID = clickNotificationInfo["groupID"]
        if userID != nil || groupID != nil {
            navigateToBuiltInChatViewControllerImpl(userID, groupID: groupID)
            clickNotificationInfo.removeAll()
        }
    }

    @objc func navigateToBuiltInChatViewControllerImpl(_ userID: String?, groupID: String?) {
        print(">>>>> navigateToBuiltInChatViewControllerImpl, userID: \(userID ?? "nil"), groupID: \(groupID ?? "nil")")

        // Use PushNavigationManager to trigger navigation in SwiftUI
        PushNavigationManager.shared.navigateToChat(userID: userID, groupID: groupID)
    }

    // MARK: - TIMPushListener

    func onRecvPushMessage(_ message: TIMPushMessage) {
        NSLog("onRecvPushMessage:%@", message)
    }

    func onRevokePushMessage(_ messageID: String) {
        NSLog("onRevokePushMessage:%@", messageID)
    }

    func onNotificationClicked(_ ext: String) {
        NSLog("onNotificationClicked:%@", ext)
    }
}

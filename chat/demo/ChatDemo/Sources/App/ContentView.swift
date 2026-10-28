import TUIChatKit_Swift
import AtomicXCore
import Combine
import SwiftUI
import UIKit
import ObjectiveC

public enum RootPage {
    case login
    case home
    case autoLogin
}

struct ContentView: View {
    @StateObject private var themeState = ThemeState.shared
    @StateObject private var appStyleSettings = AppStyleSettings()
    @StateObject private var languageState = LanguageState()
    @State private var currentPage: RootPage = .login
    @State private var cancellables = Set<AnyCancellable>()

    var body: some View {
        NavigationView {
            Group {
                switch currentPage {
                case .login:
                    LoginPage()
                case .home:
                    HomePage()
                case .autoLogin:
                    AutoLoginPage()
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .environmentObject(themeState)
        .environmentObject(appStyleSettings)
        .environmentObject(languageState)
        .preferredColorScheme(getPreferredColorScheme())
        .environment(\.layoutDirection, getLayoutDirection())
        .onAppear {
            languageState.setLanguage(languageState.currentLanguage)
            setupLoginStatusObserver()
            InteractivePopGestureEnabler.shared.scheduleInstall()
        }
        .onChange(of: currentPage) { _ in
            InteractivePopGestureEnabler.shared.scheduleInstall()
        }
    }

    private func getPreferredColorScheme() -> ColorScheme? {
        switch themeState.currentMode {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            if themeState.isDarkMode {
                return .dark
            } else {
                return .light
            }
        }
    }

    private func getLayoutDirection() -> LayoutDirection {
        let rtlLanguages = ["ar", "he", "fa", "ur"]
        return rtlLanguages.contains(languageState.currentLanguage) ? .rightToLeft : .leftToRight
    }

    private func setupLoginStatusObserver() {
        let currentLoginStatus = LoginStore.shared.state.value.loginStatus
        if currentLoginStatus == .logined {
            currentPage = .home
        } else if LoginStatusManager.hasSavedCredentials {
            currentPage = .autoLogin
            LoginStatusManager.shared.autoLogin { success in
                if !success {
                    DispatchQueue.main.async {
                        if LoginStore.shared.state.value.loginStatus != .logined {
                            currentPage = .login
                        }
                    }
                }
            }
        } else {
            currentPage = .login
        }

        LoginStore.shared.state
            .subscribe(StatePublisherSelector(keyPath: \LoginState.loginStatus))
            .sink { loginStatus in
                DispatchQueue.main.async {
                    handleLoginStatusChange(loginStatus)
                }
            }
            .store(in: &cancellables)
    }

    private func handleLoginStatusChange(_ loginStatus: LoginStatus) {
        switch loginStatus {
        case .logined:
            if currentPage != .home {
                currentPage = .home
            }
        case .unlogin:
            NotificationCenter.default.post(name: Notification.Name("ChatDemoWillLogout"), object: nil)
            currentPage = .login
        }
    }
}

struct AutoLoginPage: View {
    @EnvironmentObject var themeState: ThemeState

    var body: some View {
        ZStack {
            themeState.colors.bgColorOperate.ignoresSafeArea()
            ProgressView()
                .scaleEffect(1.5)
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

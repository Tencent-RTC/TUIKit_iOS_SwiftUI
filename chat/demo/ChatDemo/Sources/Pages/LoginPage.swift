import TUIChatKit_Swift
import AtomicXCore
import SwiftUI

class LoginStatusManager: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var currentUserID: String = ""
    @Published var isLoggingIn: Bool = false
    @Published var loginError: String? = nil
    static let shared = LoginStatusManager()

    enum LoginPersist {
        static let loginUser = "LoginUser"
        static let loginType = "LoginType"
        static let loginTypeLocal = "local"
    }

    static var hasSavedCredentials: Bool {
        let type = UserDefaults.standard.string(forKey: LoginPersist.loginType) ?? ""
        let userID = UserDefaults.standard.string(forKey: LoginPersist.loginUser) ?? ""
        return type == LoginPersist.loginTypeLocal && !userID.isEmpty
    }

    private init() {
        isLoggedIn = LoginStore.shared.state.value.loginStatus == .logined
        if isLoggedIn, let userInfo = LoginStore.shared.state.value.loginUserInfo {
            currentUserID = userInfo.userID
        }
    }

    func login(sdkAppID: Int32, userID: String, userSig: String, completion: @escaping (Bool) -> Void) {
        isLoggingIn = true
        loginError = nil
        LoginStore.shared.login(sdkAppID: sdkAppID, userID: userID, userSig: userSig, completion: { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success:
                CallService.initEngine(sdkAppID: sdkAppID, userID: userID, userSig: userSig)
                DispatchQueue.main.async {
                    self.isLoggedIn = true
                    self.currentUserID = userID
                    self.isLoggingIn = false
                    completion(true)
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self.loginError = "\(LocalizedChatString("LoginFailed")): \(error.code), \(error.message)"
                    self.isLoggingIn = false
                    NetworkPermissionHelper.shared.showSettingsGuideIfNeeded()
                    completion(false)
                }
            }
        })
    }

    func loginLocal(userID: String, completion: @escaping (Bool) -> Void) {
        let appID = GenerateTestUserSig.sdkAppID
        guard appID > 0 else {
            loginError = LocalizedChatString("InvalidSDKAppID")
            completion(false)
            return
        }
        let userSig = GenerateTestUserSig.genTestUserSig(identifier: userID)
        login(sdkAppID: appID, userID: userID, userSig: userSig) { success in
            if success {
                UserDefaults.standard.set(userID, forKey: LoginPersist.loginUser)
                UserDefaults.standard.set(LoginPersist.loginTypeLocal, forKey: LoginPersist.loginType)
            }
            completion(success)
        }
    }

    func autoLogin(completion: @escaping (Bool) -> Void) {
        let type = UserDefaults.standard.string(forKey: LoginPersist.loginType) ?? ""
        let userID = UserDefaults.standard.string(forKey: LoginPersist.loginUser) ?? ""
        if type == LoginPersist.loginTypeLocal, !userID.isEmpty {
            loginLocal(userID: userID) { [weak self] success in
                if !success {
                    self?.clearSavedCredentials()
                }
                completion(success)
            }
            return
        }
        clearSavedCredentials()
        completion(false)
    }

    private func clearSavedCredentials() {
        UserDefaults.standard.set("", forKey: LoginPersist.loginUser)
        UserDefaults.standard.set("", forKey: LoginPersist.loginType)
    }

    func logout(completion: @escaping (Bool) -> Void) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.logout(completion: completion) }
            return
        }
        NotificationCenter.default.post(name: Notification.Name("ChatDemoWillLogout"), object: nil)
        clearSavedCredentials()
        LoginStore.shared.logout(completion: { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success:
                DispatchQueue.main.async {
                    self.isLoggedIn = false
                    self.currentUserID = ""
                    self.isLoggingIn = false
                    completion(true)
                }
            case .failure:
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: Notification.Name("ChatDemoLogoutFailed"), object: nil)
                    completion(false)
                }
            }
        })
    }
}

struct LoginPage: View {
    private static let heroHeight: CGFloat = 248
    private static let panelTopOverlap: CGFloat = 24
    private static let bottomContentLift: CGFloat = 40
    private static let homepageURL = "https://cloud.tencent.com/product/im"
    static var hasAgreedPrivacy = false

    @EnvironmentObject var themeState: ThemeState
    @EnvironmentObject var languageState: LanguageState
    @StateObject private var loginManager = LoginStatusManager.shared
    @State private var userID = ""
    @State private var showPrivacy = false
    @State private var showConfigGuide = false

    private var loginEnabled: Bool {
        !userID.isEmpty && !loginManager.isLoggingIn
    }

    private static var topSafeAreaInset: CGFloat {
        let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        let window = scene?.windows.first(where: { $0.isKeyWindow }) ?? scene?.windows.first
        return window?.safeAreaInsets.top ?? 0
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                themeState.colors.bgColorOperate
                heroSection(safeAreaTop: Self.topSafeAreaInset)
                loginPanel(minContentHeight: geometry.size.height - Self.heroHeight + Self.panelTopOverlap - Self.bottomContentLift)
                    .padding(.top, Self.heroHeight - Self.panelTopOverlap)
            }
        }
        .ignoresSafeArea(.container, edges: .all)
        .overlay {
            if showPrivacy {
                PrivacyDialogView(onAgree: {
                    LoginPage.hasAgreedPrivacy = true
                    showPrivacy = false
                    NetworkPermissionHelper.shared.startProbe()
                }, onRefuse: {
                    exit(0)
                })
                .environmentObject(themeState)
            }
        }
        .onAppear {
            if !LoginPage.hasAgreedPrivacy {
                showPrivacy = true
            }
        }
        .alert(isPresented: $showConfigGuide) {
            Alert(
                title: Text(LocalizedChatString("LoginFailed")),
                message: Text((loginManager.loginError ?? LocalizedChatString("LoginFailed")) + "\n\n" + LocalizedChatString("LoginConfigGuide")),
                primaryButton: .default(Text(LocalizedChatString("ViewDocument"))) {
                    if let url = URL(string: "https://cloud.tencent.com/document/product/269/68228") {
                        UIApplication.shared.open(url)
                    }
                },
                secondaryButton: .cancel(Text(LocalizedChatString("Cancel")))
            )
        }
    }

    private func heroSection(safeAreaTop: CGFloat) -> some View {
        ZStack(alignment: .topTrailing) {
            Image("demo_login_hero_bg")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: Self.heroHeight)
                .clipped()
            HStack(spacing: 0) {
                LoginSwitcherButton(icon: "demo_ic_login_theme", title: currentThemeName()) {
                    showThemeSheet()
                }
                LoginSwitcherButton(icon: "demo_ic_login_language", title: currentLanguageName()) {
                    showLanguageSheet()
                }
            }
            .padding(.top, safeAreaTop + CGFloat(SpacingScheme.smallSpacing))
            .padding(.trailing, CGFloat(SpacingScheme.smallSpacing))
            HStack(alignment: .center, spacing: CGFloat(SpacingScheme.iconIconSpacing)) {
                Image("demo_login_brand_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 84, height: 44)
                VStack(alignment: .leading, spacing: CGFloat(SpacingScheme.smallSpacing)) {
                    Text(LocalizedChatString("LoginHeroTitle"))
                        .font(FontScheme.body2Bold)
                        .foregroundColor(Colors.White1)
                    Text(LocalizedChatString("LoginHeroSubtitle"))
                        .font(FontScheme.caption2Regular)
                        .foregroundColor(Colors.White1.opacity(0.8))
                }
                .offset(y: 1)
            }
            .padding(.leading, CGFloat(SpacingScheme.normalSpacing))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .frame(height: Self.heroHeight)
    }

    private func loginPanel(minContentHeight: CGFloat) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                fieldLabel(LocalizedChatString("EnterUserID"))
                TextField(LocalizedChatString("EnterUserID"), text: $userID)
                    .font(FontScheme.caption1Regular)
                    .foregroundColor(themeState.colors.textColorPrimary)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .frame(height: 52)
                    .onChange(of: userID) { _ in loginManager.loginError = nil }
                fieldDivider(bottomPadding: 0)
                if let error = loginManager.loginError {
                    Text(error)
                        .font(FontScheme.caption3Regular)
                        .foregroundColor(themeState.colors.textColorTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, CGFloat(SpacingScheme.iconTextSpacing))
                }
                Button(action: handleLogin) {
                    Group {
                        if loginManager.isLoggingIn {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: themeState.colors.textColorButton))
                        } else {
                            Text(LocalizedChatString("login"))
                                .font(FontScheme.body4Bold)
                        }
                    }
                    .foregroundColor(loginEnabled ? themeState.colors.textColorButton : themeState.colors.textColorButtonDisabled)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(loginEnabled ? themeState.colors.buttonColorPrimaryDefault : themeState.colors.buttonColorPrimaryDisabled)
                    .cornerRadius(CGFloat(RadiusScheme.largeRadius))
                }
                .disabled(!loginEnabled)
                .padding(.top, CGFloat(SpacingScheme.titleSpacing))
                Spacer(minLength: 24)
                Button(action: {
                    if let url = URL(string: Self.homepageURL), UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url)
                    } else {
                        WindowToastManager.shared.info(LocalizedChatString("LoginOpenBrowserFailed"))
                    }
                }) {
                    Text(LocalizedChatString("LoginOfficialWebsite"))
                        .font(FontScheme.caption2Regular)
                        .foregroundColor(themeState.colors.textColorLink)
                        .padding(CGFloat(SpacingScheme.smallSpacing))
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal, CGFloat(SpacingScheme.titleSpacing))
            .padding(.top, CGFloat(SpacingScheme.titleSpacing))
            .padding(.bottom, CGFloat(SpacingScheme.normalSpacing))
            .frame(minHeight: minContentHeight)
        }
        .scrollDismissesKeyboardInteractivelyIfAvailable()
        .background(themeState.colors.bgColorOperate)
        .cornerRadius(CGFloat(RadiusScheme.superLargeRadius), corners: [.topLeft, .topRight])
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(FontScheme.body4Bold)
            .foregroundColor(themeState.colors.textColorPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, CGFloat(SpacingScheme.iconTextSpacing))
    }

    private func fieldDivider(bottomPadding: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)) -> some View {
        Rectangle()
            .fill(themeState.colors.strokeColorPrimary)
            .frame(height: 1)
            .padding(.bottom, bottomPadding)
    }

    private func handleLogin() {
        let trimmed = userID.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            WindowToastManager.shared.info(LocalizedChatString("EnterUserID"))
            return
        }
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        guard GenerateTestUserSig.sdkAppID > 0 else {
            loginManager.loginError = LocalizedChatString("InvalidSDKAppID")
            showConfigGuide = true
            return
        }
        loginManager.loginLocal(userID: trimmed) { success in
            if !success {
                showConfigGuide = true
            }
        }
    }

    private func currentThemeName() -> String {
        switch ThemeState.shared.currentTheme.mode {
        case .light: return LocalizedChatString("ThemeNameLight")
        case .dark: return LocalizedChatString("ThemeNameDark")
        case .system: return LocalizedChatString("ThemeNameSystem")
        }
    }

    private func currentLanguageName() -> String {
        languageState.getCurrentLanguageName()
    }

    private func showThemeSheet() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: LocalizedChatString("ThemeNameSystem"), style: .default) { _ in
            ThemeState.shared.setThemeMode(.system)
        })
        alert.addAction(UIAlertAction(title: LocalizedChatString("ThemeNameLight"), style: .default) { _ in
            ThemeState.shared.setThemeMode(.light)
        })
        alert.addAction(UIAlertAction(title: LocalizedChatString("ThemeNameDark"), style: .default) { _ in
            ThemeState.shared.setThemeMode(.dark)
        })
        alert.addAction(UIAlertAction(title: LocalizedChatString("Cancel"), style: .cancel))
        presentFromTop(alert)
    }

    private func showLanguageSheet() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        for language in languageState.supportedLanguages {
            alert.addAction(UIAlertAction(title: language.nativeName, style: .default) { _ in
                languageState.setLanguage(language.code)
            })
        }
        alert.addAction(UIAlertAction(title: LocalizedChatString("Cancel"), style: .cancel))
        presentFromTop(alert)
    }

    private func presentFromTop(_ controller: UIViewController) {
        guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController ?? scene.windows.first?.rootViewController
        else { return }
        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        top.present(controller, animated: true)
    }
}

struct LoginSwitcherButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: CGFloat(SpacingScheme.smallSpacing)) {
                Image(icon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                Text(title)
                    .font(FontScheme.caption2Regular)
                Image("demo_ic_login_arrow_down")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 10, height: 10)
            }
            .foregroundColor(Colors.White1)
            .padding(.horizontal, CGFloat(SpacingScheme.iconIconSpacing))
            .padding(.vertical, CGFloat(SpacingScheme.smallSpacing))
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }

    @ViewBuilder
    func scrollDismissesKeyboardInteractivelyIfAvailable() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollDismissesKeyboard(.interactively)
        } else {
            self
        }
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

struct PrivacyDialogView: View {
    @EnvironmentObject var themeState: ThemeState
    @State private var privacyTextHeight: CGFloat = 200
    let onAgree: () -> Void
    let onRefuse: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let dialogWidth = geometry.size.width * 0.8
            ZStack {
                Colors.Black1.opacity(0.4)
                    .ignoresSafeArea()
                VStack(spacing: 0) {
                    PrivacyTextView(contentWidth: dialogWidth - 40, measuredHeight: $privacyTextHeight)
                        .frame(width: dialogWidth - 40, height: privacyTextHeight)
                        .padding(CGFloat(SpacingScheme.contentSpacing))
                    Button(action: onAgree) {
                        Text(LocalizedChatString("LoginPrivacyAgree"))
                            .font(FontScheme.caption1Bold)
                            .foregroundColor(themeState.colors.textColorButton)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(themeState.colors.buttonColorPrimaryDefault)
                            .cornerRadius(CGFloat(RadiusScheme.largeRadius))
                    }
                    .padding(.horizontal, CGFloat(SpacingScheme.contentSpacing))
                    .padding(.top, CGFloat(SpacingScheme.iconTextSpacing))
                    Button(action: onRefuse) {
                        Text(LocalizedChatString("LoginPrivacyRefuse"))
                            .font(FontScheme.caption2Regular)
                            .foregroundColor(themeState.colors.textColorSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .padding(.horizontal, CGFloat(SpacingScheme.contentSpacing))
                    .padding(.top, CGFloat(SpacingScheme.smallSpacing))
                    .padding(.bottom, CGFloat(SpacingScheme.contentSpacing))
                }
                .frame(width: dialogWidth)
                .background(themeState.colors.bgColorOperate)
                .cornerRadius(CGFloat(RadiusScheme.largeRadius))
            }
        }
    }
}

private struct PrivacyTextView: UIViewRepresentable {
    @EnvironmentObject var themeState: ThemeState
    let contentWidth: CGFloat
    @Binding var measuredHeight: CGFloat

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView(frame: CGRect(x: 0, y: 0, width: contentWidth, height: 1))
        textView.isEditable = false
        textView.isScrollEnabled = true
        textView.showsVerticalScrollIndicator = false
        textView.bounces = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.attributedText = buildAttributed()
        textView.linkTextAttributes = [.foregroundColor: UIColor(themeState.colors.textColorLink)]
        let bounds = buildAttributed().boundingRect(
            with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        DispatchQueue.main.async {
            measuredHeight = ceil(bounds.height)
        }
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.attributedText = buildAttributed()
    }

    private func buildAttributed() -> NSAttributedString {
        let colors = themeState.colors
        let fullText = LocalizedChatString("LoginPrivacyDialogTips")
        let linkPhrases: [(phrase: String, url: String)] = [
            (LocalizedChatString("LoginUserAgreement"), "https://web.sdk.qcloud.com/document/Tencent-IM-User-Agreement.html"),
            (LocalizedChatString("LoginPrivacyPolicySummary"), "https://privacy.qq.com/document/preview/c63a48325d0e4a35b93f675205a65a77"),
            (LocalizedChatString("LoginPrivacyPolicy"), "https://privacy.qq.com/document/preview/1cfe904fb7004b8ab1193a55857f7272"),
            (LocalizedChatString("LoginSelfInfoCollection"), "https://privacy.qq.com/document/preview/45ba982a1ce6493597a00f8c86b52a1e"),
            (LocalizedChatString("LoginThirdPartShared"), "https://privacy.qq.com/document/preview/dea84ac4bb88454794928b77126e9246"),
        ]
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = CGFloat(SpacingScheme.iconTextSpacing)
        let attributed = NSMutableAttributedString(
            string: fullText,
            attributes: [
                .font: UIKitFontScheme.caption2Regular,
                .foregroundColor: UIColor(colors.textColorPrimary),
                .paragraphStyle: paragraphStyle,
            ]
        )
        for item in linkPhrases {
            if let range = fullText.range(of: item.phrase, options: .backwards) {
                let nsRange = NSRange(range, in: fullText)
                attributed.addAttribute(.link, value: item.url, range: nsRange)
                attributed.addAttribute(.foregroundColor, value: UIColor(colors.textColorLink), range: nsRange)
            }
        }
        return attributed
    }
}

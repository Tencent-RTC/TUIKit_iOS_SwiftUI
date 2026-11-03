import TUIChatKit_Swift
import AtomicXCore
import SwiftUI

struct ColorOption: Identifiable {
    let id = UUID()
    let name: String
    let hex: String
    let color: Color
    init(name: String, hex: String) {
        self.name = name
        self.hex = hex
        self.color = Color(hexString: hex)
    }
}

extension ThemeConfig {
    var displayName: String {
        let modeName: String
        switch mode {
        case .system:
            modeName = LocalizedChatString("ThemeNameSystem")
        case .light:
            modeName = LocalizedChatString("ThemeNameLight")
        case .dark:
            modeName = LocalizedChatString("ThemeNameDark")
        }
        if let primaryColor = primaryColor {
            return "\(modeName) + \(primaryColor)"
        } else {
            return modeName
        }
    }
}

let presetColors = [
    ColorOption(name: LocalizedChatString("ColorRed"), hex: "#E54545"),
    ColorOption(name: LocalizedChatString("ColorOrange"), hex: "#FF7200"),
    ColorOption(name: LocalizedChatString("ColorYellow"), hex: "#7ff879"),
    ColorOption(name: LocalizedChatString("ColorGreen"), hex: "#0ABF77"),
    ColorOption(name: LocalizedChatString("ColorBlue"), hex: "#1C66E5"),
    ColorOption(name: LocalizedChatString("ColorPurple"), hex: "#AF52DE")
]

enum SettingsSheetKind: Identifiable {
    case theme, language, approve, translate
    var id: Int { hashValue }
}

struct SettingsPage: View {
    @EnvironmentObject var themeState: ThemeState
    @EnvironmentObject var languageState: LanguageState
    @ObservedObject private var loginManager = LoginStatusManager.shared
    @State private var loginStore = LoginStore.shared
    @State private var allowType: AllowType? = nil
    @State private var nickname: String? = nil
    @State private var avatarURL: String? = nil
    @State private var selfSignature: String? = nil
    @AppStorage("com.atomicx.enableReadReceipt") private var enableReadReceipt: Bool = false
    @State private var activeSheet: SettingsSheetKind? = nil
    @State private var showProfileDetail = false
    @State private var showColorPicker = false
    @State private var showAbout = false
    @State private var showVoiceSetting = false

    private let translateLanguageOptions: [(code: String, name: String)] = [
        ("zh", "简体中文"), ("zh-TW", "繁體中文"), ("en", "English"), ("ja", "日本語"),
        ("ko", "한국어"), ("fr", "Français"), ("es", "Español"), ("it", "Italiano"),
        ("de", "Deutsch"), ("tr", "Türkçe"), ("ru", "Русский"), ("pt", "Português"),
        ("vi", "Tiếng Việt"), ("id", "Bahasa Indonesia"), ("th", "ภาษาไทย"),
        ("ms", "Bahasa Melayu"), ("hi", "हिन्दी")
    ]

    private func displayName() -> String {
        if let nickname = nickname, !nickname.isEmpty { return nickname }
        return loginManager.currentUserID
    }

    private func signatureText() -> String {
        let sig = selfSignature ?? ""
        return "\(LocalizedChatString("MeSignaturePrefix"))：\(sig.isEmpty ? LocalizedChatString("NoSelfSignature") : sig)"
    }

    private func themeValueText() -> String {
        switch themeState.currentMode {
        case .system: return LocalizedChatString("ThemeNameSystem")
        case .light: return LocalizedChatString("ThemeNameLight")
        case .dark: return LocalizedChatString("ThemeNameDark")
        }
    }

    private func approveValueText() -> String {
        guard let allowType = allowType else { return "" }
        switch allowType {
        case .allowAny: return LocalizedChatString("AllowTypeAcceptOne")
        case .needConfirm: return LocalizedChatString("AllowTypeNeedConfirm")
        case .denyAny: return LocalizedChatString("AllowTypeDeclineAll")
        }
    }

    private func translateValueText() -> String {
        var currentCode = AppBuilderConfig.shared.translateTargetLanguage
        if currentCode == "zh-Hans" { currentCode = "zh" } else if currentCode == "zh-Hant" { currentCode = "zh-TW" }
        return translateLanguageOptions.first { $0.code == currentCode }?.name ?? currentCode
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        profileSection
                        groupSpacer
                        groupOne
                        groupSpacer
                        groupTwo
                        groupSpacer
                        groupThree
                        Spacer(minLength: 0)
                        logoutSection
                    }
                    .frame(minHeight: proxy.size.height)
                }
            }
            .background(themeState.colors.bgColorTopBar)
        }
        .background(themeState.colors.bgColorTopBar.ignoresSafeArea())
        .id("SettingsPage-\(languageState.currentLanguage)")
        .onReceive(loginStore.state.subscribe(StatePublisherSelector(keyPath: \LoginState.loginUserInfo?.allowType))) { self.allowType = $0 }
        .onReceive(loginStore.state.subscribe(StatePublisherSelector(keyPath: \LoginState.loginUserInfo?.nickname))) { self.nickname = $0 }
        .onReceive(loginStore.state.subscribe(StatePublisherSelector(keyPath: \LoginState.loginUserInfo?.avatarURL))) { self.avatarURL = $0 }
        .onReceive(loginStore.state.subscribe(StatePublisherSelector(keyPath: \LoginState.loginUserInfo?.selfSignature))) { self.selfSignature = $0 }
        .onAppear {
            self.nickname = loginStore.state.value.loginUserInfo?.nickname
            self.avatarURL = loginStore.state.value.loginUserInfo?.avatarURL
            self.selfSignature = loginStore.state.value.loginUserInfo?.selfSignature
            self.allowType = loginStore.state.value.loginUserInfo?.allowType
        }
        .fullScreenCover(isPresented: $showProfileDetail) {
            NavigationView {
                ProfileDetailView()
                    .environmentObject(themeState)
                    .environmentObject(languageState)
                    .navigationBarItems(leading: Button(LocalizedChatString("Cancel")) { showProfileDetail = false }.foregroundColor(themeState.colors.textColorLink))
            }
        }
        .fullScreenCover(item: $activeSheet) { kind in
            SettingsOptionSheet(kind: kind, onSelect: { index in handleSheetSelection(kind: kind, index: index) })
                .environmentObject(themeState)
        }
        .fullScreenCover(isPresented: $showColorPicker) {
            PrimaryColorPickerView(selectedHex: themeState.currentPrimaryColor ?? PrimaryColorPickerView.defaultPrimaryHex) { hex in
                themeState.setPrimaryColor(hex)
            }
            .environmentObject(themeState)
        }
        .fullScreenCover(isPresented: $showAbout) {
            AboutPage()
                .environmentObject(themeState)
        }
        .fullScreenCover(isPresented: $showVoiceSetting) {
            VoiceMessageSettingPage()
                .environmentObject(themeState)
        }
    }

    private var headerView: some View {
        Text(LocalizedChatString("TabSettings"))
            .font(FontScheme.body4Bold)
            .foregroundColor(themeState.colors.textColorPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(themeState.colors.bgColorOperate)
    }

    private var groupSpacer: some View {
        Rectangle()
            .fill(themeState.colors.bgColorTopBar)
            .frame(height: 10)
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(themeState.colors.strokeColorPrimary)
            .frame(height: 0.5)
    }

    private var arrowIcon: some View {
        Image("contact_info_arrow_right", bundle: AtomicXChatResources.resourceBundle)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 16, height: 16)
            .foregroundColor(themeState.colors.textColorTertiary)
    }

    private var profileSection: some View {
        Button(action: { showProfileDetail = true }) {
            HStack(spacing: CGFloat(SpacingScheme.bubbleSpacing)) {
                AvatarView(url: avatarURL, name: displayName(), size: .l, shape: .round)
                VStack(alignment: .leading, spacing: CGFloat(SpacingScheme.iconTextSpacing)) {
                    Text(displayName())
                        .font(FontScheme.body4Regular)
                        .foregroundColor(themeState.colors.textColorPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text("ID：\(loginStore.state.value.loginUserInfo?.userID ?? loginManager.currentUserID)")
                        .font(FontScheme.caption2Regular)
                        .foregroundColor(themeState.colors.textColorTertiary)
                    Text(signatureText())
                        .font(FontScheme.caption2Regular)
                        .foregroundColor(themeState.colors.textColorTertiary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer()
            }
            .padding(.horizontal, CGFloat(SpacingScheme.bubbleSpacing))
            .padding(.vertical, CGFloat(SpacingScheme.iconIconSpacing))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(themeState.colors.bgColorOperate)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func entryRow(title: String, value: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(FontScheme.caption1Regular)
                    .foregroundColor(themeState.colors.textColorSecondary)
                Spacer()
                if let value = value {
                    Text(value)
                        .font(FontScheme.caption1Regular)
                        .foregroundColor(themeState.colors.textColorPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                arrowIcon
            }
            .padding(.horizontal, CGFloat(SpacingScheme.bubbleSpacing))
            .padding(.vertical, CGFloat(SpacingScheme.iconIconSpacing))
            .frame(minHeight: 48)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(themeState.colors.bgColorOperate)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var primaryColorRow: some View {
        Button(action: { showColorPicker = true }) {
            HStack {
                Text(LocalizedChatString("SelectThemeColor"))
                    .font(FontScheme.caption1Regular)
                    .foregroundColor(themeState.colors.textColorSecondary)
                Spacer()
                Circle()
                    .fill(Color(hexString: themeState.currentPrimaryColor ?? PrimaryColorPickerView.defaultPrimaryHex))
                    .frame(width: 24, height: 24)
                    .overlay(Circle().stroke(themeState.colors.strokeColorPrimary, lineWidth: 1.5))
                arrowIcon
            }
            .padding(.horizontal, CGFloat(SpacingScheme.bubbleSpacing))
            .padding(.vertical, CGFloat(SpacingScheme.iconIconSpacing))
            .frame(minHeight: 48)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(themeState.colors.bgColorOperate)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var groupOne: some View {
        VStack(spacing: 0) {
            entryRow(title: LocalizedChatString("SelectThemeMode"), value: themeValueText()) { activeSheet = .theme }
            rowDivider
            primaryColorRow
            rowDivider
            entryRow(title: LocalizedChatString("SelectLanguage"), value: languageState.getCurrentLanguageName()) { activeSheet = .language }
        }
    }

    private var readReceiptRow: some View {
        VStack(alignment: .leading, spacing: CGFloat(SpacingScheme.smallSpacing)) {
            Text(LocalizedChatString("MessageReadReceipt"))
                .font(FontScheme.caption1Regular)
                .foregroundColor(themeState.colors.textColorSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(
                    Toggle("", isOn: $enableReadReceipt)
                        .labelsHidden()
                        .tint(themeState.colors.switchColorOn)
                        .onChange(of: enableReadReceipt) { AppBuilderConfig.shared.enableReadReceipt = $0 },
                    alignment: .trailing
                )
            Text(enableReadReceipt ? LocalizedChatString("MessageReadReceiptEnabledDesc") : LocalizedChatString("MessageReadReceiptDisabledDesc"))
                .font(FontScheme.caption3Regular)
                .foregroundColor(themeState.colors.textColorTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, CGFloat(SpacingScheme.bubbleSpacing))
        .padding(.vertical, CGFloat(SpacingScheme.iconIconSpacing))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(themeState.colors.bgColorOperate)
    }

    private var groupTwo: some View {
        VStack(spacing: 0) {
            entryRow(title: LocalizedChatString("MeFriendRequest"), value: approveValueText()) { activeSheet = .approve }
            rowDivider
            readReceiptRow
            rowDivider
            entryRow(title: LocalizedChatString("TranslateMessage"), value: translateValueText()) { activeSheet = .translate }
            rowDivider
            entryRow(title: LocalizedChatString("VoiceMessageSettings"), value: nil) { showVoiceSetting = true }
        }
    }

    private var groupThree: some View {
        VStack(spacing: 0) {
            entryRow(title: LocalizedChatString("AboutTencentIM"), value: nil) { showAbout = true }
        }
    }

    private var logoutSection: some View {
        Button(action: { loginManager.logout { _ in } }) {
            Text(LocalizedChatString("logout"))
                .font(FontScheme.caption1Regular)
                .foregroundColor(themeState.colors.textColorError)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .background(themeState.colors.bgColorInput)
                .cornerRadius(CGFloat(RadiusScheme.smallRadius))
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, CGFloat(SpacingScheme.bubbleSpacing))
        .padding(.vertical, CGFloat(SpacingScheme.contentSpacing))
        .background(themeState.colors.bgColorTopBar)
    }

    private func handleSheetSelection(kind: SettingsSheetKind, index: Int) {
        switch kind {
        case .theme:
            let modes: [ThemeMode] = [.system, .light, .dark]
            if index < modes.count { themeState.setThemeMode(modes[index]) }
        case .language:
            let languages = languageState.supportedLanguages
            if index < languages.count { languageState.setLanguage(languages[index].code) }
        case .approve:
            let types: [AllowType] = [.allowAny, .needConfirm, .denyAny]
            if index < types.count { setAllowType(types[index]) }
        case .translate:
            if index < translateLanguageOptions.count {
                let code = translateLanguageOptions[index].code
                AppBuilderConfig.shared.translateTargetLanguage = code
                UserDefaults.standard.set(code, forKey: "com.atomicx.translateTargetLanguage")
            }
        }
    }

    private func sheetTitles(for kind: SettingsSheetKind) -> [String] {
        switch kind {
        case .theme:
            return [LocalizedChatString("ThemeNameSystem"), LocalizedChatString("ThemeNameLight"), LocalizedChatString("ThemeNameDark")]
        case .language:
            return languageState.supportedLanguages.map { $0.nativeName }
        case .approve:
            return [LocalizedChatString("AllowTypeAcceptOne"), LocalizedChatString("AllowTypeNeedConfirm"), LocalizedChatString("AllowTypeDeclineAll")]
        case .translate:
            return translateLanguageOptions.map { $0.name }
        }
    }

    private func setAllowType(_ allowType: AllowType) {
        if var info = loginStore.state.value.loginUserInfo {
            info.allowType = allowType
            LoginStore.shared.setSelfInfo(userProfile: info, completion: nil)
        }
    }

    private func SettingsOptionSheet(kind: SettingsSheetKind, onSelect: @escaping (Int) -> Void) -> some View {
        SettingsBottomOptionSheet(optionTitles: sheetTitles(for: kind), onSelect: onSelect)
            .environmentObject(themeState)
    }
}

private struct SubPageHeader: View {
    @EnvironmentObject var themeState: ThemeState
    let title: String
    var titleFont: Font = FontScheme.caption1Medium
    let onBack: () -> Void

    var body: some View {
        ZStack {
            Text(title)
                .font(titleFont)
                .foregroundColor(themeState.colors.textColorPrimary)
                .frame(maxWidth: .infinity)
            HStack {
                Button(action: onBack) {
                    Image("contact_info_back", bundle: AtomicXChatResources.resourceBundle)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .foregroundColor(themeState.colors.textColorPrimary)
                        .frame(width: 28, height: 28)
                }
                .padding(.leading, CGFloat(SpacingScheme.bubbleSpacing))
                Spacer()
            }
        }
        .frame(height: 56)
        .background(themeState.colors.bgColorOperate)
    }
}

private struct SettingEntryRow: View {
    @EnvironmentObject var themeState: ThemeState
    let title: String
    var value: String = ""
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(FontScheme.caption1Regular)
                    .foregroundColor(themeState.colors.textColorSecondary)
                Spacer()
                if !value.isEmpty {
                    Text(value)
                        .font(FontScheme.caption1Regular)
                        .foregroundColor(themeState.colors.textColorPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Image("contact_info_arrow_right", bundle: AtomicXChatResources.resourceBundle)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                    .foregroundColor(themeState.colors.textColorTertiary)
            }
            .padding(.horizontal, CGFloat(SpacingScheme.bubbleSpacing))
            .padding(.vertical, CGFloat(SpacingScheme.iconIconSpacing))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(themeState.colors.bgColorOperate)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct VoiceMessageSettingPage: View {
    @EnvironmentObject var themeState: ThemeState
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedVoiceName: String = ""
    @State private var activeSubPage: VoiceSubPage? = nil

    private enum VoiceSubPage: Identifiable {
        case clone, select
        var id: Int { hashValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            SubPageHeader(title: LocalizedChatString("VoiceMessageSettings"), titleFont: FontScheme.body4Bold) {
                presentationMode.wrappedValue.dismiss()
            }
            Rectangle().fill(themeState.colors.bgColorTopBar).frame(height: 10)
            SettingEntryRow(title: LocalizedChatString("VoiceClone")) { activeSubPage = .clone }
            Rectangle().fill(themeState.colors.strokeColorPrimary).frame(height: 0.5)
            SettingEntryRow(title: LocalizedChatString("VoiceSelect"), value: selectedVoiceName) { activeSubPage = .select }
            Spacer()
        }
        .background(themeState.colors.bgColorTopBar.ignoresSafeArea())
        .onAppear {
            let name = VoiceMessageConfig.shared.getSelectedVoiceName()
            selectedVoiceName = name.isEmpty ? LocalizedChatString("voice_message_voice_default") : name
        }
        .fullScreenCover(item: $activeSubPage) { subPage in
            switch subPage {
            case .clone:
                VoiceClonePage().environmentObject(themeState)
            case .select:
                VoiceSelectPage().environmentObject(themeState)
            }
        }
    }
}

struct VoiceSelectPage: View {
    @EnvironmentObject var themeState: ThemeState
    @Environment(\.presentationMode) var presentationMode
    @State private var defaultVoices: [CustomVoiceItem] = VoiceItemProvider.defaultVoiceList()
    @State private var customVoices: [CustomVoiceItem] = []
    @State private var selectedId: String = VoiceMessageConfig.shared.getSelectedVoiceId()
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 0) {
            SubPageHeader(title: LocalizedChatString("VoiceSelect"), titleFont: FontScheme.body4Bold) {
                presentationMode.wrappedValue.dismiss()
            }
            List {
                Section(header: Text(LocalizedChatString("VoiceDefaultGroup"))) {
                    ForEach(defaultVoices, id: \.voiceId) { voice in
                        voiceRow(voice, isCustom: false)
                    }
                }
                Section(header: Text(LocalizedChatString("VoiceCustomGroup"))) {
                    if customVoices.isEmpty && !isLoading {
                        Text(LocalizedChatString("VoiceCustomEmpty"))
                            .font(FontScheme.caption2Regular)
                            .foregroundColor(themeState.colors.textColorTertiary)
                            .listRowBackground(themeState.colors.bgColorOperate)
                    } else {
                        ForEach(customVoices, id: \.voiceId) { voice in
                            voiceRow(voice, isCustom: true)
                        }
                        .onDelete(perform: deleteVoices)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
        }
        .background(themeState.colors.bgColorOperate.ignoresSafeArea())
        .onAppear { loadCustomVoices() }
    }

    private func voiceRow(_ voice: CustomVoiceItem, isCustom: Bool) -> some View {
        Button(action: { selectVoice(voice) }) {
            HStack {
                Text(voice.name)
                    .font(FontScheme.caption1Regular)
                    .foregroundColor(themeState.colors.textColorPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if isCustom {
                    Text(LocalizedChatString("VoiceCustomBadge"))
                        .font(FontScheme.caption4Regular)
                        .foregroundColor(themeState.colors.textColorButton)
                        .padding(.horizontal, CGFloat(SpacingScheme.iconTextSpacing))
                        .padding(.vertical, 2)
                        .background(themeState.colors.buttonColorPrimaryDefault)
                        .cornerRadius(CGFloat(RadiusScheme.tipsRadius))
                    Text(voice.voiceId)
                        .font(FontScheme.caption3Regular)
                        .foregroundColor(themeState.colors.textColorTertiary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer()
                if voice.voiceId == selectedId {
                    Image(systemName: "checkmark")
                        .foregroundColor(themeState.colors.textColorLink)
                }
            }
            .padding(.vertical, CGFloat(SpacingScheme.iconIconSpacing))
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .listRowBackground(themeState.colors.bgColorOperate)
    }

    private func selectVoice(_ voice: CustomVoiceItem) {
        VoiceMessageConfig.shared.setSelectedVoice(id: voice.voiceId, name: voice.name)
        selectedId = voice.voiceId
    }

    private func loadCustomVoices() {
        isLoading = true
        ExperimentalAPI.getCustomVoiceList(onSuccess: { list in
            self.isLoading = false
            self.customVoices = list
        }, onFailure: { _, _ in
            self.isLoading = false
            self.customVoices = []
        })
    }

    private func deleteVoices(at offsets: IndexSet) {
        for index in offsets {
            let voice = customVoices[index]
            ExperimentalAPI.deleteCustomVoice(voiceId: voice.voiceId, onSuccess: {
                self.customVoices.removeAll { $0.voiceId == voice.voiceId }
                if self.selectedId == voice.voiceId {
                    VoiceMessageConfig.shared.setSelectedVoice(id: "", name: "")
                    self.selectedId = ""
                }
            }, onFailure: { _, _ in })
        }
    }
}

private struct CloneWaveformView: View {
    @EnvironmentObject var themeState: ThemeState
    let samples: [CGFloat]

    var body: some View {
        HStack(alignment: .center, spacing: CGFloat(SpacingScheme.iconTextSpacing)) {
            ForEach(0 ..< 24, id: \.self) { index in
                let sample = index < samples.count ? samples[index] : 0.1
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(themeState.colors.buttonColorPrimaryDefault)
                    .frame(width: 3, height: max(3, sample * 36))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(themeState.colors.bgColorInput)
        .cornerRadius(CGFloat(RadiusScheme.alertRadius))
    }
}

struct VoiceClonePage: View {
    @EnvironmentObject var themeState: ThemeState
    @Environment(\.presentationMode) var presentationMode
    @State private var isRecording = false
    @State private var isSubmitting = false
    @State private var recordedPath: String? = nil
    @State private var durationMs = 0
    @State private var powerSamples: [CGFloat] = Array(repeating: 0.1, count: 24)
    @State private var statusKey = "VoiceCloneStart"
    @State private var voiceName = ""
    @State private var alertMessage: String? = nil
    @State private var showSuccess = false
    @State private var waveformTimer: Timer? = nil
    @State private var latestRealPower: CGFloat? = nil
    @State private var waveformPhase: CGFloat = 0

    private let minCloneSeconds = 3
    private let maxCloneMs = 30000

    private var canSubmit: Bool {
        recordedPath != nil && !isSubmitting && !isRecording
    }

    var body: some View {
        VStack(spacing: 0) {
            SubPageHeader(title: LocalizedChatString("VoiceClone"), titleFont: FontScheme.body4Bold) {
                cancelRecordingIfNeeded()
                presentationMode.wrappedValue.dismiss()
            }
            ScrollView {
                VStack(spacing: CGFloat(SpacingScheme.bubbleSpacing)) {
                    Text(LocalizedChatString("VoiceCloneTip"))
                        .font(FontScheme.caption2Regular)
                        .foregroundColor(themeState.colors.textColorSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(LocalizedChatString("VoiceCloneReadingTitle"))
                        .font(FontScheme.caption1Regular)
                        .foregroundColor(themeState.colors.textColorPrimary)
                        .frame(maxWidth: .infinity)
                    Text("“\(LocalizedChatString("VoiceCloneSample"))”")
                        .font(FontScheme.caption1Regular)
                        .foregroundColor(themeState.colors.textColorPrimary)
                        .frame(maxWidth: .infinity)
                    CloneWaveformView(samples: powerSamples)
                    Text(timeText())
                        .font(FontScheme.caption1Medium.monospacedDigit())
                        .foregroundColor(themeState.colors.textColorPrimary)
                        .frame(maxWidth: .infinity)
                    Button(action: toggleRecord) {
                        Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                            .font(FontScheme.body2Regular)
                            .foregroundColor(themeState.colors.textColorButton)
                            .frame(width: 64, height: 64)
                            .background(themeState.colors.buttonColorPrimaryDefault)
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(maxWidth: .infinity)
                    Text(LocalizedChatString(statusKey))
                        .font(FontScheme.caption2Regular)
                        .foregroundColor(themeState.colors.textColorSecondary)
                        .frame(maxWidth: .infinity)
                    Text(LocalizedChatString("VoiceCloneAuthTip"))
                        .font(FontScheme.caption3Regular)
                        .foregroundColor(themeState.colors.textColorTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    TextField("", text: $voiceName, prompt: Text(LocalizedChatString("VoiceCloneNameHint")).foregroundColor(themeState.colors.textColorTertiary))
                        .font(FontScheme.caption1Regular)
                        .foregroundColor(themeState.colors.textColorPrimary)
                        .padding(.horizontal, CGFloat(SpacingScheme.iconIconSpacing))
                        .frame(height: 44)
                        .background(themeState.colors.bgColorInput)
                        .cornerRadius(CGFloat(RadiusScheme.smallRadius))
                    Button(action: submit) {
                        ZStack {
                            if isSubmitting {
                                ProgressView().tint(themeState.colors.textColorButton)
                            } else {
                                Text(LocalizedChatString("VoiceCloneSubmit"))
                                    .font(FontScheme.caption1Regular)
                                    .foregroundColor(themeState.colors.textColorButton)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(canSubmit ? themeState.colors.buttonColorPrimaryDefault : themeState.colors.buttonColorPrimaryDisabled)
                        .cornerRadius(CGFloat(RadiusScheme.smallRadius))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(!canSubmit)
                }
                .padding(.horizontal, CGFloat(SpacingScheme.bubbleSpacing))
                .padding(.vertical, CGFloat(SpacingScheme.contentSpacing))
            }
            .onTapGesture { hideKeyboard() }
        }
        .background(themeState.colors.bgColorOperate.ignoresSafeArea())
        .onDisappear { cancelRecordingIfNeeded() }
        .alert(alertMessage ?? "", isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })) {
            Button(LocalizedChatString("AlertConfirm")) { alertMessage = nil }
        }
        .alert(LocalizedChatString("VoiceCloneSuccessTitle"), isPresented: $showSuccess) {
            Button(LocalizedChatString("AlertConfirm")) { presentationMode.wrappedValue.dismiss() }
        } message: {
            Text(LocalizedChatString("VoiceCloneSuccessMessage"))
        }
    }

    private func timeText() -> String {
        let totalSeconds = durationMs / 1000
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    private func toggleRecord() {
        guard !isSubmitting else { return }
        if isRecording {
            AudioRecorder.sharedRecorder.stopRecord()
            return
        }
        recordedPath = nil
        durationMs = 0
        powerSamples = Array(repeating: 0.1, count: 24)
        latestRealPower = nil
        waveformPhase = 0
        let recorder = AudioRecorder.sharedRecorder
        recorder.onRecordTime = { timeMs in
            DispatchQueue.main.async { self.durationMs = timeMs }
        }
        recorder.onPowerLevel = { power in
            self.latestRealPower = min(1, max(0.1, CGFloat(power + 60) / 60))
        }
        recorder.onRecordingComplete = { resultCode, filePath, durationSec in
            DispatchQueue.main.async {
                self.isRecording = false
                self.stopWaveformTimer()
                self.handleRecordComplete(resultCode: resultCode, filePath: filePath, durationSec: durationSec)
            }
        }
        isRecording = true
        statusKey = "VoiceCloneStop"
        startWaveformTimer()
        recorder.startRecord(minDurationMs: minCloneSeconds * 1000, maxDurationMs: maxCloneMs)
    }

    private func startWaveformTimer() {
        stopWaveformTimer()
        let timer = Timer(timeInterval: 0.1, repeats: true) { _ in
            DispatchQueue.main.async {
                self.waveformPhase += 0.6
                let next: CGFloat
                if let realPower = self.latestRealPower {
                    next = realPower
                } else {
                    let sine = (sin(self.waveformPhase) + 1) / 2
                    let jitter = CGFloat.random(in: -0.15 ... 0.15)
                    next = min(1, max(0.1, 0.25 + sine * 0.6 + jitter))
                }
                self.powerSamples.append(next)
                if self.powerSamples.count > 24 {
                    self.powerSamples.removeFirst(self.powerSamples.count - 24)
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        waveformTimer = timer
    }

    private func stopWaveformTimer() {
        waveformTimer?.invalidate()
        waveformTimer = nil
        latestRealPower = nil
    }

    private func handleRecordComplete(resultCode: AudioRecordResultCode, filePath: String, durationSec: Int) {
        switch resultCode {
        case .success, .exceedMaxDuration:
            if durationSec >= minCloneSeconds && !filePath.isEmpty {
                recordedPath = filePath
                durationMs = durationSec * 1000
                statusKey = "VoiceCloneDone"
            } else {
                resetRecordingState()
                alertMessage = LocalizedChatString("VoiceCloneTooShortMessage")
            }
        case .errorLessThanMinDuration:
            resetRecordingState()
            alertMessage = LocalizedChatString("VoiceCloneTooShortMessage")
        case .errorRecordPermissionDenied:
            resetRecordingState()
            alertMessage = LocalizedChatString("VoiceClonePermissionDenied")
        case .errorCancel:
            resetRecordingState()
        default:
            resetRecordingState()
            alertMessage = LocalizedChatString("VoiceCloneRecordFailed")
        }
    }

    private func resetRecordingState() {
        recordedPath = nil
        durationMs = 0
        statusKey = "VoiceCloneStart"
    }

    private func cancelRecordingIfNeeded() {
        guard isRecording else { return }
        AudioRecorder.sharedRecorder.cancelRecord()
        isRecording = false
        stopWaveformTimer()
    }

    private func submit() {
        guard let path = recordedPath, !path.isEmpty else {
            alertMessage = LocalizedChatString("VoiceCloneEmptyRecord")
            return
        }
        guard !isSubmitting else { return }
        let trimmedName = voiceName.trimmingCharacters(in: .whitespaces)
        let name = trimmedName.isEmpty ? LocalizedChatString("VoiceCloneDefaultName") : trimmedName
        isSubmitting = true
        ExperimentalAPI.voiceClone(filePath: path, voiceName: name, onSuccess: { voiceId in
            self.isSubmitting = false
            VoiceMessageConfig.shared.setSelectedVoice(id: voiceId, name: name)
            self.showSuccess = true
        }, onFailure: { _, _ in
            self.isSubmitting = false
            self.alertMessage = LocalizedChatString("VoiceCloneFailed")
        })
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct AboutPage: View {
    @EnvironmentObject var themeState: ThemeState
    @Environment(\.presentationMode) var presentationMode
    @State private var showDisclaimer = false

    private let privacyURL = "https://privacy.qq.com/document/preview/1cfe904fb7004b8ab1193a55857f7272"
    private let userAgreementURL = "https://web.sdk.qcloud.com/document/Tencent-IM-User-Agreement.html"
    private let personalInformationURL = "https://privacy.qq.com/document/preview/45ba982a1ce6493597a00f8c86b52a1e"
    private let thirdPartySharingURL = "https://privacy.qq.com/document/preview/dea84ac4bb88454794928b77126e9246"
    private let contactUsURL = "https://cloud.tencent.com/document/product/269/59590"
    private let icpBeianURL = "https://beian.miit.gov.cn"

    var body: some View {
        VStack(spacing: 0) {
            SubPageHeader(title: LocalizedChatString("AboutTencentIM")) { presentationMode.wrappedValue.dismiss() }
            Rectangle().fill(themeState.colors.bgColorTopBar).frame(height: 10)
            VStack(spacing: 0) {
                aboutRow(title: LocalizedChatString("AboutSDKVersion"), value: ExperimentalAPI.sdkVersion(), showArrow: false, action: nil)
                aboutDivider
                aboutRow(title: LocalizedChatString("AboutPrivacyRegulations"), value: "", showArrow: true) { open(privacyURL) }
                aboutDivider
                aboutRow(title: LocalizedChatString("AboutUserAgreement"), value: "", showArrow: true) { open(userAgreementURL) }
                aboutDivider
                aboutRow(title: LocalizedChatString("AboutDisclaimer"), value: "", showArrow: true) { showDisclaimer = true }
                aboutDivider
                aboutRow(title: LocalizedChatString("AboutPersonalInformationCollectionList"), value: "", showArrow: true) { open(personalInformationURL) }
                aboutDivider
                aboutRow(title: LocalizedChatString("About3PartySharingList"), value: "", showArrow: true) { open(thirdPartySharingURL) }
                aboutDivider
                aboutRow(title: LocalizedChatString("AboutContactUs"), value: "", showArrow: true) { open(contactUsURL) }
            }
            Spacer()
            VStack(spacing: CGFloat(SpacingScheme.iconIconSpacing)) {
                Button(action: { open(icpBeianURL) }) {
                    Text("ICP备案号：粤B2-20090059-2674A >")
                        .font(FontScheme.caption3Regular)
                        .foregroundColor(themeState.colors.textColorTertiary)
                }
                Text("腾讯公司 版权所有")
                    .font(FontScheme.caption3Regular)
                    .foregroundColor(themeState.colors.textColorTertiary)
                Text("Copyright © 2020-2024 Tencent. All Rights Reserved.")
                    .font(FontScheme.caption3Regular)
                    .foregroundColor(themeState.colors.textColorTertiary)
            }
            .padding(.bottom, 34)
        }
        .background(themeState.colors.bgColorTopBar.ignoresSafeArea())
        .alert(LocalizedChatString("AboutDisclaimer"), isPresented: $showDisclaimer) {
            Button(LocalizedChatString("Accept"), role: .destructive) {}
        } message: {
            Text(LocalizedChatString("AboutDisclaimerText"))
        }
    }

    private var aboutDivider: some View {
        Rectangle().fill(themeState.colors.strokeColorPrimary).frame(height: 0.5)
    }

    private func aboutRow(title: String, value: String, showArrow: Bool, action: (() -> Void)?) -> some View {
        Button(action: { action?() }) {
            HStack {
                Text(title)
                    .font(FontScheme.caption1Regular)
                    .foregroundColor(themeState.colors.textColorSecondary)
                Spacer()
                if !value.isEmpty {
                    Text(value)
                        .font(FontScheme.caption1Regular)
                        .foregroundColor(themeState.colors.textColorPrimary)
                }
                if showArrow {
                    Image("contact_info_arrow_right", bundle: AtomicXChatResources.resourceBundle)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .foregroundColor(themeState.colors.textColorTertiary)
                }
            }
            .padding(.horizontal, CGFloat(SpacingScheme.bubbleSpacing))
            .padding(.vertical, CGFloat(SpacingScheme.iconIconSpacing))
            .frame(minHeight: 48)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(themeState.colors.bgColorOperate)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(action == nil)
    }

    private func open(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}

struct SettingsBottomOptionSheet: View {
    @EnvironmentObject var themeState: ThemeState
    @Environment(\.presentationMode) var presentationMode
    let optionTitles: [String]
    let onSelect: (Int) -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Colors.Black1.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { presentationMode.wrappedValue.dismiss() }
            VStack(spacing: CGFloat(SpacingScheme.smallSpacing)) {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(optionTitles.enumerated()), id: \.offset) { index, title in
                                if index > 0 {
                                    Rectangle().fill(themeState.colors.strokeColorPrimary).frame(height: 0.5)
                                }
                                Button(action: {
                                    presentationMode.wrappedValue.dismiss()
                                    onSelect(index)
                                }) {
                                    Text(title)
                                        .font(FontScheme.caption1Regular)
                                        .foregroundColor(themeState.colors.textColorLink)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 56)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .frame(maxHeight: UIScreen.main.bounds.height * 0.5)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .background(themeState.colors.bgColorOperate)
                .cornerRadius(CGFloat(RadiusScheme.largeRadius))
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Text(LocalizedChatString("Cancel"))
                        .font(FontScheme.caption1Medium)
                        .foregroundColor(themeState.colors.textColorLink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(themeState.colors.bgColorOperate)
                        .cornerRadius(CGFloat(RadiusScheme.largeRadius))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, CGFloat(SpacingScheme.smallSpacing))
            .padding(.bottom, CGFloat(SpacingScheme.smallSpacing))
        }
        .background(ClearBackgroundView())
    }
}

struct ClearBackgroundView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        DispatchQueue.main.async {
            view.superview?.superview?.backgroundColor = .clear
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

enum Theme: String, CaseIterable {
    case light = "Light"
    case dark = "Dark"
    case custom = "Custom"
}

struct ThemePicker: View {
    @Binding var selectedTheme: Theme
    @EnvironmentObject var themeState: ThemeState
    var body: some View {
        NavigationView {
            List {
                ForEach(Theme.allCases, id: \.self) { theme in
                    Button(action: {
                        selectedTheme = theme
                    }) {
                        HStack {
                            Text(theme.rawValue)
                            if selectedTheme == theme {
                                Spacer()
                                Image(systemName: "checkmark")
                                    .foregroundColor(themeState.colors.buttonColorPrimaryDefault)
                            }
                        }
                    }
                }
            }
            .navigationBarTitle(LocalizedChatString("SelectTheme"), displayMode: .inline)
        }
    }
}

struct ProfileDetailView: View {
    @EnvironmentObject var themeState: ThemeState
    @EnvironmentObject var languageState: LanguageState
    @ObservedObject private var loginManager = LoginStatusManager.shared
    @State private var loginStore = LoginStore.shared
    @State private var showingAvatarPicker = false
    @State private var showingNicknameSheet = false
    @State private var showingSignatureSheet = false
    @State private var showingGenderActionSheet = false
    @State private var showingGenderSheet = false
    @State private var showingDatePicker = false
    @State private var gender: Gender? = nil
    @State private var selectedDate = Date()
    @State private var birthday: UInt32? = nil
    @State private var nickname: String?
    @State private var avatar: String?
    @State private var selfSignature: String?

    private func getNickName() -> String {
        if let nickname = loginStore.state.value.loginUserInfo?.nickname, !nickname.isEmpty {
            return nickname
        }
        return loginManager.currentUserID
    }

    private func displayName() -> String {
        let nickname = loginStore.state.value.loginUserInfo?.nickname ?? ""
        return nickname.isEmpty ? loginManager.currentUserID : nickname
    }

    private func genderText() -> String {
        switch gender {
        case .male: return LocalizedChatString("Male")
        case .female: return LocalizedChatString("Female")
        default: return LocalizedChatString("GenderSecret")
        }
    }

    private func birthdayText() -> String {
        let birthday = birthday ?? loginStore.state.value.loginUserInfo?.birthday
        guard let birthday = birthday, birthday > 0 else { return "1970-01-01" }
        let raw = String(birthday)
        guard raw.count == 8 else { return "1970-01-01" }
        let year = raw.prefix(4)
        let month = raw.dropFirst(4).prefix(2)
        let day = raw.dropFirst(6).prefix(2)
        return "\(year)-\(month)-\(day)"
    }

    private func birthdayDate() -> Date {
        let birthday = birthday ?? loginStore.state.value.loginUserInfo?.birthday
        guard let birthday = birthday, birthday > 0 else { return Date() }
        let raw = String(birthday)
        guard raw.count == 8, let year = Int(raw.prefix(4)), let month = Int(raw.dropFirst(4).prefix(2)), let day = Int(raw.dropFirst(6).prefix(2)) else { return Date() }
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components) ?? Date()
    }

    private func infoRow(title: String, value: String, showArrow: Bool, showDivider: Bool, action: (() -> Void)?) -> some View {
        VStack(spacing: 0) {
            Button(action: { action?() }) {
                HStack {
                    Text(title)
                        .font(FontScheme.caption1Regular)
                        .foregroundColor(themeState.colors.textColorSecondary)
                    Spacer()
                    Text(value)
                        .font(FontScheme.caption1Regular)
                        .foregroundColor(themeState.colors.textColorPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if showArrow {
                        Image("contact_info_arrow_right", bundle: AtomicXChatResources.resourceBundle)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                            .foregroundColor(themeState.colors.textColorTertiary)
                    }
                }
                .padding(.horizontal, CGFloat(SpacingScheme.bubbleSpacing))
                .padding(.vertical, CGFloat(SpacingScheme.iconIconSpacing))
                .frame(minHeight: 48)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(action == nil)
            if showDivider {
                Rectangle().fill(themeState.colors.strokeColorPrimary).frame(height: 0.5)
            }
        }
        .background(themeState.colors.bgColorOperate)
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                Button(action: { showingAvatarPicker = true }) {
                    AvatarView(url: avatar, name: displayName(), size: .xxl, shape: .round)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.top, CGFloat(SpacingScheme.bubbleSpacing))
                Text(displayName())
                    .font(FontScheme.caption1Regular)
                    .foregroundColor(themeState.colors.textColorPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, CGFloat(SpacingScheme.bubbleSpacing))
                    .padding(.top, CGFloat(SpacingScheme.bubbleSpacing))
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 0) {
                infoRow(title: LocalizedChatString("ProfileAccount"), value: loginStore.state.value.loginUserInfo?.userID ?? loginManager.currentUserID, showArrow: false, showDivider: true, action: nil)
                infoRow(title: LocalizedChatString("ProfileNickname"), value: loginStore.state.value.loginUserInfo?.nickname ?? "", showArrow: true, showDivider: true) { showingNicknameSheet = true }
                infoRow(title: LocalizedChatString("ProfileStatus"), value: loginStore.state.value.loginUserInfo?.selfSignature ?? "", showArrow: true, showDivider: true) { showingSignatureSheet = true }
                infoRow(title: LocalizedChatString("ProfileGender"), value: genderText(), showArrow: true, showDivider: true) { showingGenderActionSheet = true }
                infoRow(title: LocalizedChatString("ProfileBirthday"), value: birthdayText(), showArrow: true, showDivider: false) {
                    selectedDate = birthdayDate()
                    showingDatePicker = true
                }
            }
            .padding(.top, 36)

            Spacer()
        }
        .background(themeState.colors.bgColorTopBar.ignoresSafeArea())
        .navigationBarTitle(LocalizedChatString("ProfileDetails"), displayMode: .inline)
        .onReceive(loginStore.state.subscribe(StatePublisherSelector(keyPath: \LoginState.loginUserInfo?.avatarURL))) { self.avatar = $0 }
        .onReceive(loginStore.state.subscribe(StatePublisherSelector(keyPath: \LoginState.loginUserInfo?.nickname))) { self.nickname = $0 }
        .onReceive(loginStore.state.subscribe(StatePublisherSelector(keyPath: \LoginState.loginUserInfo?.selfSignature))) { self.selfSignature = $0 }
        .onReceive(loginStore.state.subscribe(StatePublisherSelector(keyPath: \LoginState.loginUserInfo?.gender))) { self.gender = $0 }
        .onReceive(loginStore.state.subscribe(StatePublisherSelector(keyPath: \LoginState.loginUserInfo?.birthday))) { self.birthday = $0 }
        .onAppear {
            self.avatar = loginStore.state.value.loginUserInfo?.avatarURL
            self.nickname = loginStore.state.value.loginUserInfo?.nickname
            self.selfSignature = loginStore.state.value.loginUserInfo?.selfSignature
            self.gender = loginStore.state.value.loginUserInfo?.gender
            self.birthday = loginStore.state.value.loginUserInfo?.birthday
        }
        .fullScreenCover(isPresented: $showingGenderActionSheet) {
            SettingsBottomOptionSheet(optionTitles: [LocalizedChatString("Male"), LocalizedChatString("Female"), LocalizedChatString("GenderSecret")]) { index in
                let genders: [Gender] = [.male, .female, .unknown]
                if index < genders.count { updateGender(genders[index]) }
            }
            .environmentObject(themeState)
        }
        .background(
            NavigationLink(
                destination: AvatarSelectorView(imageUrlList: createUserAvatarUrlList(), column: 4, onComplete: { selectedImageUrl in
                    if let userID = loginStore.state.value.loginUserInfo?.userID {
                        let user = UserProfile(userID: userID, nickname: nil, avatarURL: selectedImageUrl)
                        loginStore.setSelfInfo(userProfile: user, completion: nil)
                    }
                }),
                isActive: $showingAvatarPicker
            ) { EmptyView() }
            .hidden()
        )
        .sheet(isPresented: $showingNicknameSheet) {
            nicknameEditSheet(currentNickname: loginStore.state.value.loginUserInfo?.nickname ?? "", onSave: { newNickname in
                let trimmed = newNickname.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty, let userID = loginStore.state.value.loginUserInfo?.userID {
                    let user = UserProfile(userID: userID, nickname: newNickname)
                    loginStore.setSelfInfo(userProfile: user, completion: nil)
                }
            })
            .modifier(SheetModifier())
        }
        .sheet(isPresented: $showingSignatureSheet) {
            selfSignatureEditSheet(currentSignature: loginStore.state.value.loginUserInfo?.selfSignature ?? "", onSave: { selfSignature in
                if let userID = loginStore.state.value.loginUserInfo?.userID {
                    var user = UserProfile(userID: userID)
                    user.selfSignature = selfSignature
                    loginStore.setSelfInfo(userProfile: user, completion: nil)
                }
            })
            .modifier(SheetModifier())
        }
        .sheet(isPresented: $showingDatePicker) {
            birthdayEditSheet(currentDate: selectedDate, onSave: { newDate in updateBirthday(newDate) })
                .environmentObject(languageState)
                .modifier(SheetModifier())
        }
    }

    private func createUserAvatarUrlList() -> [String] {
        (1 ... 26).map { "https://im.sdk.qcloud.com/download/tuikit-resource/avatar/avatar_\($0).png" }
    }

    private func updateGender(_ gender: Gender) {
        if let userID = loginStore.state.value.loginUserInfo?.userID {
            var user = UserProfile(userID: userID)
            user.gender = gender
            loginStore.setSelfInfo(userProfile: user, completion: nil)
        }
    }

    private func updateBirthday(_ date: Date) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        if let userID = loginStore.state.value.loginUserInfo?.userID {
            var user = UserProfile(userID: userID)
            user.birthday = UInt32(formatter.string(from: date))
            loginStore.setSelfInfo(userProfile: user, completion: nil)
        }
    }
}

private struct nicknameEditSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var newNickname: String = ""
    let currentNickname: String
    let onSave: (String) -> Void

    var body: some View {
        TextEditSheetView(
            title: LocalizedChatString("ProfileEditName"),
            currentText: currentNickname,
            placeholder: LocalizedChatString("ProfileEditName"),
            helpText: LocalizedChatString("ProfileEditNameDesc"),
            onSave: onSave
        )
    }
}

private struct selfSignatureEditSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var newSignature: String = ""
    let currentSignature: String
    let onSave: (String) -> Void

    var body: some View {
        TextEditSheetView(
            title: LocalizedChatString("ProfileEditSignture"),
            currentText: currentSignature,
            placeholder: LocalizedChatString("ProfileEditSignture"),
            helpText: LocalizedChatString("ProfileEditNameDesc"),
            onSave: onSave
        )
    }
}

private struct birthdayEditSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var languageState: LanguageState
    @EnvironmentObject var themeState: ThemeState
    @State private var selectedDate: Date
    let currentDate: Date
    let onSave: (Date) -> Void

    init(currentDate: Date, onSave: @escaping (Date) -> Void) {
        self.currentDate = currentDate
        self.onSave = onSave
        self._selectedDate = State(initialValue: currentDate)
    }

    var body: some View {
        VStack(spacing: CGFloat(SpacingScheme.contentSpacing)) {
            HStack(spacing: CGFloat(SpacingScheme.contentSpacing)) {
                Button(LocalizedChatString("Cancel")) {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(themeState.colors.textColorLink)

                Spacer()

                Button(LocalizedChatString("Save")) {
                    onSave(selectedDate)
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(themeState.colors.textColorLink)
            }
            .padding(.horizontal)

            DatePicker(
                "",
                selection: $selectedDate,
                displayedComponents: .date
            )
            .datePickerStyle(WheelDatePickerStyle())
            .labelsHidden()
            .environment(\.locale, Locale(identifier: languageState.currentLanguage))
        }
    }
}

private struct GenderActionSheetModifier: ViewModifier {
    @Binding var isPresented: Bool
    let onGenderSelected: (Int) -> Void

    func body(content: Content) -> some View {
        content
            .confirmationDialog(LocalizedChatString("ProfileEditGender"), isPresented: $isPresented, titleVisibility: .visible) {
                Button(LocalizedChatString("Male")) {
                    onGenderSelected(1)
                }
                Button(LocalizedChatString("Female")) {
                    onGenderSelected(2)
                }
                Button(LocalizedChatString("Cancel"), role: .cancel) {}
            }
    }
}

private struct SheetModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.hidden)
                .interactiveDismissDisabled(false)
        } else {
            content
        }
    }
}

private struct ListBackgroundModifier: ViewModifier {
    let backgroundColor: Color

    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content
                .scrollContentBackground(.hidden)
                .background(backgroundColor)
        } else {
            content
                .onAppear {
                    UITableView.appearance().backgroundColor = .clear
                }
                .background(backgroundColor)
        }
    }
}

private struct GradientSlider: View {
    let gradientColors: [Color]
    let thumbColor: Color
    @Binding var progress: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let trackHeight: CGFloat = 24
            let thumbRadius = trackHeight / 2
            let usableWidth = max(geometry.size.width - thumbRadius * 2, 1)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(LinearGradient(colors: gradientColors, startPoint: .leading, endPoint: .trailing))
                    .frame(height: trackHeight)
                Circle()
                    .fill(Colors.White1)
                    .shadow(color: Colors.Black1.opacity(0.16), radius: 2, x: 0, y: 1)
                    .overlay(Circle().fill(thumbColor).padding(3))
                    .overlay(Circle().stroke(Colors.Black1.opacity(0.16), lineWidth: 1))
                    .frame(width: trackHeight, height: trackHeight)
                    .offset(x: thumbRadius + progress * usableWidth - thumbRadius)
            }
            .frame(height: trackHeight)
            .padding(.vertical, CGFloat(SpacingScheme.iconTextSpacing))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let clampedX = min(max(value.location.x, thumbRadius), geometry.size.width - thumbRadius)
                        progress = (clampedX - thumbRadius) / usableWidth
                    }
            )
        }
        .frame(height: 32)
    }
}

struct PrimaryColorPickerView: View {
    static let defaultPrimaryHex = "#1C66E5"
    @EnvironmentObject var themeState: ThemeState
    @Environment(\.presentationMode) var presentationMode
    let onColorSelected: (String) -> Void
    @State private var hue: CGFloat
    @State private var saturation: CGFloat
    @State private var brightness: CGFloat

    init(selectedHex: String, onColorSelected: @escaping (String) -> Void) {
        self.onColorSelected = onColorSelected
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(Color(hexString: selectedHex)).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        _hue = State(initialValue: h * 360)
        _saturation = State(initialValue: s)
        _brightness = State(initialValue: b)
    }

    private var currentColor: Color {
        Color(hue: hue / 360, saturation: saturation, brightness: brightness)
    }

    private var hueGradient: [Color] {
        (0 ... 6).map { Color(hue: Double($0) / 6.0, saturation: 1, brightness: 1) }
    }

    private var saturationGradient: [Color] {
        [Color(hue: hue / 360, saturation: 0, brightness: brightness), Color(hue: hue / 360, saturation: 1, brightness: brightness)]
    }

    private var brightnessGradient: [Color] {
        [Colors.Black1, Color(hue: hue / 360, saturation: saturation, brightness: 1)]
    }

    var body: some View {
        ZStack {
            Colors.Black1.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { presentationMode.wrappedValue.dismiss() }
            VStack(spacing: 0) {
                Text(LocalizedChatString("SelectThemeColorTitle"))
                    .font(FontScheme.caption1Bold)
                    .foregroundColor(themeState.colors.textColorPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, CGFloat(SpacingScheme.iconIconSpacing))
                Circle()
                    .fill(currentColor)
                    .frame(width: 48, height: 48)
                    .overlay(Circle().stroke(themeState.colors.strokeColorPrimary, lineWidth: 1.5))
                    .padding(.bottom, CGFloat(SpacingScheme.smallSpacing))
                Text(currentColorHex())
                    .font(FontScheme.caption2Regular)
                    .foregroundColor(themeState.colors.textColorSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, CGFloat(SpacingScheme.iconIconSpacing))
                labeledSlider(title: LocalizedChatString("ThemeColorHue"), gradient: hueGradient, progress: $hue, range: 360)
                labeledSlider(title: LocalizedChatString("ThemeColorSaturation"), gradient: saturationGradient, progress: $saturation, range: 1)
                labeledSlider(title: LocalizedChatString("ThemeColorBrightness"), gradient: brightnessGradient, progress: $brightness, range: 1, last: true)
                HStack {
                    Button(action: resetColor) {
                        Text(LocalizedChatString("ThemeColorReset"))
                            .font(FontScheme.caption1Regular)
                            .foregroundColor(themeState.colors.textColorSecondary)
                            .frame(minWidth: 72, minHeight: 44)
                    }
                    Spacer()
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Text(LocalizedChatString("Cancel"))
                            .font(FontScheme.caption1Regular)
                            .foregroundColor(themeState.colors.textColorSecondary)
                            .frame(minWidth: 72, minHeight: 44)
                    }
                    Button(action: {
                        onColorSelected(currentColorHex())
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text(LocalizedChatString("Confirm"))
                            .font(FontScheme.caption1Bold)
                            .foregroundColor(themeState.colors.textColorLink)
                            .frame(minWidth: 72, minHeight: 44)
                    }
                }
            }
            .padding(CGFloat(SpacingScheme.bubbleSpacing))
            .background(themeState.colors.bgColorDialog)
            .cornerRadius(CGFloat(RadiusScheme.alertRadius))
            .padding(.horizontal, 36)
        }
        .background(ClearBackgroundView())
    }

    private func labeledSlider(title: String, gradient: [Color], progress: Binding<CGFloat>, range: CGFloat, last: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: CGFloat(SpacingScheme.iconTextSpacing)) {
            Text(title)
                .font(FontScheme.caption3Regular)
                .foregroundColor(themeState.colors.textColorSecondary)
            GradientSlider(
                gradientColors: gradient,
                thumbColor: currentColor,
                progress: Binding(
                    get: { progress.wrappedValue / range },
                    set: { progress.wrappedValue = $0 * range }
                )
            )
        }
        .padding(.bottom, CGFloat(last ? SpacingScheme.bubbleSpacing : SpacingScheme.iconIconSpacing))
    }

    private func currentColorHex() -> String {
        currentColor.hexString()
    }

    private func resetColor() {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(Color(hexString: Self.defaultPrimaryHex)).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        hue = h * 360
        saturation = s
        brightness = b
    }
}

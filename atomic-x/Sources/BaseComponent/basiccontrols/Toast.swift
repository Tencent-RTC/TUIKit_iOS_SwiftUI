import SwiftUI

private class ToastBundle {}
private extension Bundle {
    static var toastBundle: Bundle {
        return AtomicXChatResources.resourceBundle
    }
}

public enum ToastType {
    case loading
    case info
    case success
    case warning
    case error
    case help
    var iconName: String {
        switch self {
        case .loading:
            return "loading-blue"
        case .info:
            return "info-circle-filled"
        case .success:
            return "check-circle-filled"
        case .warning:
            return "error-circle-filled"
        case .error:
            return "error-circle-filled"
        case .help:
            return "help-circle-filled"
        }
    }
}

public struct IconToast: View {
    @EnvironmentObject var themeState: ThemeState
    @State private var isAnimating = false
    let type: ToastType
    let message: String
    let customIcon: String?
    let isVisible: Bool
    let onDismiss: () -> Void

    public init(
        type: ToastType = .info,
        message: String,
        customIcon: String? = nil,
        isVisible: Bool,
        onDismiss: @escaping () -> Void = {}
    ) {
        self.type = type
        self.message = message
        self.customIcon = customIcon
        self.isVisible = isVisible
        self.onDismiss = onDismiss
    }

    public var body: some View {
        if isVisible {
            HStack(alignment: .center, spacing: 4) {
                // Icon
                if type == .loading {
                    Image(type.iconName, bundle: Bundle.toastBundle)
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(themeState.colors.textColorLink)
                        .frame(width: 16, height: 16)
                        .rotationEffect(.degrees(isAnimating ? 360 : 0))
                        .animation(
                            isAnimating ? Animation.linear(duration: 1.0).repeatForever(autoreverses: false) : .default,
                            value: isAnimating
                        )
                        .onAppear { isAnimating = true }
                        .onDisappear { isAnimating = false }
                } else {
                    Image(type.iconName, bundle: Bundle.toastBundle)
                        .renderingMode(.template)
                        .foregroundColor(iconColor(type))
                        .frame(width: 16, height: 16)
                }
                // Message
                Text(message)
                    .font(themeState.fonts.caption2Medium)
                    .foregroundColor(themeState.colors.textColorPrimary)
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(themeState.colors.floatingColorDefault)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(themeState.colors.strokeColorSecondary, lineWidth: 1)
                    )
                    .shadow(
                        color: themeState.colors.shadowColor,
                        radius: 8,
                        x: 0,
                        y: 6
                    )
                    .shadow(
                        color: themeState.colors.shadowColor,
                        radius: 3,
                        x: 0,
                        y: 1
                    )
            )
            .transition(.opacity)
            .onTapGesture {
                onDismiss()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .compatibleIgnoreSafeArea()
        } else {
            Color.clear
                .frame(width: 0, height: 0)
        }
    }

    func iconColor(_ toastType: ToastType) -> Color {
        switch toastType {
        case .loading:
            return themeState.colors.textColorLink
        case .info:
            return themeState.colors.textColorLink
        case .success:
            return themeState.colors.textColorSuccess
        case .warning:
            return themeState.colors.textColorWarning
        case .error:
            return themeState.colors.textColorError
        case .help:
            return themeState.colors.textColorLink
        }
    }
}

public struct SimpleToast: View {
    @EnvironmentObject var themeState: ThemeState
    let message: String
    let isVisible: Bool
    let onDismiss: () -> Void

    public init(
        message: String,
        isVisible: Bool,
        onDismiss: @escaping () -> Void = {}
    ) {
        self.message = message
        self.isVisible = isVisible
        self.onDismiss = onDismiss
    }

    public var body: some View {
        if isVisible {
            Text(message)
                .font(themeState.fonts.caption2Medium)
                .foregroundColor(themeState.colors.textColorPrimary)
                .lineLimit(nil)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(themeState.colors.floatingColorDefault)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(themeState.colors.strokeColorSecondary, lineWidth: 1)
                        )
                        .shadow(
                            color: themeState.colors.shadowColor,
                            radius: 8,
                            x: 0,
                            y: 6
                        )
                        .shadow(
                            color: themeState.colors.shadowColor,
                            radius: 3,
                            x: 0,
                            y: 1
                        )
                )
                .transition(.opacity)
                .onTapGesture {
                    onDismiss()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .compatibleIgnoreSafeArea()
        }
    }
}

public class Toast: ObservableObject {
    @Published public var isVisible = false
    @Published public var type: ToastType = .info
    @Published public var message = ""
    @Published public var customIcon: String? = nil
    @Published public var isSimpleVisible = false
    @Published public var simpleMessage = ""
    private var hideTimer: Timer?
    private var simpleHideTimer: Timer?
    public init() {}

    public func loading(_ message: String) {
        runOnMain {
            self.showWithIcon(type: .loading, message: message)
        }
    }

    public func info(_ message: String) {
        runOnMain {
            self.showWithIcon(type: .info, message: message)
        }
    }

    public func success(_ message: String) {
        runOnMain {
            self.showWithIcon(type: .success, message: message)
        }
    }

    public func warning(_ message: String) {
        runOnMain {
            self.showWithIcon(type: .warning, message: message)
        }
    }

    public func error(_ message: String) {
        runOnMain {
            self.showWithIcon(type: .error, message: message)
        }
    }

    public func simple(_ message: String) {
        runOnMain {
            self.showSimpleToast(message: message)
        }
    }

    public func show(
        _ message: String,
        type: ToastType? = nil,
        icon: String? = nil,
        duration: TimeInterval = 2.0
    ) {
        runOnMain {
            if let type = type {
                self.showWithIcon(type: type, message: message, customIcon: icon, duration: duration)
            } else {
                self.showSimpleToast(message: message, duration: duration)
            }
        }
    }

    public func hide() {
        isVisible = false
        hideTimer?.invalidate()
    }

    public func hideSimple() {
        isSimpleVisible = false
        simpleHideTimer?.invalidate()
    }

    private func showWithIcon(
        type: ToastType,
        message: String,
        customIcon: String? = nil,
        duration: TimeInterval = 2.0
    ) {
        self.type = type
        self.message = message
        self.customIcon = customIcon
        isVisible = true
        if isSimpleVisible {
            hideSimple()
        }
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { _ in
            DispatchQueue.main.async {
                self.hide()
            }
        }
    }

    private func showSimpleToast(
        message: String,
        duration: TimeInterval = 2.0
    ) {
        hide()
        simpleMessage = message
        isSimpleVisible = true
        simpleHideTimer?.invalidate()
        simpleHideTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { _ in
            DispatchQueue.main.async {
                self.hideSimple()
            }
        }
    }

    private func runOnMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async {
                block()
            }
        }
    }
}

// MARK: - Window-based Global Toast Manager

private class ToastWindow: UIWindow {
    override init(windowScene: UIWindowScene) {
        super.init(windowScene: windowScene)
        self.windowLevel = UIWindow.Level.alert + 2 // Higher than alert
        self.backgroundColor = UIColor.clear
        self.isHidden = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var canBecomeKey: Bool {
        return false
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitView = super.hitTest(point, with: event)
        
        guard let hitView = hitView,
              hitView != self,
              hitView != self.rootViewController?.view else {
            return nil 
        }
        
        return hitView
    }
}

private class ToastHostingController: UIHostingController<AnyView> {
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .default
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.clear
    }
}

public class WindowToastManager: ObservableObject {
    public static let shared = WindowToastManager()
    
    @Published public var isVisible = false
    @Published public var type: ToastType = .info
    @Published public var message = ""
    @Published public var customIcon: String? = nil
    @Published public var isSimpleVisible = false
    @Published public var simpleMessage = ""
    
    private var toastWindow: ToastWindow?
    private var hostingController: ToastHostingController?
    private var hideTimer: Timer?
    private var simpleHideTimer: Timer?
    
    private init() {}
    
    public func loading(_ message: String) {
        runOnMain {
            self.showWithIcon(type: .loading, message: message)
        }
    }
    
    public func info(_ message: String) {
        runOnMain {
            self.showWithIcon(type: .info, message: message)
        }
    }
    
    public func success(_ message: String) {
        runOnMain {
            self.showWithIcon(type: .success, message: message)
        }
    }
    
    public func warning(_ message: String) {
        runOnMain {
            self.showWithIcon(type: .warning, message: message)
        }
    }
    
    public func error(_ message: String) {
        runOnMain {
            self.showWithIcon(type: .error, message: message)
        }
    }
    
    public func simple(_ message: String) {
        runOnMain {
            self.showSimpleToast(message: message)
        }
    }
    
    public func show(
        _ message: String,
        type: ToastType? = nil,
        icon: String? = nil,
        duration: TimeInterval = 2.0
    ) {
        runOnMain {
            if let type = type {
                self.showWithIcon(type: type, message: message, customIcon: icon, duration: duration)
            } else {
                self.showSimpleToast(message: message, duration: duration)
            }
        }
    }
    
    public func hide() {
        isVisible = false
        hideTimer?.invalidate()
        dismissToast()
    }
    
    public func hideSimple() {
        isSimpleVisible = false
        simpleHideTimer?.invalidate()
        dismissToast()
    }
    
    private func showWithIcon(
        type: ToastType,
        message: String,
        customIcon: String? = nil,
        duration: TimeInterval = 2.0
    ) {
        self.type = type
        self.message = message
        self.customIcon = customIcon
        isVisible = true
        if isSimpleVisible {
            hideSimple()
        }
        
        presentToast()
        
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { _ in
            DispatchQueue.main.async {
                self.hide()
            }
        }
    }
    
    private func showSimpleToast(
        message: String,
        duration: TimeInterval = 2.0
    ) {
        hide()
        simpleMessage = message
        isSimpleVisible = true
        
        presentToast()
        
        simpleHideTimer?.invalidate()
        simpleHideTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { _ in
            DispatchQueue.main.async {
                self.hideSimple()
            }
        }
    }
    
    private func presentToast() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            print("WindowToastManager: No window scene found")
            return
        }
        
        let themeState = DefaultTheme
        
        toastWindow = ToastWindow(windowScene: windowScene)
        let toastView = AnyView(WindowToastView().environmentObject(themeState))
        hostingController = ToastHostingController(rootView: toastView)
        
        toastWindow?.rootViewController = hostingController
        toastWindow?.isHidden = false
        
    }
    
    private func dismissToast() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.toastWindow?.isHidden = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.toastWindow = nil
                self.hostingController = nil
            }
        }
    }
    
    private func runOnMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async {
                block()
            }
        }
    }
}

public struct WindowToastView: View {
    @ObservedObject private var toastManager = WindowToastManager.shared
    
    public init() {}
    
    public var body: some View {
        ZStack {
            if toastManager.isVisible {
                IconToast(
                    type: toastManager.type,
                    message: toastManager.message,
                    customIcon: toastManager.customIcon,
                    isVisible: true
                ) {
                    toastManager.hide()
                }
            }
            if toastManager.isSimpleVisible {
                SimpleToast(
                    message: toastManager.simpleMessage,
                    isVisible: true
                ) {
                    toastManager.hideSimple()
                }
            }
        }
    }
}

// MARK: - Original View Extension (kept for backward compatibility)

public extension View {
    func toast(_ toast: Toast) -> some View {
        ZStack {
            self
            if toast.isVisible {
                IconToast(
                    type: toast.type,
                    message: toast.message,
                    customIcon: toast.customIcon,
                    isVisible: true
                ) {
                    toast.hide()
                }
            }
            if toast.isSimpleVisible {
                SimpleToast(
                    message: toast.simpleMessage,
                    isVisible: true
                ) {
                    toast.hideSimple()
                }
            }
        }
        .environmentObject(toast)
    }
}

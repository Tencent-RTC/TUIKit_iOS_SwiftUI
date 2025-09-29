import SwiftUI
import UIKit

// MARK: - UIWindow-based Alert Presenter

private class AlertWindow: UIWindow {
    override init(windowScene: UIWindowScene) {
        super.init(windowScene: windowScene)
        self.windowLevel = UIWindow.Level.alert + 1
        self.backgroundColor = UIColor.clear
        self.isHidden = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private class AlertHostingController: UIHostingController<AnyView> {
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .default
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.clear
    }
}

public class WindowAlertManager: ObservableObject {
    public static let shared = WindowAlertManager()
    
    @Published public var isPresented = false
    @Published public var title: String?
    @Published public var message: String?
    @Published public var cancelText: String?
    @Published public var confirmText: String = LocalizedChatString("Confirm")
    @Published public var onConfirm: (() -> Void)?
    @Published public var onCancel: (() -> Void)?
    @Published public var onDismiss: (() -> Void)?
    
    private var alertWindow: AlertWindow?
    private var hostingController: AlertHostingController?
    
    private init() {}
    
    public func showAlert(
        title: String? = nil,
        message: String? = nil,
        cancelText: String? = nil,
        confirmText: String = LocalizedChatString("Confirm"),
        onConfirm: @escaping () -> Void = {},
        onCancel: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        print("WindowAlertManager: showAlert called with message: \(message ?? "nil")")
        DispatchQueue.main.async {
            self.title = title
            self.message = message
            self.cancelText = cancelText
            self.confirmText = confirmText
            self.onConfirm = onConfirm
            self.onCancel = onCancel
            self.onDismiss = onDismiss
            self.isPresented = true
            
            self.presentAlert()
            print("WindowAlertManager: Alert presented")
        }
    }
    
    public func dismiss() {
        DispatchQueue.main.async {
            self.isPresented = false
            self.onDismiss?()
            self.dismissAlert()
            self.clearCallbacks()
        }
    }
    
    private func presentAlert() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            print("WindowAlertManager: No window scene found")
            return
        }
        
        if shouldUseUIAlertController() {
            presentUIAlertController()
            return
        }
        
        let themeState = DefaultTheme
        
        alertWindow = AlertWindow(windowScene: windowScene)
        let alertView = AnyView(WindowAlertView().environmentObject(themeState))
        hostingController = AlertHostingController(rootView: alertView)
        
        alertWindow?.rootViewController = hostingController
        alertWindow?.isHidden = false
        alertWindow?.makeKeyAndVisible()
    }
    
    private func shouldUseUIAlertController() -> Bool {
        return cancelText == nil
    }
    
    private func presentUIAlertController() {
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = windowScene.windows.first?.rootViewController else {
                print("WindowAlertManager: No root view controller found")
                return
            }
            
            let alert = UIAlertController(
                title: self.title,
                message: self.message,
                preferredStyle: .alert
            )
            
            if let cancelText = self.cancelText {
                alert.addAction(UIAlertAction(title: cancelText, style: .cancel) { _ in
                    self.onCancel?()
                    self.dismiss()
                })
            }
            
            alert.addAction(UIAlertAction(title: self.confirmText, style: .default) { _ in
                self.onConfirm?()
                self.dismiss()
            })
            
            rootViewController.present(alert, animated: true)
        }
    }
    
    private func dismissAlert() {
        alertWindow?.isHidden = true
        alertWindow = nil
        hostingController = nil
    }
    
    private func clearCallbacks() {
        self.onConfirm = nil
        self.onCancel = nil
        self.onDismiss = nil
    }
}

public struct WindowAlertView: View {
    @ObservedObject private var alertManager = WindowAlertManager.shared
    
    public init() {}
    
    public var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .compatibleIgnoreSafeArea()
                .onTapGesture {
                    alertManager.dismiss()
                }
            
            AlertDialog(
                isVisible: true,
                title: alertManager.title,
                message: alertManager.message,
                cancelText: alertManager.cancelText,
                confirmText: alertManager.confirmText,
                onDismiss: {
                    alertManager.dismiss()
                },
                onCancel: {
                    alertManager.onCancel?()
                    alertManager.dismiss()
                },
                onConfirm: {
                    alertManager.onConfirm?()
                    alertManager.dismiss()
                }
            )
        }
    }
}

public struct AlertDialog: View {
    @EnvironmentObject var themeState: ThemeState
    @State private var messageHeight: CGFloat = 0
    let isVisible: Bool
    let title: String?
    let message: String?
    let confirmText: String
    let onDismiss: (() -> Void)?
    let onConfirm: () -> Void
    let cancelText: String?
    let onCancel: (() -> Void)?

    public init(
        isVisible: Bool,
        title: String? = nil,
        message: String? = nil,
        cancelText: String? = nil,
        confirmText: String = LocalizedChatString("IKnew"),
        onDismiss: (() -> Void)? = nil,
        onCancel: (() -> Void)? = nil,
        onConfirm: @escaping () -> Void = {}
    ) {
        self.isVisible = isVisible
        self.title = title
        self.message = message
        self.confirmText = confirmText
        self.onDismiss = onDismiss
        self.onConfirm = onConfirm
        self.cancelText = cancelText
        self.onCancel = onCancel
    }

    private func calculateMessageHeight() -> CGFloat {
        guard let message = message, !message.isEmpty else { return 0 }
        let textWidth = CGFloat(327 - 48)
        let font = UIFont.systemFont(ofSize: 14)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 6
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle
        ]
        let textHeight = (message as NSString).boundingRect(
            with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        ).height
        let topPadding: CGFloat = title == nil ? 32 : 12
        let bottomPadding: CGFloat = 20
        return textHeight + topPadding + bottomPadding
    }

    private var shouldUseScrollView: Bool {
        let calculatedHeight = calculateMessageHeight()
        let maxHeight: CGFloat = 330
        return calculatedHeight > maxHeight
    }

    public var body: some View {
        if isVisible {
            ZStack {
                Color.black.opacity(0.4)
                    .compatibleIgnoreSafeArea()
                    .onTapGesture { onDismiss?() }
                VStack(spacing: 0) {
                    if let title = title, !title.isEmpty {
                        Text(title)
                            .font(themeState.fonts.body4Bold)
                            .foregroundColor(themeState.colors.textColorPrimary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 32)
                            .padding(.bottom, 12)
                            .padding(.horizontal, 24)
                    }
                    if let message = message, !message.isEmpty {
                        if shouldUseScrollView {
                            ScrollView(.vertical, showsIndicators: true) {
                                Text(message)
                                    .font(themeState.fonts.caption1Regular)
                                    .foregroundColor(themeState.colors.textColorSecondary)
                                    .lineSpacing(6)
                                    .multilineTextAlignment(.leading)
                                    .padding(.horizontal, 24)
                                    .padding(.top, title == nil ? 32 : 12)
                                    .padding(.bottom, 20)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(height: 330)
                        } else {
                            Text(message)
                                .font(themeState.fonts.caption1Regular)
                                .foregroundColor(themeState.colors.textColorSecondary)
                                .lineSpacing(6)
                                .multilineTextAlignment(.leading)
                                .padding(.horizontal, 24)
                                .padding(.top, title == nil ? 32 : 12)
                                .padding(.bottom, 20)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    Spacer().frame(height: 20)
                    Divider().background(themeState.colors.strokeColorModule)
                    if let cancelText = cancelText, let onCancel = onCancel {
                        HStack(spacing: 0) {
                            Button(action: {
                                onDismiss?()
                                onCancel()
                            }) {
                                Text(cancelText)
                                    .font(themeState.fonts.caption1Medium)
                                    .foregroundColor(themeState.colors.textColorPrimary)
                                    .frame(maxWidth: .infinity, maxHeight: 56)
                            }
                            Divider().frame(width: 1).background(themeState.colors.strokeColorModule)
                            Button(action: {
                                onDismiss?()
                                onConfirm()
                            }) {
                                Text(confirmText)
                                    .font(themeState.fonts.caption1Medium)
                                    .foregroundColor(themeState.colors.textColorLink)
                                    .frame(maxWidth: .infinity, maxHeight: 56)
                            }
                        }
                        .frame(height: 56)
                    } else {
                        Button(action: {
                            onDismiss?()
                            onConfirm()
                        }) {
                            Text(confirmText)
                                .font(themeState.fonts.caption1Medium)
                                .foregroundColor(themeState.colors.textColorLink)
                                .frame(maxWidth: .infinity, maxHeight: 56)
                        }
                        .frame(height: 56)
                    }
                }
                .frame(minWidth: 327, maxWidth: 327, minHeight: 134)
                .background(themeState.colors.bgColorDialog)
                .cornerRadius(20)
                .shadow(radius: 8)
            }
        }
    }
}

// MARK: - View Extension for easier usage

public extension View {
    func alertDialog(
        isPresented: Binding<Bool>,
        title: String? = nil,
        message: String? = nil,
        confirmText: String = LocalizedChatString("IKnew"),
        onConfirm: @escaping () -> Void = {}
    ) -> some View {
        ZStack {
            self
            AlertDialog(
                isVisible: isPresented.wrappedValue,
                title: title,
                message: message,
                cancelText: nil,
                confirmText: confirmText,
                onDismiss: {
                    isPresented.wrappedValue = false
                },
                onCancel: nil,
                onConfirm: {
                    onConfirm()
                    isPresented.wrappedValue = false
                }
            )
        }
    }

    func alertDialog(
        isPresented: Binding<Bool>,
        title: String? = nil,
        message: String? = nil,
        cancelText: String? = nil,
        confirmText: String = LocalizedChatString("IKnew"),
        onDismiss: (() -> Void)? = nil,
        onCancel: (() -> Void)? = nil,
        onConfirm: @escaping () -> Void = {}
    ) -> some View {
        ZStack {
            self
            AlertDialog(
                isVisible: isPresented.wrappedValue,
                title: title,
                message: message,
                cancelText: cancelText,
                confirmText: confirmText,
                onDismiss: {
                    isPresented.wrappedValue = false
                },
                onCancel: {
                    onCancel?()
                    isPresented.wrappedValue = false
                },
                onConfirm: {
                    onConfirm()
                    isPresented.wrappedValue = false
                }
            )
        }
    }
}

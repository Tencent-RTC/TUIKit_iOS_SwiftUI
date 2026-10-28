import SwiftUI
import UIKit

final class WindowOverlayPresenter {
    static let shared = WindowOverlayPresenter()

    private var window: UIWindow?

    var overlayRootViewController: UIViewController? { window?.rootViewController }

    private init() {}

    func show<V: View>(_ view: V, themeState: ThemeState, interactive: Bool) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        dismiss()
        let hosting = UIHostingController(rootView: view.environmentObject(themeState))
        hosting.view.backgroundColor = .clear
        let overlayWindow = UIWindow(windowScene: windowScene)
        overlayWindow.windowLevel = .alert + 1
        overlayWindow.rootViewController = hosting
        overlayWindow.isUserInteractionEnabled = interactive
        overlayWindow.isHidden = false
        window = overlayWindow
    }

    func dismiss() {
        window?.isHidden = true
        window?.rootViewController = nil
        window = nil
    }
}

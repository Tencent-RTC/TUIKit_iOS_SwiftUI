import SwiftUI
import UIKit

struct NavigationBarConfigurator: UIViewControllerRepresentable {
    typealias UIViewControllerType = UIViewController
    let configure: (UINavigationController) -> Void

    init(configure: @escaping (UINavigationController) -> Void) {
        self.configure = configure
    }

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if let nav = uiViewController.navigationController {
            configure(nav)
        }
    }
}

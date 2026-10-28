import SwiftUI
import UIKit

struct HostViewControllerBeacon: UIViewRepresentable {
    let onFound: (UIViewController) -> Void

    func makeUIView(context: Context) -> BeaconView {
        BeaconView(onFound: onFound)
    }

    func updateUIView(_ uiView: BeaconView, context: Context) {}

    final class BeaconView: UIView {
        let onFound: (UIViewController) -> Void

        init(onFound: @escaping (UIViewController) -> Void) {
            self.onFound = onFound
            super.init(frame: .zero)
            isHidden = true
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError() }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil else { return }
            var responder = next
            while let r = responder {
                if let vc = r as? UIViewController {
                    onFound(vc)
                    return
                }
                responder = r.next
            }
        }
    }
}

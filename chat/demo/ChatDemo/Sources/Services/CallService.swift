import RTCRoomEngine
import TUICallKit_Swift
import SwiftUI

enum CallService {
    static func initEngine(sdkAppID: Int32, userID: String, userSig: String) {
        TUICallEngine.createInstance().`init`(sdkAppID, userId: userID, userSig: userSig) {
            TUICallEngine.createInstance().enableMultiDeviceAbility(enable: true) {
            } fail: { code, message in
                print("[Login] enableMultiDeviceAbility failed: \(code), \(message ?? "")")
            }
            TUICallKit.createInstance().enableIncomingBanner(enable: true)
        } fail: { code, message in
            print("[Login] initCallEngine failed: \(code), \(message ?? "")")
        }
    }
}

struct RecentCallsPage: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> RecentCallsViewController {
        RecentCallsViewController(recordCallsUIStyle: .minimalist)
    }

    func updateUIViewController(_ uiViewController: RecentCallsViewController, context: Context) {}
}

import RTCRoomEngine
import SwiftUI
import TUICallKit_Swift

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

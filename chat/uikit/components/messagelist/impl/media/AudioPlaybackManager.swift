import AtomicXCore
import SwiftUI

class AudioPlaybackManager: ObservableObject {
    @Published var currentPlayingMsgID: String? = nil

    init() {}

    func setCurrentPlayingMsgID(_ msgID: String?) {
        currentPlayingMsgID = msgID
    }

    func clearCurrentPlayingMsgID() {
        currentPlayingMsgID = nil
    }

    func isPlaying(msgID: String?) -> Bool {
        guard let msgID = msgID, let currentMsgID = currentPlayingMsgID else {
            return false
        }
        return msgID == currentMsgID
    }
}

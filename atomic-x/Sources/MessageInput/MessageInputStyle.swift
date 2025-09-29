import SwiftUI

public protocol MessageInputConfigProtocol {
    var isShowAudioRecorder: Bool { get }
    var isShowPhotoTaker: Bool { get }
    var isShowMore: Bool { get }
    var isShowSendButton: Bool { get }
}

public struct ChatMessageInputStyle: MessageInputConfigProtocol {
    private let userIsShowAudioRecorder: Bool?
    private let userIsShowPhotoTaker: Bool?
    private let userIsShowMore: Bool?
    private let userIsShowSendButton: Bool?
    public var isShowAudioRecorder: Bool {
        return userIsShowAudioRecorder ?? true
    }

    public var isShowPhotoTaker: Bool {
        return userIsShowPhotoTaker ?? true
    }

    public var isShowMore: Bool {
        return userIsShowMore ?? true
    }

    public var isShowSendButton: Bool {
        if let userIsShowSendButton = userIsShowSendButton {
            return userIsShowSendButton
        } else {
            return !AppBuilderConfig.shared.hideSendButton
        }
    }

    public init() {
        self.userIsShowAudioRecorder = nil
        self.userIsShowPhotoTaker = nil
        self.userIsShowMore = nil
        self.userIsShowSendButton = nil
    }

    public init(
        isShowAudioRecorder: Bool? = nil,
        isShowPhotoTaker: Bool? = nil,
        isShowMore: Bool? = nil,
        isShowSendButton: Bool? = nil
    ) {
        self.userIsShowAudioRecorder = isShowAudioRecorder
        self.userIsShowPhotoTaker = isShowPhotoTaker
        self.userIsShowMore = isShowMore
        self.userIsShowSendButton = isShowSendButton
    }
}

public struct RoomMessageInputStyle: MessageInputConfigProtocol {
    private let userIsShowAudioRecorder: Bool?
    private let userIsShowPhotoTaker: Bool?
    private let userIsShowMore: Bool?
    private let userIsShowSendButton: Bool?
    public var isShowAudioRecorder: Bool {
        return userIsShowAudioRecorder ?? false
    }

    public var isShowPhotoTaker: Bool {
        return userIsShowPhotoTaker ?? false
    }

    public var isShowMore: Bool {
        return userIsShowMore ?? false
    }

    public var isShowSendButton: Bool {
        return userIsShowSendButton ?? true
    }

    public init() {
        self.userIsShowAudioRecorder = nil
        self.userIsShowPhotoTaker = nil
        self.userIsShowMore = nil
        self.userIsShowSendButton = nil
    }

    public init(
        isShowAudioRecorder: Bool? = nil,
        isShowPhotoTaker: Bool? = nil,
        isShowMore: Bool? = nil,
        isShowSendButton: Bool? = nil
    ) {
        self.userIsShowAudioRecorder = isShowAudioRecorder
        self.userIsShowPhotoTaker = isShowPhotoTaker
        self.userIsShowMore = isShowMore
        self.userIsShowSendButton = isShowSendButton
    }
}

import SwiftUI

public protocol MessageInputConfigProtocol {
    var isShowAudioRecorder: Bool { get }
    var isShowPhotoTaker: Bool { get }
    var isShowMore: Bool { get }
    var isShowSendButton: Bool { get }
    var enableReadReceipt: Bool { get }
    var enableMention: Bool { get }
}

public struct ChatMessageInputConfig: MessageInputConfigProtocol {
    private let userIsShowAudioRecorder: Bool?
    private let userIsShowPhotoTaker: Bool?
    private let userIsShowMore: Bool?
    private let userIsShowSendButton: Bool?
    private let userEnableReadReceipt: Bool?
    private let userEnableMention: Bool?

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

    public var enableReadReceipt: Bool {
        if let userEnableReadReceipt = userEnableReadReceipt {
            return userEnableReadReceipt
        } else {
            return AppBuilderConfig.shared.enableReadReceipt
        }
    }

    public var enableMention: Bool {
        return userEnableMention ?? true
    }

    public init() {
        self.userIsShowAudioRecorder = nil
        self.userIsShowPhotoTaker = nil
        self.userIsShowMore = nil
        self.userIsShowSendButton = nil
        self.userEnableReadReceipt = nil
        self.userEnableMention = nil
    }

    public init(
        isShowAudioRecorder: Bool? = nil,
        isShowPhotoTaker: Bool? = nil,
        isShowMore: Bool? = nil,
        isShowSendButton: Bool? = nil,
        enableReadReceipt: Bool? = nil,
        enableMention: Bool? = nil
    ) {
        self.userIsShowAudioRecorder = isShowAudioRecorder
        self.userIsShowPhotoTaker = isShowPhotoTaker
        self.userIsShowMore = isShowMore
        self.userIsShowSendButton = isShowSendButton
        self.userEnableReadReceipt = enableReadReceipt
        self.userEnableMention = enableMention
    }
}

public struct RoomMessageInputConfig: MessageInputConfigProtocol {
    private let userIsShowAudioRecorder: Bool?
    private let userIsShowPhotoTaker: Bool?
    private let userIsShowMore: Bool?
    private let userIsShowSendButton: Bool?
    private let userEnableReadReceipt: Bool?
    private let userEnableMention: Bool?

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

    public var enableReadReceipt: Bool {
        return userEnableReadReceipt ?? false
    }

    public var enableMention: Bool {
        return userEnableMention ?? false
    }

    public init() {
        self.userIsShowAudioRecorder = nil
        self.userIsShowPhotoTaker = nil
        self.userIsShowMore = nil
        self.userIsShowSendButton = nil
        self.userEnableReadReceipt = nil
        self.userEnableMention = nil
    }

    public init(
        isShowAudioRecorder: Bool? = nil,
        isShowPhotoTaker: Bool? = nil,
        isShowMore: Bool? = nil,
        isShowSendButton: Bool? = nil,
        enableReadReceipt: Bool? = nil,
        enableMention: Bool? = nil
    ) {
        self.userIsShowAudioRecorder = isShowAudioRecorder
        self.userIsShowPhotoTaker = isShowPhotoTaker
        self.userIsShowMore = isShowMore
        self.userIsShowSendButton = isShowSendButton
        self.userEnableReadReceipt = enableReadReceipt
        self.userEnableMention = enableMention
    }
}

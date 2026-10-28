import AtomicXCore
import SwiftUI

extension ChatMessageInputConfig {
    internal static let defaultAudioMaxRecordDurationMs = 60_000

    public var keepSendButtonVisible: Bool {
        get { userKeepSendButtonVisible ?? false }
        set { userKeepSendButtonVisible = newValue }
    }

    public var appearance: MessageInputAppearance? {
        get { userAppearance }
        set { userAppearance = newValue }
    }

    public var isShowAudioRecorder: Bool {
        get { userIsShowAudioRecorder ?? true }
        set { userIsShowAudioRecorder = newValue }
    }

    public var isShowPhotoTaker: Bool {
        get { userIsShowPhotoTaker ?? true }
        set { userIsShowPhotoTaker = newValue }
    }

    public var isShowMore: Bool {
        get { userIsShowMore ?? true }
        set { userIsShowMore = newValue }
    }

    public var isShowSendButton: Bool {
        get { userIsShowSendButton ?? !AppBuilderConfig.shared.hideSendButton }
        set { userIsShowSendButton = newValue }
    }

    public var isShowEmoji: Bool {
        get { userIsShowEmoji ?? true }
        set { userIsShowEmoji = newValue }
    }

    public var enableReadReceipt: Bool {
        get { userEnableReadReceipt ?? AppBuilderConfig.shared.enableReadReceipt }
        set { userEnableReadReceipt = newValue }
    }

    public var enableMention: Bool {
        get { userEnableMention ?? true }
        set { userEnableMention = newValue }
    }

    public var enableLongPressToTalk: Bool {
        get { userEnableLongPressToTalk ?? true }
        set { userEnableLongPressToTalk = newValue }
    }

    public var isShowVideoCall: Bool {
        get { userIsShowVideoCall ?? true }
        set { userIsShowVideoCall = newValue }
    }

    public var isShowAudioCall: Bool {
        get { userIsShowAudioCall ?? true }
        set { userIsShowAudioCall = newValue }
    }

    public var enableTyping: Bool {
        get { userEnableTyping ?? true }
        set { userEnableTyping = newValue }
    }

    public var audioMaxRecordDurationMs: Int {
        get { userAudioMaxRecordDurationMs ?? Self.defaultAudioMaxRecordDurationMs }
        set { userAudioMaxRecordDurationMs = newValue }
    }

    public var actionCustomizer: MessageInputActionCustomizer? {
        get { userActionCustomizer }
        set { userActionCustomizer = newValue }
    }

    public init(
        isShowAudioRecorder: Bool? = nil,
        isShowPhotoTaker: Bool? = nil,
        isShowMore: Bool? = nil,
        isShowSendButton: Bool? = nil,
        isShowEmoji: Bool? = nil,
        enableReadReceipt: Bool? = nil,
        enableMention: Bool? = nil,
        enableLongPressToTalk: Bool? = nil,
        isShowVideoCall: Bool? = nil,
        isShowAudioCall: Bool? = nil,
        enableTyping: Bool? = nil,
        audioMaxRecordDurationMs: Int? = nil,
        actionCustomizer: MessageInputActionCustomizer? = nil,
        keepSendButtonVisible: Bool? = nil,
        appearance: MessageInputAppearance? = nil
    ) {
        self.userIsShowAudioRecorder = isShowAudioRecorder
        self.userIsShowPhotoTaker = isShowPhotoTaker
        self.userIsShowMore = isShowMore
        self.userIsShowSendButton = isShowSendButton
        self.userIsShowEmoji = isShowEmoji
        self.userEnableReadReceipt = enableReadReceipt
        self.userEnableMention = enableMention
        self.userEnableLongPressToTalk = enableLongPressToTalk
        self.userIsShowVideoCall = isShowVideoCall
        self.userIsShowAudioCall = isShowAudioCall
        self.userEnableTyping = enableTyping
        self.userAudioMaxRecordDurationMs = audioMaxRecordDurationMs
        self.userActionCustomizer = actionCustomizer
        self.userKeepSendButtonVisible = keepSendButtonVisible
        self.userAppearance = appearance
    }
}

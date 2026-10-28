extension VideoRecorderConfig {
    static let defaultMinDurationMs = 2000
    static let defaultMaxDurationMs = 15000

    public convenience init(
        recordMode: RecordMode? = nil,
        videoQuality: VideoQuality? = nil,
        minDurationMs: Int? = nil,
        maxDurationMs: Int? = nil,
        isDefaultFrontCamera: Bool? = nil,
        isSupportEdit: Bool? = nil,
        isSupportTorch: Bool? = nil,
        isSupportAspect: Bool? = nil
    ) {
        self.init()
        self.userRecordMode = recordMode
        self.userVideoQuality = videoQuality
        self.userMinDurationMs = minDurationMs
        self.userMaxDurationMs = maxDurationMs
        self.userIsDefaultFrontCamera = isDefaultFrontCamera
        self.userIsSupportEdit = isSupportEdit
        self.userIsSupportTorch = isSupportTorch
        self.userIsSupportAspect = isSupportAspect
    }

    public var recordMode: RecordMode {
        get { userRecordMode ?? .videoPhotoMix }
        set { userRecordMode = newValue }
    }

    public var videoQuality: VideoQuality {
        get { userVideoQuality ?? .medium }
        set { userVideoQuality = newValue }
    }

    public var minDurationMs: Int {
        get { userMinDurationMs ?? Self.defaultMinDurationMs }
        set { userMinDurationMs = newValue }
    }

    public var maxDurationMs: Int {
        get { userMaxDurationMs ?? Self.defaultMaxDurationMs }
        set { userMaxDurationMs = newValue }
    }

    public var isDefaultFrontCamera: Bool {
        get { userIsDefaultFrontCamera ?? false }
        set { userIsDefaultFrontCamera = newValue }
    }

    public var isSupportEdit: Bool? {
        get { userIsSupportEdit }
        set { userIsSupportEdit = newValue }
    }

    public var isSupportTorch: Bool {
        get { userIsSupportTorch ?? true }
        set { userIsSupportTorch = newValue }
    }

    public var isSupportAspect: Bool {
        get { userIsSupportAspect ?? true }
        set { userIsSupportAspect = newValue }
    }
}

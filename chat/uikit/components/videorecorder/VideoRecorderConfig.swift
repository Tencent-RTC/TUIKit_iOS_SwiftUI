public class VideoRecorderConfig {
    public var userRecordMode: RecordMode? = nil
    public var userVideoQuality: VideoQuality? = nil
    public var userMinDurationMs: Int? = nil
    public var userMaxDurationMs: Int? = nil
    public var userIsDefaultFrontCamera: Bool? = nil
    public var userIsSupportEdit: Bool? = nil
    public var userIsSupportTorch: Bool? = nil
    public var userIsSupportAspect: Bool? = nil
}

public enum RecordMode: Int {
    case videoPhotoMix = 0
    case photoOnly = 1
    case videoOnly = 2
}

public enum VideoQuality: Int {
    case low = 1
    case medium = 2
    case high = 3
}

public enum MediaType {
    case photo
    case video
}

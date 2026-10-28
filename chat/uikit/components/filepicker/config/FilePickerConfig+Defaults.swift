extension FilePickerConfig {
    public init(maxCount: Int? = nil) { userMaxCount = maxCount }

    public var maxCount: Int {
        get { userMaxCount ?? 1 }
        set { userMaxCount = newValue }
    }
}

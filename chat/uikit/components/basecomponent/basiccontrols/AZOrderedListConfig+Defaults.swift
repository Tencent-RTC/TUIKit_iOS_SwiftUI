extension AZOrderedListConfig {
    public init(showIndexBar: Bool? = nil) { userShowIndexBar = showIndexBar }

    public var showIndexBar: Bool {
        get { userShowIndexBar ?? true }
        set { userShowIndexBar = newValue }
    }
}

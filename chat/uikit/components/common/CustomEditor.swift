import Foundation

public protocol CustomItem {
    var ID: String { get }
}

public final class CustomEditor<Item: CustomItem> {
    private let implementation: CustomEditorImpl<Item>

    public private(set) var items: [Item] {
        get { implementation.items }
        set { implementation.items = newValue }
    }

    public init(items: [Item]) { implementation = CustomEditorImpl(items: items) }

    public func add(_ item: Item) { implementation.add(item) }

    @discardableResult
    public func remove(_ ID: String) -> Bool { implementation.remove(ID) }

    public func replace(_ ID: String, _ transform: (Item) -> Item) { implementation.replace(ID, transform) }

    public func insertBefore(_ anchorID: String, _ item: Item) { implementation.insertBefore(anchorID, item) }

    public func insertAfter(_ anchorID: String, _ item: Item) { implementation.insertAfter(anchorID, item) }

    public func moveBefore(_ ID: String, _ anchorID: String) { implementation.moveBefore(ID, anchorID) }

    public func moveAfter(_ ID: String, _ anchorID: String) { implementation.moveAfter(ID, anchorID) }

    public func clear() { implementation.clear() }

    public func build() -> [Item] { implementation.build() }
}

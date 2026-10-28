import Foundation

final class CustomEditorImpl<Item: CustomItem> {
    var items: [Item]

    private var didBuild = false

    init(items: [Item]) {
        self.items = items
    }

    func add(_ item: Item) {
        prepareMutation()
        precondition(!item.ID.isEmpty, "CustomEditor: item ID must not be empty")
        precondition(!items.contains { $0.ID == item.ID }, "CustomEditor: duplicated item ID \(item.ID)")
        items.append(item)
    }

    @discardableResult
    func remove(_ ID: String) -> Bool {
        prepareMutation()
        let count = items.count
        items.removeAll { $0.ID == ID }
        return items.count != count
    }

    func replace(_ ID: String, _ transform: (Item) -> Item) {
        prepareMutation()
        guard let index = items.firstIndex(where: { $0.ID == ID }) else { return }
        let replacement = transform(items[index])
        precondition(replacement.ID == ID, "CustomEditor: replacement must keep the same ID")
        items[index] = replacement
    }

    func insertBefore(_ anchorID: String, _ item: Item) {
        prepareMutation()
        precondition(!item.ID.isEmpty, "CustomEditor: item ID must not be empty")
        precondition(!items.contains { $0.ID == item.ID }, "CustomEditor: duplicated item ID \(item.ID)")
        guard let index = items.firstIndex(where: { $0.ID == anchorID }) else { return }
        items.insert(item, at: index)
    }

    func insertAfter(_ anchorID: String, _ item: Item) {
        prepareMutation()
        precondition(!item.ID.isEmpty, "CustomEditor: item ID must not be empty")
        precondition(!items.contains { $0.ID == item.ID }, "CustomEditor: duplicated item ID \(item.ID)")
        guard let index = items.firstIndex(where: { $0.ID == anchorID }) else { return }
        items.insert(item, at: index + 1)
    }

    func moveBefore(_ ID: String, _ anchorID: String) {
        prepareMutation()
        guard ID != anchorID,
              let from = items.firstIndex(where: { $0.ID == ID }),
              let to = items.firstIndex(where: { $0.ID == anchorID }) else { return }
        let item = items.remove(at: from)
        let target = items.firstIndex(where: { $0.ID == anchorID }) ?? to
        items.insert(item, at: target)
    }

    func moveAfter(_ ID: String, _ anchorID: String) {
        prepareMutation()
        guard ID != anchorID,
              let from = items.firstIndex(where: { $0.ID == ID }),
              let to = items.firstIndex(where: { $0.ID == anchorID }) else { return }
        let item = items.remove(at: from)
        let target = items.firstIndex(where: { $0.ID == anchorID }) ?? (to - 1)
        items.insert(item, at: target + 1)
    }

    func clear() {
        prepareMutation()
        items.removeAll()
    }

    func build() -> [Item] {
        didBuild = true
        return items
    }

    private func prepareMutation() {
        precondition(!didBuild, "CustomEditor: cannot mutate after build()")
    }
}

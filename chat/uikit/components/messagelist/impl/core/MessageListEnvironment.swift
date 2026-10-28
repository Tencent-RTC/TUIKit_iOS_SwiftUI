import AtomicXCore
import AVFoundation
import Combine
import Foundation
import Kingfisher
import SwiftUI

extension View {
    func onValueChange<Value: Equatable>(of value: Value, perform action: @escaping (Value) -> Void) -> some View {
        return onChange(of: value, perform: action)
    }

    private func createValuePublisher<Value>(_ value: Value) -> AnyPublisher<Value, Never> {
        return Future<Value, Never> { promise in
            promise(.success(value))
        }
        .eraseToAnyPublisher()
    }
}

extension View {
    @ViewBuilder
    func listRowSeparatorHidden() -> some View {
        listRowSeparator(.hidden)
    }

    @ViewBuilder
    func listRowInsetsZero() -> some View {
        listRowInsets(EdgeInsets())
    }
}

private struct MessageListConfigProtocolKey: EnvironmentKey {
    static let defaultValue: MessageListConfigProtocol = ChatMessageListConfig(alignment: nil)
}

private struct MessageCustomActionsKey: EnvironmentKey {
    static let defaultValue: [MessageCustomAction] = []
}

private struct MultiSelectModeKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

private struct SelectedMessageIDsKey: EnvironmentKey {
    static let defaultValue: Set<String> = []
}

private struct ToggleMessageSelectionKey: EnvironmentKey {
    static let defaultValue: ((MessageInfo) -> Void)? = nil
}

extension EnvironmentValues {
    var messageListConfigProtocol: MessageListConfigProtocol {
        get { self[MessageListConfigProtocolKey.self] }
        set { self[MessageListConfigProtocolKey.self] = newValue }
    }

    var messageCustomActions: [MessageCustomAction] {
        get { self[MessageCustomActionsKey.self] }
        set { self[MessageCustomActionsKey.self] = newValue }
    }

    var isMultiSelectMode: Bool {
        get { self[MultiSelectModeKey.self] }
        set { self[MultiSelectModeKey.self] = newValue }
    }

    var selectedMessageIDs: Set<String> {
        get { self[SelectedMessageIDsKey.self] }
        set { self[SelectedMessageIDsKey.self] = newValue }
    }

    var toggleMessageSelection: ((MessageInfo) -> Void)? {
        get { self[ToggleMessageSelectionKey.self] }
        set { self[ToggleMessageSelectionKey.self] = newValue }
    }
}

class MultiSelectManager: ObservableObject {
    @Published var isMultiSelectMode: Bool = false
    @Published var selectedMessageIDs: Set<String> = []

    func enterMultiSelectMode(initialMessageID: String?) {
        if let msgID = initialMessageID {
            selectedMessageIDs.insert(msgID)
        }
        isMultiSelectMode = true
    }

    func exitMultiSelectMode() {
        isMultiSelectMode = false
        selectedMessageIDs.removeAll()
    }

    func toggleSelection(messageID: String) {
        if selectedMessageIDs.contains(messageID) {
            selectedMessageIDs.remove(messageID)
        } else {
            selectedMessageIDs.insert(messageID)
        }
    }

    func isSelected(messageID: String) -> Bool {
        return selectedMessageIDs.contains(messageID)
    }
}

private struct MultiSelectManagerKey: EnvironmentKey {
    static let defaultValue: MultiSelectManager = .init()
}

extension EnvironmentValues {
    var multiSelectManager: MultiSelectManager {
        get { self[MultiSelectManagerKey.self] }
        set { self[MultiSelectManagerKey.self] = newValue }
    }
}

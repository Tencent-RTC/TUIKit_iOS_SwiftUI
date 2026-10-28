import AtomicXCore
import SwiftUI

final class MessageCellRegistry {
    static let shared = MessageCellRegistry()

    private let lock = NSLock()
    private var contentViewBuilders: [String: (CustomMessagePayload) -> AnyView] = [:]

    private init() {}

    func register(businessID: String,
                         summaryProvider: @escaping (CustomMessagePayload) -> String?,
                         contentViewBuilder: @escaping (CustomMessagePayload) -> AnyView) {
        CustomMessageSummaryRegistry.shared.register(businessID: businessID, summaryProvider: summaryProvider)
        lock.lock()
        contentViewBuilders[businessID] = contentViewBuilder
        lock.unlock()
    }

    func customContentView(for payload: CustomMessagePayload) -> AnyView? {
        guard let businessID = Self.businessID(from: payload) else { return nil }
        lock.lock()
        let builder = contentViewBuilders[businessID]
        lock.unlock()
        return builder?(payload)
    }

    func hasCustomCell(for payload: CustomMessagePayload) -> Bool {
        guard let businessID = Self.businessID(from: payload) else { return false }
        lock.lock()
        let exists = contentViewBuilders[businessID] != nil
        lock.unlock()
        return exists
    }

    private static func businessID(from payload: CustomMessagePayload) -> String? {
        guard let data = payload.customData.data(using: .utf8),
              let customInfo = ChatUtil.jsonData2Dictionary(jsonData: data),
              let businessID = customInfo["businessID"] as? String
        else {
            return nil
        }
        return businessID
    }
}

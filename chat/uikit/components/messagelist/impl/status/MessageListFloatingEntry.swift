import AtomicXCore
import Combine
import Foundation
import SwiftUI

final class MessageMentionReadState: ObservableObject {
    static let shared = MessageMentionReadState()
    @Published private(set) var revision = 0

    private let defaults: UserDefaults
    private var consumedByScope: [String: Set<Int64>] = [:]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    static func scopeKey(conversationID: String) -> String? {
        let login = LoginStore.shared
        guard login.sdkAppID > 0, let userID = login.state.value.loginUserInfo?.userID,
              !userID.isEmpty, !conversationID.isEmpty else { return nil }
        return "chat_consumed_mentions_\(login.sdkAppID)_\(userID.utf8.count):\(userID)_\(conversationID)"
    }

    func unconsumed(_ infoList: [GroupAtInfo], scopeKey: String?) -> [GroupAtInfo] {
        guard let scopeKey = scopeKey else { return infoList }
        let consumed = consumedSequences(scopeKey: scopeKey)
        return infoList.filter { !consumed.contains($0.msgSeq) }
    }

    func markConsumed(_ sequences: Set<Int64>, scopeKey: String?) {
        guard let scopeKey = scopeKey else { return }
        let old = consumedSequences(scopeKey: scopeKey)
        let updated = old.union(sequences.filter { $0 > 0 })
        guard updated != old else { return }
        consumedByScope[scopeKey] = updated
        defaults.set(updated.sorted().map { String($0) }, forKey: scopeKey)
        revision += 1
    }

    private func consumedSequences(scopeKey: String) -> Set<Int64> {
        if let cached = consumedByScope[scopeKey] { return cached }
        let saved = Set((defaults.stringArray(forKey: scopeKey) ?? []).compactMap { Int64($0) })
        consumedByScope[scopeKey] = saved
        return saved
    }
}

enum MessageListFloatingEntry: Equatable {
    case backToLatest
    case newMessages(count: Int, firstMessageID: String)
    case mention(sequence: Int64, isAtAll: Bool)
    case backToQuote(returnMessageID: String)
}

final class MessageListFloatingEntryController: ObservableObject {
    @Published private(set) var currentEntry: MessageListFloatingEntry? = nil

    private static let backToLatestThresholdScreenMultiplier: CGFloat = 1.5

    private var newMessageIDs: [String] = []
    private var isBeyondDisplayThreshold: Bool = false
    private var backToQuoteReturnID: String? = nil
    private var showBackToQuote: Bool = false
    private var pendingMentions: [Int64: Bool] = [:]
    private var consumedMentionSequences: Set<Int64> = []
    private let mentionReadState: MessageMentionReadState
    private let mentionScopeKey: String?

    init(conversationID: String? = nil, mentionReadState: MessageMentionReadState = .shared) {
        self.mentionReadState = mentionReadState
        self.mentionScopeKey = conversationID.flatMap { MessageMentionReadState.scopeKey(conversationID: $0) }
    }

    var currentMentionTarget: (sequence: Int64, isAtAll: Bool)? {
        guard let sequence = pendingMentions.keys.min(), let isAtAll = pendingMentions[sequence] else { return nil }
        return (sequence, isAtAll)
    }

    func reset() {
        newMessageIDs.removeAll()
        isBeyondDisplayThreshold = false
        backToQuoteReturnID = nil
        showBackToQuote = false
        consumedMentionSequences.formUnion(pendingMentions.keys)
        mentionReadState.markConsumed(Set(pendingMentions.keys), scopeKey: mentionScopeKey)
        pendingMentions.removeAll()
        recompute()
    }


    func onQuoteNavigated(returnMessageID: String) {
        guard !returnMessageID.isEmpty else { return }
        backToQuoteReturnID = returnMessageID
        showBackToQuote = true
        recompute()
    }

    var currentBackToQuoteReturnID: String? {
        return showBackToQuote ? backToQuoteReturnID : nil
    }

    func onReturnMessageVisible() {
        guard showBackToQuote else { return }
        backToQuoteReturnID = nil
        showBackToQuote = false
        recompute()
    }


    func mergeMentionTargets(_ infoList: [GroupAtInfo]) {
        for info in mentionReadState.unconsumed(infoList, scopeKey: mentionScopeKey)
            where info.msgSeq > 0 && !consumedMentionSequences.contains(info.msgSeq) {
            let isAtAll = info.atType == .atAll || info.atType == .atAllAtMe
            pendingMentions[info.msgSeq] = (pendingMentions[info.msgSeq] ?? false) || isAtAll
        }
        recompute()
    }

    func onMentionMessageFrameChanged(sequence: Int64, frame: CGRect, viewport: CGRect) {
        guard frame.width > 0, frame.height > 0, viewport.width > 0, viewport.height > 0 else { return }
        let intersection = frame.intersection(viewport)
        guard !intersection.isNull, intersection.width > 1, intersection.height > 1 else { return }
        onMentionMessageVisible(sequence: sequence)
    }

    func onMentionMessageVisible(sequence: Int64) {
        guard pendingMentions.removeValue(forKey: sequence) != nil else { return }
        consumedMentionSequences.insert(sequence)
        mentionReadState.markConsumed([sequence], scopeKey: mentionScopeKey)
        recompute()
    }


    func onNewMessage(_ message: MessageInfo, isLatestVisible: Bool) {
        guard !message.msgID.isEmpty else { return }
        if isLatestVisible {
            clearNewMessages()
            recompute()
            return
        }
        guard !newMessageIDs.contains(message.msgID) else { return }
        newMessageIDs.append(message.msgID)
        recompute()
    }

    @discardableResult
    func onMessageRecalled(msgID: String) -> Bool {
        guard !msgID.isEmpty else { return false }
        let countBeforeRemoval = newMessageIDs.count
        newMessageIDs.removeAll { $0 == msgID }
        let removed = newMessageIDs.count != countBeforeRemoval
        if removed {
            recompute()
        }
        return removed
    }

    func onScroll(distanceFromLatest: CGFloat, viewportHeight: CGFloat, isLatestVisible: Bool) {
        if isLatestVisible {
            clearNewMessages()
            isBeyondDisplayThreshold = false
        } else if viewportHeight > 0,
                  distanceFromLatest >= viewportHeight * Self.backToLatestThresholdScreenMultiplier {
            isBeyondDisplayThreshold = true
        }
        recompute()
    }


    func consume(_ entry: MessageListFloatingEntry) {
        switch entry {
        case .backToLatest:
            break
        case .newMessages:
            clearNewMessages()
        case .mention(let sequence, _):
            pendingMentions.removeValue(forKey: sequence)
            consumedMentionSequences.insert(sequence)
            mentionReadState.markConsumed([sequence], scopeKey: mentionScopeKey)
        case .backToQuote:
            backToQuoteReturnID = nil
            showBackToQuote = false
        }
        recompute()
    }


    private func recompute() {
        withAnimation(.easeInOut(duration: 0.2)) {
            if showBackToQuote, let returnID = backToQuoteReturnID {
                currentEntry = .backToQuote(returnMessageID: returnID)
                return
            }
            if let mention = currentMentionTarget {
                currentEntry = .mention(sequence: mention.sequence, isAtAll: mention.isAtAll)
                return
            }
            if isBeyondDisplayThreshold, let first = newMessageIDs.first {
                currentEntry = .newMessages(count: newMessageIDs.count, firstMessageID: first)
                return
            }
            currentEntry = isBeyondDisplayThreshold ? .backToLatest : nil
        }
    }

    private func clearNewMessages() {
        newMessageIDs.removeAll()
    }
}

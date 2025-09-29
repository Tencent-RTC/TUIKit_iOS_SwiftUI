import AtomicXCore
import AVFoundation
import Combine
import Foundation
import SwiftUI

extension View {
    func onValueChange<Value: Equatable>(of value: Value, perform action: @escaping (Value) -> Void) -> some View {
        if #available(iOS 15.0, *) {
            return self.onChange(of: value, perform: action)
        } else {
            return onReceive(createValuePublisher(value)) { newValue in
                action(newValue)
            }
        }
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
        if #available(iOS 15.0, *) {
            self.listRowSeparator(.hidden)
        } else {
            self
        }
    }

    @ViewBuilder
    func listRowInsetsZero() -> some View {
        if #available(iOS 15.0, *) {
            self.listRowInsets(EdgeInsets())
        } else {
            self
        }
    }
}

private struct RefreshableModifier: ViewModifier {
    let hasMoreData: Bool
    let isLoading: Bool
    let onRefresh: (@escaping () -> Void) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 15.0, *) {
            content
                .refreshable {
                    await withCheckedContinuation { continuation in
                        onRefresh {
                            continuation.resume()
                        }
                    }
                }
        } else {
            content
        }
    }
}

private struct MessageListConfigProtocolKey: EnvironmentKey {
    static let defaultValue: MessageListConfigProtocol = ChatMessageStyle()
}

extension EnvironmentValues {
    var MessageListConfigProtocol: MessageListConfigProtocol {
        get { self[MessageListConfigProtocolKey.self] }
        set { self[MessageListConfigProtocolKey.self] = newValue }
    }
}

public struct MessageList: View {
    @EnvironmentObject var themeState: ThemeState
    @State private var keyboardHandler = KeyboardHandler()
    @StateObject private var menuManager = MessageMenuManager.shared
    @StateObject private var sharedAudioPlayer = AudioPlayer.create()
    @State private var isLoading = false
    @State private var isPullingToRefresh = false
    @State private var refreshProgress: CGFloat = 0
    @State private var isDragging = false
    @State private var isLoadingMoreMessages = false
    @State private var isLoadingMoreNewerMessages = false
    @State private var anchorMessageId: String? = nil
    @State private var messageList: [MessageInfo] = []
    @State private var hasMoreOlderMessage: Bool = false
    @State private var hasMoreNewerMessage: Bool = false
    @State private var messageListChangeReason: MessageListChangeReason = .unknown
    @State private var messageListStore: MessageListStore? = nil
    @State private var isStoreInitialized = false
    @State private var isPageVisible = false
    let listStyle: MessageListConfigProtocol

    private let conversationID: String
    private let onUserClick: ((String) -> Void)?
    private let locateMessage: MessageInfo?
    private var conversationStore: ConversationListStore

    public init(
        conversationID: String,
        listStyle: MessageListConfigProtocol,
        locateMessage: MessageInfo? = nil,
        onUserClick: ((String) -> Void)? = nil
    ) {
        self.conversationID = conversationID
        self.listStyle = listStyle
        self.locateMessage = locateMessage
        self.onUserClick = onUserClick
        self.conversationStore = ConversationListStore.create()
    }

    private var store: MessageListStore {
        guard let store = messageListStore else {
            return MessageListStore.create(conversationID: conversationID, messageListType: .history)
        }
        return store
    }

    public var body: some View {
        if #available(iOS 15.0, *) {
            let _ = Self._printChanges()
        } else {
            // Fallback on earlier versions
        }

        ZStack(alignment: .top) {
            themeState.colors.bgColorOperate.ignoresSafeArea()
            if isLoading {
                loadingIndicatorView
            }
            scrollableMessageListView
            MessageMenuView
        }
        .padding(.bottom, 8)
        .background(themeState.colors.bgColorOperate)
        .videoPlayerSupport()
        .onAppear {
            isPageVisible = true
            initializeStoreIfNeeded()
            fetchMessages()

            if #available(iOS 15.0, *) {
            } else {
                UITableView.appearance().separatorStyle = .none
                UITableView.appearance().separatorColor = .clear
            }
        }
        .onDisappear {
            isPageVisible = false
        }
        .onReceive(store.state.subscribe(StatePublisherSelector(keyPath: \MessageListState.messageList))) { messageList in
            self.messageList = messageList
        }
        .onReceive(store.state.subscribe(StatePublisherSelector(keyPath: \MessageListState.hasMoreOlderMessage))) { hasMoreOlderMessage in
            self.hasMoreOlderMessage = hasMoreOlderMessage
        }
        .onReceive(store.state.subscribe(StatePublisherSelector(keyPath: \MessageListState.hasMoreNewerMessage))) { hasMoreNewerMessage in
            self.hasMoreNewerMessage = hasMoreNewerMessage
        }
        .onReceive(store.state.subscribe(StatePublisherSelector(keyPath: \MessageListState.messageListChangeReason))) { messageListChangeReason in
            self.messageListChangeReason = messageListChangeReason
        }
    }

    private var loadingIndicatorView: some View {
        VStack {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.5)
            Text("loading...")
                .font(.system(size: 14))
                .foregroundColor(themeState.colors.textColorSecondary)
                .padding(.top, 8)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .zIndex(2)
    }

    @ViewBuilder
    private func messageListContent(scrollProxy: ScrollViewProxy) -> some View {
        ForEach(messageList) { message in
            MessageView(
                message: message,
                messageListStore: store,
                conversationID: conversationID,
                audioPlayer: sharedAudioPlayer,
                onUserClick: onUserClick,
                parentMessageList: messageList
            )
            .environment(\.MessageListConfigProtocol, listStyle)
            .environmentObject(menuManager)
            .environment(\.locateMessageID, locateMessage?.msgID)
            .id(message.id)
            .listRowSeparatorHidden()
            .listRowInsetsZero()
            .listRowBackground(Color.clear)
        }
        if hasMoreNewerMessage {
            HStack {
                Spacer()
                if isLoadingMoreNewerMessages {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.8)
                }
                Spacer()
            }
            .frame(height: 40)
            .onAppear {
                if !isLoadingMoreNewerMessages {
                    loadMoreNewerMessages {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            scrollToBottom(proxy: scrollProxy, animated: true)
                        }
                    }
                }
            }
            .listRowSeparatorHidden()
            .listRowInsetsZero()
            .listRowBackground(Color.clear)
        }
    }

    private var scrollableMessageListView: some View {
        ScrollViewReader { scrollProxy in
            Group {
                if #available(iOS 15.0, *) {
                    List {
                        messageListContent(scrollProxy: scrollProxy)
                    }
                    .listStyle(PlainListStyle())
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            messageListContent(scrollProxy: scrollProxy)
                        }
                    }
                }
            }
            .background(themeState.colors.bgColorOperate)
            .simultaneousGesture(
                TapGesture()
                    .onEnded { _ in
                        hideKeyboard()
                        menuManager.hideMenu()
                    }
            )
            .modifier(RefreshableModifier(
                hasMoreData: hasMoreOlderMessage,
                isLoading: isLoading,
                onRefresh: { completion in
                    if let firstMessage = messageList.first {
                        anchorMessageId = firstMessage.id
                    }
                    isLoadingMoreMessages = true
                    loadMoreOlderMessages(completion: {
                        isLoadingMoreMessages = false
                        completion()
                    })
                }
            ))
            .onAppear {
                setupScrollDetection()
            }
            .onValueChange(of: messageListChangeReason) { messageListChangeReason in
                if messageListChangeReason == .fetchMessages {
                    conversationStore.clearConversationUnreadCount(conversationID, completion: nil)
                    if let targetID = locateMessage?.msgID {
                        scrollToTargetMessage(proxy: scrollProxy, targetID: targetID)
                    } else {
                        scrollToBottom(proxy: scrollProxy, animated: false)
                    }
                } else if messageListChangeReason == .fetchMoreMessages {
                    if let anchorId = anchorMessageId {
                        DispatchQueue.main.async {
                            withAnimation(.none) {
                                scrollProxy.scrollTo(anchorId, anchor: .top)
                            }
                        }
                        anchorMessageId = nil
                    }
                } else if messageListChangeReason == .sendMessage || messageListChangeReason == .recvMessage {
                    scrollToBottom(proxy: scrollProxy, animated: true)
                    if messageListChangeReason == .recvMessage {
                        conversationStore.clearConversationUnreadCount(conversationID, completion: nil)
                    }
                }
            }
            .onReceive(keyboardHandler.$keyboardHeight) { keyboardHeight in
                if keyboardHeight > 0 && isPageVisible {
                    scrollToBottom(proxy: scrollProxy, animated: true)
                }
            }
        }
    }

    private var MessageMenuView: some View {
        MessageActionView()
            .environmentObject(menuManager)
            .zIndex(1000)
            .onValueChange(of: menuManager.menuData.isShowing) { isShowing in
                if isShowing {
                    hideKeyboard()
                }
            }
    }

    private func scrollToTargetMessage(proxy: ScrollViewProxy, targetID: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("MessageListView: Executing scroll to target message")
            withAnimation(.easeOut(duration: 0.3)) {
                proxy.scrollTo(targetID, anchor: .center)
            }
        }
    }

    private func fetchMessagesWithTarget() {
        guard locateMessage?.msgID != nil else {
            fetchMessagesNormal()
            return
        }

        if let locateMessage = locateMessage {
            var option = MessageFetchOption()
            option.message = locateMessage
            option.direction = [.Older, .Newer]
            option.pageCount = 10
            store.fetchMessageList(with: option, completion: { result in
                switch result {
                case .success:
                    DispatchQueue.main.async {
                        self.isLoading = false
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        self.isLoading = false
                        print("Failed to fetch messages with target: \(error.code), \(error.message)")
                    }
                }
            })
        } else {
            fetchMessagesNormal()
        }
    }

    private func fetchMessagesNormal() {
        var option = MessageFetchOption()
        option.direction = .Older
        option.pageCount = 20
        store.fetchMessageList(with: option, completion: { result in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self.isLoading = false
                    print("Failed to fetch messages: \(error.code), \(error.message)")
                }
            }
        })
    }

    private func initializeStoreIfNeeded() {
        guard !isStoreInitialized else { return }

        messageListStore = MessageListStore.create(conversationID: conversationID, messageListType: .history)
        isStoreInitialized = true
    }

    private func fetchMessages() {
        isLoading = true
        if locateMessage?.msgID != nil {
            fetchMessagesWithTarget()
        } else {
            fetchMessagesNormal()
        }
    }

    private func loadMoreOlderMessages(completion: @escaping () -> Void) {
        store.fetchMoreMessageList(direction: .Older, completion: { result in
            switch result {
            case .success:
                completion()
            case .failure(let error):
                print("Failed to load more messages: \(error.code), \(error.message)")
                completion()
            }
        })
    }

    private func loadMoreNewerMessages(completion: @escaping () -> Void) {
        guard !isLoadingMoreNewerMessages else {
            completion()
            return
        }
        isLoadingMoreNewerMessages = true
        store.fetchMoreMessageList(direction: .Newer, completion: { result in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    self.isLoadingMoreNewerMessages = false
                    completion()
                }
            case .failure(let error):
                print("Failed to load more newer messages: \(error.code), \(error.message)")
                DispatchQueue.main.async {
                    self.isLoadingMoreNewerMessages = false
                    completion()
                }
            }
        })
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool) {
        guard let lastMessage = messageList.last else { return }
        DispatchQueue.main.async {
            if animated {
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                }
            } else {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }

    private func setupScrollDetection() {}
}

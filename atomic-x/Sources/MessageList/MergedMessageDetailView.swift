import AtomicXCore
import Combine
import SwiftUI

struct MergedMessageDetailView: View {
    @EnvironmentObject var themeState: ThemeState
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var sharedAudioPlayer = AudioPlayer.create()
    @State private var subMessages: [MessageInfo] = []
    @State private var isLoading = true
    @State private var cancellables = Set<AnyCancellable>()
    
    let mergedMessage: MessageInfo
    let depth: Int
    private let messageStore: MessageListStore
    
    init(mergedMessage: MessageInfo, depth: Int = 0) {
        self.mergedMessage = mergedMessage
        self.depth = depth
        // Create a store for merged messages
        self.messageStore = MessageListStore.create(
            conversationID: "",
            messageListType: .merged
        )
    }
    
    private var title: String {
        return mergedMessage.messageBody?.mergedMessage?.title ?? LocalizedChatString("")
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                themeState.colors.bgColorOperate
                    .ignoresSafeArea()
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                } else if subMessages.isEmpty {
                    Text("暂无消息")
                        .foregroundColor(themeState.colors.textColorSecondary)
                } else {
                    messageListView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(themeState.colors.textColorPrimary)
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(themeState.colors.textColorLink)
                    }
                }
            }
        }
        .onAppear {
            setupSubscription()
            loadSubMessages()
        }
    }
    
    private var messageListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(subMessages) { message in
                    MessageView(
                        message: message,
                        messageListStore: messageStore,
                        conversationID: "",
                        audioPlayer: sharedAudioPlayer,
                        onUserClick: nil,
                        parentMessageList: subMessages,
                        displayMode: .merged
                    )
                    .environment(\.isInMergedDetailView, true)
                    .environmentObject(themeState)
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    @ViewBuilder
    private func nestedMergedMessageOverlay(for message: MessageInfo) -> some View {
        if message.messageType == .merged && depth < 3 {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    // TODO: Navigate to nested detail view
                }
        } else {
            EmptyView()
        }
    }
    
    private func setupSubscription() {
        messageStore.state
            .subscribe(StatePublisherSelector(keyPath: \.messageList))
            .receive(on: DispatchQueue.main)
            .sink { messageList in
                self.subMessages = messageList
                self.isLoading = false
                // Fetch reactions for sub messages
                if !messageList.isEmpty {
                    fetchMessageReactions(messageList)
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadSubMessages() {
        var option = MessageFetchOption()
        option.message = mergedMessage
        option.direction = .Older
        option.pageCount = 100
        
        messageStore.fetchMessageList(with: option) { result in
            switch result {
            case .success:
                break
            case .failure(let error):
                print(">>>>> MergedMessageDetailView fetch failed: \(error.code), \(error.message)")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }
    }

    private func fetchMessageReactions(_ messages: [MessageInfo]) {
        messageStore.fetchMessageReactions(
            messages,
            maxUserCountPerReaction: 3,
            completion: { result in
                switch result {
                case .success:
                    break
                case .failure(let error):
                    print(">>>>> MergedMessageDetailView fetch reactions failed: \(error.code), \(error.message)")
                }
            }
        )
    }
}

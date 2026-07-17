import AtomicXCore
import SwiftUI

struct MergedMessageDetailView: View {
    @EnvironmentObject var themeState: ThemeState
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var sharedAudioPlayer = AudioPlayer.create()
    // Each AudioMessageView reads the "currently playing message" flag from this manager and
    // animates accordingly. If we let MessageView create its own AudioPlaybackManager (its
    // default value), every re-render produces a fresh instance whose currentPlayingMsgID
    // is always nil, so the playing animation never starts in the merged detail view.
    @StateObject private var audioPlaybackManager = AudioPlaybackManager()
    @StateObject private var messageStoreHolder = MergedMessageStoreHolder()
    @State private var subMessages: [MessageInfo] = []
    @State private var isLoading = true
    @State private var mergedActionStore: MessageActionStore? = nil

    let mergedMessage: MessageInfo
    let depth: Int

    private var messageStore: MessageListStore { messageStoreHolder.store }

    init(mergedMessage: MessageInfo, depth: Int = 0) {
        self.mergedMessage = mergedMessage
        self.depth = depth
    }
    
    private var title: String {
        if case .merged(let payload) = mergedMessage.messagePayload {
            return payload.title
        }
        return LocalizedChatString("")
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
            loadSubMessages()
        }
    }
    
    private var messageListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(subMessages.filter { $0.status != .revoked }) { message in
                    MessageView(
                        message: message,
                        messageListStore: messageStore,
                        conversationID: "",
                        audioPlayer: sharedAudioPlayer,
                        audioPlaybackManager: audioPlaybackManager,
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
    
    private func loadSubMessages() {
        let actionStore = MessageActionStore.create(message: mergedMessage)
        mergedActionStore = actionStore // Keep store alive until callback fires
        actionStore.downloadMergedMessageList(completion: MergedMessageDetailCompletionHandler(
            onSuccess: { messageList in
                DispatchQueue.main.async {
                    self.subMessages = messageList
                    self.isLoading = false
                    self.mergedActionStore = nil
                }
            },
            onFailure: { code, desc in
                print(">>>>> MergedMessageDetailView downloadMergedMessageList failed: \(code), \(desc)")
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.mergedActionStore = nil
                }
            }
        ))
    }
}

/// See `MessageListStoreHolder` in `MessageList.swift`. The merged message detail
/// view is a SwiftUI struct, so creating `MessageListStore` directly in `init`
/// would spawn a new IM SDK listener on every parent body re-render and leave
/// the SDK with dangling pointers in its listener hash table.
private final class MergedMessageStoreHolder: ObservableObject {
    let store: MessageListStore = MessageListStore.create(conversationID: "")
}

private final class MergedMessageDetailCompletionHandler: MergedMessageListCompletionHandler {
    private let onSuccessHandler: ([MessageInfo]) -> Void
    private let onFailureHandler: (Int, String) -> Void
    
    init(onSuccess: @escaping ([MessageInfo]) -> Void, onFailure: @escaping (Int, String) -> Void) {
        self.onSuccessHandler = onSuccess
        self.onFailureHandler = onFailure
    }
    
    func onSuccess(messageList: [MessageInfo]) {
        onSuccessHandler(messageList)
    }
    
    func onFailure(code: Int, desc: String) {
        onFailureHandler(code, desc)
    }
}

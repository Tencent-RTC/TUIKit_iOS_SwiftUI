import AtomicXCore
import SwiftUI

struct ForwardTargetSelector: View {
    @EnvironmentObject var themeState: ThemeState
    private let conversationStore = ConversationListStore.create()
    @State private var conversationList: [ConversationInfo] = []
    @State private var selectedConversationIDs: Set<String> = []
    @Environment(\.presentationMode) var presentationMode
    
    let onConfirm: ([String]) -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                conversationListView
                
                if !selectedConversationIDs.isEmpty {
                    selectedConversationsBar
                }
            }
            .background(themeState.colors.bgColorOperate)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("选择会话")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(themeState.colors.textColorPrimary)
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        onDismiss()
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(themeState.colors.buttonColorPrimaryDefault)
                }
            }
        }
        .onAppear {
            loadConversations()
        }
    }
    
    private var conversationListView: some View {
        List {
            Section {
                ForEach(conversationList) { conversation in
                    conversationRow(conversation)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(themeState.colors.bgColorOperate)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            toggleConversationSelection(conversation)
                        }
                }
            } header: {
                Text("最近聊天")
                    .font(.system(size: 13))
                    .foregroundColor(themeState.colors.textColorSecondary)
                    .textCase(nil)
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
    
    private func conversationRow(_ conversation: ConversationInfo) -> some View {
        HStack(spacing: 12) {
            Avatar(
                url: conversation.avatarURL,
                name: conversation.title
            )
            .frame(width: 40, height: 40)
            
            Text(conversation.title ?? "未命名会话")
                .font(.system(size: 16))
                .foregroundColor(themeState.colors.textColorPrimary)
                .lineLimit(1)
            
            Spacer()
            
            MessageCheckBox(
                isSelected: selectedConversationIDs.contains(conversation.conversationID)
            )
        }
    }
    
    private var selectedConversationsBar: some View {
        VStack(spacing: 0) {
            Divider()
                .background(themeState.colors.shadowColor)
            
            HStack(spacing: 12) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(getSelectedConversations(), id: \.conversationID) { conversation in
                            selectedConversationChip(conversation)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                
                Spacer()
                
                Button(action: {
                    onConfirm(Array(selectedConversationIDs))
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("发送 (\(selectedConversationIDs.count))")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(themeState.colors.buttonColorPrimaryDefault)
                        .cornerRadius(20)
                }
                .padding(.trailing, 16)
            }
            .frame(height: 60)
            .background(themeState.colors.bgColorOperate)
        }
    }
    
    private func selectedConversationChip(_ conversation: ConversationInfo) -> some View {
        HStack(spacing: 4) {
            Text(conversation.title ?? "")
                .font(.system(size: 14))
                .foregroundColor(themeState.colors.textColorPrimary)
                .lineLimit(1)
            
            Button(action: {
                selectedConversationIDs.remove(conversation.conversationID)
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(themeState.colors.textColorSecondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(themeState.colors.bgColorBubbleReciprocal)
        .cornerRadius(16)
    }
    
    private func toggleConversationSelection(_ conversation: ConversationInfo) {
        if selectedConversationIDs.contains(conversation.conversationID) {
            selectedConversationIDs.remove(conversation.conversationID)
        } else {
            selectedConversationIDs.insert(conversation.conversationID)
        }
    }
    
    private func getSelectedConversations() -> [ConversationInfo] {
        return conversationList.filter { selectedConversationIDs.contains($0.conversationID) }
    }
    
    private func loadConversations() {
        let option = ConversationLoadOption()
        conversationStore.loadConversations(option: option) { result in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    self.conversationList = self.conversationStore.state.value.conversationList
                }
            case .failure(let error):
                print("ForwardTargetSelector: Failed to load conversations: \(error.code), \(error.message)")
            }
        }
    }
}

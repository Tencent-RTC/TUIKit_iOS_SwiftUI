import AtomicXCore
import SwiftUI

/// A picker view for selecting group members to mention (supports multi-selection)
struct MentionMemberPicker: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var themeState: ThemeState
    @StateObject private var viewModel: MentionMemberPickerViewModel
    @State private var selectedMembers: Set<String> = []
    
    let groupID: String
    let onMembersSelected: ([MentionInfo], Int) -> Void
    let atPosition: Int
    
    init(
        groupID: String,
        atPosition: Int,
        onMembersSelected: @escaping ([MentionInfo], Int) -> Void
    ) {
        self.groupID = groupID
        self.atPosition = atPosition
        self.onMembersSelected = onMembersSelected
        self._viewModel = StateObject(wrappedValue: MentionMemberPickerViewModel(groupID: groupID))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // @All row (single select, immediate return)
                atAllRow
                
                Divider()
                
                // Member list (multi-select)
                if viewModel.isLoading && viewModel.members.isEmpty {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else {
                    memberList
                }
            }
            .background(themeState.colors.bgColorOperate)
            .navigationBarTitle(LocalizedChatString("MentionSelectMember"), displayMode: .inline)
            .navigationBarItems(leading: cancelButton, trailing: confirmButton)
        }
        .onAppear {
            viewModel.loadMembers()
        }
    }
    
    private var cancelButton: some View {
        Button(LocalizedChatString("Cancel")) {
            presentationMode.wrappedValue.dismiss()
        }
        .foregroundColor(themeState.colors.textColorLink)
    }
    
    private var confirmButton: some View {
        Button(LocalizedChatString("Confirm")) {
            confirmSelection()
        }
        .disabled(selectedMembers.isEmpty)
        .foregroundColor(themeState.colors.textColorLink)
    }
    
    private func confirmSelection() {
        let mentionInfos = viewModel.members
            .filter { selectedMembers.contains($0.userID) }
            .map { member in
                MentionInfo.create(
                    userID: member.userID,
                    displayName: member.displayName,
                    atPosition: atPosition
                )
            }
        onMembersSelected(mentionInfos, atPosition)
        presentationMode.wrappedValue.dismiss()
    }
    
    private var atAllRow: some View {
        Button(action: {
            // @All is single select - immediately return
            let mentionInfo = MentionInfo.create(
                userID: MentionInfo.atAllUserID,
                displayName: LocalizedChatString("MentionAll"),
                atPosition: atPosition
            )
            onMembersSelected([mentionInfo], atPosition)
            presentationMode.wrappedValue.dismiss()
        }) {
            HStack(spacing: 12) {
                // @All icon
                ZStack {
                    Circle()
                        .fill(themeState.colors.textColorLink)
                        .frame(width: 40, height: 40)
                    Text("@")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Text(LocalizedChatString("MentionAll"))
                    .font(.body)
                    .foregroundColor(themeState.colors.textColorLink)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(themeState.colors.bgColorOperate)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var memberList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.members, id: \.userID) { member in
                    UserPickerRow(
                        user: toUserPickerItem(member),
                        isSelected: selectedMembers.contains(member.userID),
                        isPreSelected: false,
                        onToggle: { _ in
                            toggleSelection(member.userID)
                        }
                    )
                    
                    // Load more when reaching the end
                    if member.userID == viewModel.members.last?.userID {
                        Color.clear
                            .frame(height: 1)
                            .onAppear {
                                viewModel.loadMoreMembers()
                            }
                    }
                }
                
                if viewModel.isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding()
                        Spacer()
                    }
                }
            }
        }
    }
    
    private func toUserPickerItem(_ member: GroupMember) -> UserPickerItem {
        UserPickerItem(
            userID: member.userID,
            avatarURL: member.avatarURL,
            title: member.displayName,
            subtitle: member.userID != member.displayName ? member.userID : nil,
            isDisabled: false
        )
    }
    
    private func toggleSelection(_ userID: String) {
        if selectedMembers.contains(userID) {
            selectedMembers.remove(userID)
        } else {
            selectedMembers.insert(userID)
        }
    }
}

// MARK: - ViewModel

class MentionMemberPickerViewModel: ObservableObject {
    @Published var members: [GroupMember] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    
    private let groupID: String
    private var settingStore: GroupSettingStore
    private var hasMoreData = true
    
    init(groupID: String) {
        self.groupID = groupID
        self.settingStore = GroupSettingStore.create(groupID: groupID)
    }
    
    func loadMembers() {
        guard !isLoading else { return }
        isLoading = true
        
        settingStore.fetchGroupMemberList(role: .all) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success:
                    self?.updateMembersFromState()
                case .failure(let error):
                    print(">>>>> Failed to load group members: \(error.message)")
                }
            }
        }
    }
    
    func loadMoreMembers() {
        guard !isLoadingMore && hasMoreData else { return }
        isLoadingMore = true
        
        settingStore.fetchMoreGroupMemberList { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoadingMore = false
                switch result {
                case .success:
                    self?.updateMembersFromState()
                case .failure(let error):
                    print(">>>>> Failed to load more group members: \(error.message)")
                    self?.hasMoreData = false
                }
            }
        }
    }
    
    private func updateMembersFromState() {
        let newMembers = settingStore.state.value.allMembers
        if newMembers.count == members.count {
            hasMoreData = false
        }
        members = newMembers
    }
}

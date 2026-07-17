import AtomicXCore
import SwiftUI

public struct AddFriendPage: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var themeState: ThemeState
    @StateObject private var toast = Toast()
    
    let userID: String
    private let showsOwnNavigation: Bool
    private let onSendMessageClick: (() -> Void)?
    private let onAddFriendSuccess: (() -> Void)?
    
    private let contactStore = ContactStore.shared
    @State private var userInfo: UserProfile?
    @State private var isLoading: Bool = false
    @State private var showingAddFriendSheet: Bool = false
    @State private var addFriendMessage: String = ""
    
    public init(
        userID: String,
        showsOwnNavigation: Bool = true,
        onSendMessageClick: (() -> Void)? = nil,
        onAddFriendSuccess: (() -> Void)? = nil
    ) {
        self.userID = userID
        self.showsOwnNavigation = showsOwnNavigation
        self.onSendMessageClick = onSendMessageClick
        self.onAddFriendSuccess = onAddFriendSuccess
    }
    
    public var body: some View {
        Group {
            if showsOwnNavigation {
                NavigationView {
                    contentView
                        .navigationBarTitle(LocalizedChatString("ProfileDetails"), displayMode: .inline)
                        .navigationBarBackButtonHidden(true)
                        .navigationBarItems(
                            leading: Button(action: {
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(themeState.colors.textColorLink)
                            }
                        )
                }
            } else {
                contentView
                    .navigationBarTitle(LocalizedChatString("ProfileDetails"), displayMode: .inline)
            }
        }
        .toast(toast)
        .sheet(isPresented: $showingAddFriendSheet) {
            AddFriendSheet(
                message: $addFriendMessage,
                userID: userID,
                onSend: { message in
                    sendFriendRequest(message: message)
                }
            )
            .environmentObject(themeState)
        }
        .onAppear {
            fetchUserInfo()
        }
    }
    
    private var contentView: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header with avatar and name
                VStack(spacing: 16) {
                    // Avatar
                    Avatar(
                        url: userInfo?.avatarURL,
                        name: userInfo?.nickname ?? userID,
                        size: .xxl
                    )
                    // User name
                    Text(userInfo?.nickname ?? userID)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(themeState.colors.textColorPrimary)
                    // User ID
                    Text("ID：\(userID)")
                        .font(.caption)
                        .foregroundColor(themeState.colors.textColorSecondary)
                }
                .padding(.top, 20)
                .padding(.bottom, 30)
                
                // Action buttons
                VStack(spacing: 16) {
                    // Add Friend Button
                    Button(action: {
                        showingAddFriendSheet = true
                    }) {
                        HStack {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 16, weight: .medium))
                            Text(LocalizedChatString("AddFriend"))
                                .font(.body)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(themeState.colors.textColorButton)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(themeState.colors.buttonColorPrimaryDefault)
                        )
                    }
                    .padding(.horizontal, 20)
                    
                }
                
                Spacer(minLength: 40)
            }
        }
        .background(themeState.colors.bgColorDefault)
    }
    
    private func fetchUserInfo() {
        isLoading = true
        contactStore.getContactInfo(userIDList: [userID], completion: ContactInfoHandler(
            onSuccess: { contactInfoList in
                DispatchQueue.main.async {
                    self.isLoading = false
                    if let contactInfo = contactInfoList.first {
                        self.userInfo = UserProfile(
                            userID: contactInfo.userID,
                            nickname: contactDisplayName(contactInfo),
                            avatarURL: contactInfo.avatarURL ?? ""
                        )
                    } else {
                        self.userInfo = UserProfile(userID: userID, nickname: userID, avatarURL: "")
                    }
                }
            },
            onFailure: { _, desc in
                DispatchQueue.main.async {
                    self.isLoading = false
                    print("Failed to fetch user info: \(desc)")
                    self.userInfo = UserProfile(userID: userID, nickname: userID, avatarURL: "")
                }
            }
        ))
    }
    
    private func sendFriendRequest(message: String) {
        contactStore.addFriend(userID: userID, remark: nil, addWording: message.isEmpty ? nil : message, completion: { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    // Show success message and dismiss all
                    WindowToastManager.shared.show(LocalizedChatString("FriendRequestSent"), type: .success, duration: 3)
                    self.onAddFriendSuccess?()
                case .failure(let error):
                    if error.code == 30515 {
                        WindowToastManager.shared.show(LocalizedChatString("AlreadyFriend"), type: .error, duration: 3)
                    } else if error.code == 30516 {
                        WindowToastManager.shared.show(LocalizedChatString("FriendRequestAlreadySentForbid"), type: .error, duration: 3)
                    } else if error.code == 30525 {
                        WindowToastManager.shared.show(LocalizedChatString("UserNotFound"), type: .error, duration: 3)
                    } else if error.code == 30539 {
                        WindowToastManager.shared.show(LocalizedChatString("FriendRequestSent"), type: .success, duration: 3)
                    }else {
                        WindowToastManager.shared.show(LocalizedChatString("FriendRequestFailed"), type: .error, duration: 3)
                    }
                }
            }
        })
    }
}

// MARK: - Add Friend Sheet

private struct AddFriendSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var themeState: ThemeState
    @Binding var message: String
    
    let userID: String
    let onSend: (String) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(LocalizedChatString("Cancel")) {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(themeState.colors.textColorLink)
                
                Spacer()
                
                Text(LocalizedChatString("AddFriend"))
                    .font(.headline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Button(LocalizedChatString("Send")) {
                    onSend(message)
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(themeState.colors.textColorLink)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            // Divider
            Rectangle()
                .fill(themeState.colors.textColorTertiary.opacity(0.2))
                .frame(height: 0.5)
            
            // Content
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(LocalizedChatString("AddFriendMessageHint"))
                        .font(.body)
                        .foregroundColor(themeState.colors.textColorTertiary)
                    
                    if #available(iOS 14.0, *) {
                        TextEditor(text: $message)
                            .frame(height: 100)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(themeState.colors.textColorSecondary.opacity(0.3), lineWidth: 1)
                            )
                    } else {
                        TextField(LocalizedChatString("AddFriendMessage"), text: $message)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
                                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
        .onAppear {
            if message.isEmpty {
                message = "\(LoginStore.shared.state.value.loginUserInfo?.nickname ?? "")"
            }
        }
    }
}

private final class ContactInfoHandler: GetContactInfoCompletionHandler {
    private let onSuccessBlock: ([ContactInfo]) -> Void
    private let onFailureBlock: (Int, String) -> Void

    init(onSuccess: @escaping ([ContactInfo]) -> Void, onFailure: @escaping (Int, String) -> Void) {
        self.onSuccessBlock = onSuccess
        self.onFailureBlock = onFailure
    }

    func onSuccess(contactInfoList: [ContactInfo]) {
        onSuccessBlock(contactInfoList)
    }

    func onFailure(code: Int, desc: String) {
        onFailureBlock(code, desc)
    }
}

// MARK: - Localized Strings Extension

extension String {
    static let NotFriendYet = "NotFriendYet"
    static let AddFriend = "AddFriend" 
    static let AddFriendMessage = "AddFriendMessage"
    static let AddFriendMessageHint = "AddFriendMessageHint"
    static let FriendRequestSent = "FriendRequestSent"
}

private func contactDisplayName(_ contact: ContactInfo) -> String {
    if let remark = contact.friendRemark, !remark.isEmpty {
        return remark
    }
    if let nickname = contact.nickname, !nickname.isEmpty {
        return nickname
    }
    return contact.userID
}

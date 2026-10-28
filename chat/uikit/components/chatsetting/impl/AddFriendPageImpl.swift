import AtomicXCore
import SwiftUI

struct AddFriendPageImpl: View {
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

    init(
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

    var body: some View {
        Group {
            if showsOwnNavigation {
                NavigationView {
                    contentView
                        .navigationBarTitle(LocalizedChatString("ProfileDetails"), displayMode: .inline)
                        .navigationBarBackButtonHidden(true)
                        .navigationBarItems(
                            leading: NavBackButtonView {
                                presentationMode.wrappedValue.dismiss()
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
                VStack(spacing: CGFloat(SpacingScheme.bubbleSpacing)) {
                    AvatarView(
                        url: userInfo?.avatarURL,
                        name: userInfo?.nickname ?? userID,
                        size: .xxl
                    )
                    Text(userInfo?.nickname ?? userID)
                        .font(FontScheme.body2Medium)
                        .foregroundColor(themeState.colors.textColorPrimary)
                    Text("ID：\(userID)")
                        .font(FontScheme.caption3Regular)
                        .foregroundColor(themeState.colors.textColorSecondary)
                }
                .padding(.top, CGFloat(SpacingScheme.contentSpacing))
                .padding(.bottom, CGFloat(SpacingScheme.titleSpacing))

                VStack(spacing: CGFloat(SpacingScheme.bubbleSpacing)) {
                    Button(action: {
                        showingAddFriendSheet = true
                    }) {
                        HStack {
                            Image(systemName: "person.badge.plus")
                                .font(FontScheme.caption1Medium)
                            Text(LocalizedChatString("AddFriend"))
                                .font(FontScheme.caption1Medium)
                        }
                        .foregroundColor(themeState.colors.textColorButton)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: CGFloat(RadiusScheme.smallRadius))
                                .fill(themeState.colors.buttonColorPrimaryDefault)
                        )
                    }
                    .padding(.horizontal, CGFloat(SpacingScheme.contentSpacing))

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


private struct AddFriendSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var themeState: ThemeState
    @Binding var message: String

    let userID: String
    let onSend: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(LocalizedChatString("Cancel")) {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(themeState.colors.textColorLink)

                Spacer()

                Text(LocalizedChatString("AddFriend"))
                    .font(FontScheme.caption1Medium)

                Spacer()

                Button(LocalizedChatString("Send")) {
                    onSend(message)
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(themeState.colors.textColorLink)
            }
            .padding(.horizontal, CGFloat(SpacingScheme.contentSpacing))
            .padding(.vertical, CGFloat(SpacingScheme.bubbleSpacing))

            Rectangle()
                .fill(themeState.colors.textColorTertiary.opacity(0.2))
                .frame(height: 0.5)

            VStack(alignment: .leading, spacing: CGFloat(SpacingScheme.contentSpacing)) {
                VStack(alignment: .leading, spacing: CGFloat(SpacingScheme.smallSpacing)) {
                    Text(LocalizedChatString("AddFriendMessageHint"))
                        .font(FontScheme.caption1Regular)
                        .foregroundColor(themeState.colors.textColorTertiary)

                    if #available(iOS 14.0, *) {
                        TextEditor(text: $message)
                            .frame(height: 100)
                            .overlay(
                                RoundedRectangle(cornerRadius: CGFloat(RadiusScheme.smallRadius))
                                    .stroke(themeState.colors.textColorSecondary.opacity(0.3), lineWidth: 1)
                            )
                    } else {
                        TextField(LocalizedChatString("AddFriendMessage"), text: $message)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }

                Spacer()
            }
            .padding(.horizontal, CGFloat(SpacingScheme.contentSpacing))
            .padding(.top, CGFloat(SpacingScheme.contentSpacing))
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

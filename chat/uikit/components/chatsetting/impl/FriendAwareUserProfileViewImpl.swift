import AtomicXCore
import SwiftUI

struct FriendAwareUserProfileViewImpl<FriendContent: View>: View {
    let userID: String
    private let friendContent: (String) -> FriendContent

    @State private var isFriend: Bool?
    @State private var fallbackContactInfo: ContactInfo?

    init(userID: String, @ViewBuilder friendContent: @escaping (String) -> FriendContent) {
        self.userID = userID
        self.friendContent = friendContent
    }

    var body: some View {
        Group {
            if let isFriend = isFriend {
                if isFriend {
                    friendContent(userID)
                } else {
                    AddContactDetailView(userID: userID, contactInfo: fallbackContactInfo)
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            if isFriend == nil { route() }
        }
    }

    private func route() {
        if ContactStore.shared.state.value.friendList.contains(where: { $0.userID == userID }) {
            isFriend = true
            return
        }
        ContactStore.shared.loadFriends { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.isFriend = ContactStore.shared.state.value.friendList.contains { $0.userID == self.userID }
                case .failure:
                    self.fallbackToContactInfo()
                }
            }
        }
    }

    private func fallbackToContactInfo() {
        ContactStore.shared.getContactInfo(
            userIDList: [userID],
            completion: ContactInfoHandler(
                onSuccess: { contactInfoList in
                    DispatchQueue.main.async {
                        let info = contactInfoList.first
                        self.fallbackContactInfo = info
                        self.isFriend = info?.isFriend ?? false
                    }
                },
                onFailure: { _, _ in
                    DispatchQueue.main.async {
                        self.isFriend = false
                    }
                }
            )
        )
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

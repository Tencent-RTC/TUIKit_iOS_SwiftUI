import AtomicXCore
import SwiftUI

public struct FriendAwareUserProfileView: View {
    let userID: String
    @State private var isFriend: Bool? = nil
    @State private var isLoading: Bool = true
    
    public init(userID: String) {
        self.userID = userID
    }
    
    public var body: some View {
        Group {
            if isLoading {
                // Show loading indicator while checking friendship status
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let isFriend = isFriend {
                if isFriend {
                    // Show C2CChatSetting for friends
                    C2CChatSetting(userID: userID)
                } else {
                    // Show AddFriendPage for non-friends
                    AddFriendPage(userID: userID, showsOwnNavigation: false)
                }
            } else {
                // Show error state
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("Failed to load user information")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            checkFriendshipStatus()
        }
    }
    
    private func checkFriendshipStatus() {
        isLoading = true
        ContactStore.shared.getContactInfo(
            userIDList: [userID],
            completion: ContactInfoHandler(
                onSuccess: { contactInfoList in
                    DispatchQueue.main.async {
                        self.isFriend = contactInfoList.first?.isFriend ?? false
                        self.isLoading = false
                    }
                },
                onFailure: { _, _ in
                    DispatchQueue.main.async {
                        self.isFriend = false
                        self.isLoading = false
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

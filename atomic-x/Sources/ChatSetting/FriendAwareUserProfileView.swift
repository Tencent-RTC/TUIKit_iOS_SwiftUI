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
                    C2CChatSetting(userID: userID, showsOwnNavigation: false)
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
        let contactStore = ContactListStore.create()
        
        contactStore.fetchUserInfo(userID: userID, completion: { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    // Check the result in the store's state
                    let contactInfo = contactStore.state.value.addFriendInfo
                    self.isFriend = contactInfo?.isContact ?? false
                case .failure:
                    // If failed to get user info, assume not a friend
                    self.isFriend = false
                }
                self.isLoading = false
            }
        })
    }
}

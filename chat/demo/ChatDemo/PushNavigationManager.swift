import Foundation
import SwiftUI
import Combine

// MARK: - Push Navigation Manager
class PushNavigationManager: ObservableObject {
    static let shared = PushNavigationManager()
    
    @Published var pendingNavigation: PushNavigationInfo? = nil
    
    private init() {}
    
    func navigateToChat(userID: String? = nil, groupID: String? = nil) {
        DispatchQueue.main.async {
            self.pendingNavigation = PushNavigationInfo(userID: userID, groupID: groupID)
        }
    }
    
    func clearPendingNavigation() {
        pendingNavigation = nil
    }
}

// MARK: - Push Navigation Info
struct PushNavigationInfo: Equatable {
    let userID: String?
    let groupID: String?
    let timestamp: Date = Date()
    
    static func == (lhs: PushNavigationInfo, rhs: PushNavigationInfo) -> Bool {
        return lhs.userID == rhs.userID && 
               lhs.groupID == rhs.groupID && 
               lhs.timestamp == rhs.timestamp
    }
}

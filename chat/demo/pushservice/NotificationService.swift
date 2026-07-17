import TIMPush
import UserNotifications

class NotificationService: UNNotificationServiceExtension {
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        // App Group ID (same as in AppDelegate)
        let appGroupID = kTIMPushAppGroupKey

        // Handle notification service request for delivery statistics
        TIMPushManager.handleNotificationServiceRequest(request: request, appGroupID: appGroupID) { [weak self] _ in
            if let bestAttemptContent = self?.bestAttemptContent {
                self?.contentHandler?(bestAttemptContent)
            }
        }
    }

    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        if let contentHandler = contentHandler, let bestAttemptContent = bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
}

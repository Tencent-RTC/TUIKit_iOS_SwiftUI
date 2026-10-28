import AtomicXCore
import Foundation

public final class VoiceMessageConfig {
    public static let shared = VoiceMessageConfig()

    private let KeyPrefix = "voice_message_config"
    private let NameSelectedVoiceId = "selectedVoiceId"
    private let NameSelectedVoiceName = "selectedVoiceName"

    public func getSelectedVoiceId() -> String {
        return storage().string(forKey: key(NameSelectedVoiceId)) ?? ""
    }

    public func getSelectedVoiceName() -> String {
        return storage().string(forKey: key(NameSelectedVoiceName)) ?? ""
    }

    public func setSelectedVoice(id: String, name: String) {
        let storage = storage()
        storage.set(id, forKey: key(NameSelectedVoiceId))
        storage.set(name, forKey: key(NameSelectedVoiceName))
    }

    private init() {}

    private func storage() -> UserDefaults {
        return UserDefaults.standard
    }

    private func key(_ name: String) -> String {
        let userId = currentUserId()
        return userId.isEmpty ? "\(KeyPrefix).\(name)" : "\(KeyPrefix).\(userId).\(name)"
    }

    private func currentUserId() -> String {
        return LoginStore.shared.state.value.loginUserInfo?.userID ?? ""
    }
}

public struct CustomVoiceItem: Equatable, Hashable {
    public let voiceId: String
    public let name: String
    let isDefault: Bool

    public init(voiceId: String, name: String, isDefault: Bool) {
        self.voiceId = voiceId
        self.name = name
        self.isDefault = isDefault
    }

    public static func == (lhs: CustomVoiceItem, rhs: CustomVoiceItem) -> Bool {
        lhs.voiceId == rhs.voiceId
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(voiceId)
    }
}

public enum VoiceItemProvider {
    static let defaultVoiceItems: [(voiceId: String, nameKey: String)] = [
        ("", "voice_message_voice_default"),
        ("male-kefu-xiaoxu", "voice_message_voice_xiaoxu"),
        ("female-kefu-xiaomei", "voice_message_voice_xiaomei"),
        ("female-kefu-xiaoxin", "voice_message_voice_xiaoxin"),
        ("female-kefu-xiaoyue", "voice_message_voice_xiaoyue")
    ]

    public static func defaultVoiceList() -> [CustomVoiceItem] {
        defaultVoiceItems.map { CustomVoiceItem(voiceId: $0.voiceId, name: LocalizedChatString($0.nameKey), isDefault: true) }
    }
}

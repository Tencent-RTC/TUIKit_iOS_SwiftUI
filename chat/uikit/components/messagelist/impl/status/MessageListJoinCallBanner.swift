import AtomicXCore
import Combine
import ImSDK_Plus
import Kingfisher
import SwiftUI

struct JoinCallBannerUser {
    let id: String
    var displayName: String
    var avatarURL: String?
}

struct JoinCallBannerState: Equatable {
    let callID: String
    let mediaType: String
    var users: [JoinCallBannerUser]
    let isCurrentUserJoined: Bool

    var shouldShowJoinButton: Bool { !isCurrentUserJoined }
}

extension JoinCallBannerUser: Equatable {}

enum JoinCallBannerStateParser {
    private static let keyBusinessType = "business_type"
    private static let keyCallID = "call_id"
    private static let keyCallMediaType = "call_media_type"
    private static let keyUserList = "user_list"
    private static let keyUserID = "userid"
    private static let keyUserIDAlt = "userID"
    private static let keyNickname = "nickname"
    private static let keyName = "name"
    private static let keyAvatarURL = "avatar_url"
    private static let keyFaceURL = "faceUrl"
    private static let valueBusinessType = "callkit"

    static func parse(raw: String?, currentUserID: String?) -> JoinCallBannerState? {
        guard let raw = raw, !raw.isEmpty,
              let data = raw.data(using: .utf8),
              let map = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let businessType = map[keyBusinessType] as? String
        let callID = map[keyCallID] as? String
        let mediaType = map[keyCallMediaType] as? String
        let users = parseUsers(map[keyUserList])
        guard businessType == valueBusinessType,
              let callID = callID, !callID.isEmpty,
              let mediaType = mediaType, !mediaType.isEmpty,
              users.count > 1 else {
            return nil
        }

        let isCurrentUserJoined = currentUserID != nil && users.contains { $0.id == currentUserID }
        return JoinCallBannerState(
            callID: callID,
            mediaType: mediaType,
            users: users,
            isCurrentUserJoined: isCurrentUserJoined
        )
    }

    private static func parseUsers(_ value: Any?) -> [JoinCallBannerUser] {
        guard let list = value as? [Any] else { return [] }
        return list.compactMap { item in
            guard let userMap = item as? [String: Any] else { return nil }
            let userID = (userMap[keyUserID] as? String) ?? (userMap[keyUserIDAlt] as? String)
            guard let id = userID, !id.isEmpty else { return nil }
            let displayName = (userMap[keyNickname] as? String) ?? (userMap[keyName] as? String) ?? id
            let avatarURL = (userMap[keyAvatarURL] as? String) ?? (userMap[keyFaceURL] as? String)
            return JoinCallBannerUser(id: id, displayName: displayName, avatarURL: avatarURL)
        }
    }
}

final class MessageListJoinCallBannerController: NSObject, ObservableObject {
    @Published private(set) var state: JoinCallBannerState?

    private static let groupAttributeKey = "inner_attr_kit_info"
    private static let conversationGroupPrefix = "group_"

    private var currentGroupID: String?
    private var currentCallID: String?

    func bind(conversationID: String) {
        let groupID = conversationID.hasPrefix(Self.conversationGroupPrefix)
            ? String(conversationID.dropFirst(Self.conversationGroupPrefix.count))
            : nil
        if groupID == currentGroupID { return }
        release()
        guard let groupID = groupID, !groupID.isEmpty else { return }
        currentGroupID = groupID
        V2TIMManager.sharedInstance().addGroupListener(listener: self)
        V2TIMManager.sharedInstance().getGroupAttributes(groupID, keys: [Self.groupAttributeKey], succ: { [weak self] attributes in
            guard let self = self, groupID == self.currentGroupID else { return }
            DispatchQueue.main.async {
                self.render(attributes: attributes as? [String: String])
            }
        }, fail: { [weak self] _, _ in
            guard let self = self, groupID == self.currentGroupID else { return }
            DispatchQueue.main.async {
                self.currentCallID = nil
                self.state = nil
            }
        })
    }

    func release() {
        V2TIMManager.sharedInstance().removeGroupListener(listener: self)
        currentGroupID = nil
        currentCallID = nil
        state = nil
    }

    private func render(attributes: [String: String]?) {
        let currentUserID = LoginStore.shared.state.value.loginUserInfo?.userID
        guard let parsed = JoinCallBannerStateParser.parse(raw: attributes?[Self.groupAttributeKey], currentUserID: currentUserID),
              !parsed.callID.isEmpty else {
            currentCallID = nil
            state = nil
            return
        }
        currentCallID = parsed.callID
        state = parsed
        fetchUserProfiles(state: parsed)
    }

    private func fetchUserProfiles(state: JoinCallBannerState) {
        let userIDs = state.users.map { $0.id }.filter { !$0.isEmpty }
        guard !userIDs.isEmpty else { return }
        ContactStore.shared.getContactInfo(userIDList: userIDs, completion: JoinCallContactInfoHandler(
            onSuccess: { [weak self] contactInfoList in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    guard self.currentCallID == state.callID else { return }
                    var profileByUserID: [String: ContactInfo] = [:]
                    for info in contactInfoList {
                        profileByUserID[info.userID] = info
                    }
                    guard !profileByUserID.isEmpty else { return }
                    var enriched = state
                    enriched.users = state.users.map { user in
                        guard let profile = profileByUserID[user.id] else { return user }
                        var updated = user
                        if let nickname = profile.nickname, !nickname.isEmpty {
                            updated.displayName = nickname
                        }
                        if let avatarURL = profile.avatarURL, !avatarURL.isEmpty {
                            updated.avatarURL = avatarURL
                        }
                        return updated
                    }
                    self.state = enriched
                }
            },
            onFailure: { _, _ in }
        ))
    }
}

extension MessageListJoinCallBannerController: V2TIMGroupListener {
    func onGroupAttributeChanged(_ groupID: String!, attributes: NSMutableDictionary!) {
        guard let groupID = groupID, !groupID.isEmpty, groupID == currentGroupID else { return }
        render(attributes: attributes as? [String: String])
    }
}

private final class JoinCallContactInfoHandler: GetContactInfoCompletionHandler {
    private let successBlock: ([ContactInfo]) -> Void
    private let failureBlock: (Int, String) -> Void

    init(onSuccess: @escaping ([ContactInfo]) -> Void, onFailure: @escaping (Int, String) -> Void) {
        successBlock = onSuccess
        failureBlock = onFailure
    }

    func onSuccess(contactInfoList: [ContactInfo]) {
        successBlock(contactInfoList)
    }

    func onFailure(code: Int, desc: String) {
        failureBlock(code, desc)
    }
}

struct MessageListJoinCallBannerView: View {
    @EnvironmentObject var themeState: ThemeState
    let state: JoinCallBannerState
    @State private var isExpanded = false
    @State private var boundCallID: String?

    private static let cardCornerRadius = CGFloat(RadiusScheme.alertRadius)
    private static let cardTopPadding = CGFloat(SpacingScheme.smallSpacing)
    private static let cardHorizontalPadding = CGFloat(SpacingScheme.iconIconSpacing)
    private static let cardBottomPadding = CGFloat(SpacingScheme.smallSpacing)
    private static let callIconSize: CGFloat = 22
    private static let callIconLeadingPadding = CGFloat(SpacingScheme.bubbleSpacing)
    private static let headerVerticalPadding = CGFloat(SpacingScheme.iconIconSpacing)
    private static let hintIconSpacing = CGFloat(SpacingScheme.iconIconSpacing)
    private static let chevronSize: CGFloat = 20
    private static let chevronTrailingPadding = CGFloat(SpacingScheme.bubbleSpacing)
    private static let avatarSize: CGFloat = 52
    private static let avatarSpacing = CGFloat(SpacingScheme.bubbleSpacing)
    private static let maxVisibleAvatarCount = 4
    private static let avatarRowTopPadding = CGFloat(SpacingScheme.contentSpacing)
    private static let dividerTopPadding = CGFloat(SpacingScheme.titleSpacing)
    private static let joinButtonHeight: CGFloat = 48
    private static let expandDuration: TimeInterval = 0.22
    private static let chevronRotationDuration: TimeInterval = 0.18

    var body: some View {
        VStack(spacing: 0) {
            headerRow
            if isExpanded {
                expandedContent
            }
        }
        .background(themeState.colors.bgColorOperate)
        .cornerRadius(Self.cardCornerRadius)
        .shadow(color: Colors.Black1.opacity(0.12), radius: 4, x: 0, y: 2)
        .padding(.top, Self.cardTopPadding)
        .padding(.horizontal, Self.cardHorizontalPadding)
        .padding(.bottom, Self.cardBottomPadding)
        .onAppear {
            collapseIfNewCall()
        }
        .onChange(of: state.callID) { _ in
            collapseIfNewCall()
        }
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            callIcon
            Text(String(format: LocalizedChatString("MessageListJoinGroupCallUsers"), state.users.count))
                .font(FontScheme.caption1Regular)
                .foregroundColor(themeState.colors.textColorPrimary)
                .padding(.leading, Self.hintIconSpacing)
            Spacer(minLength: Self.hintIconSpacing)
            JoinCallChevronShape()
                .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .foregroundColor(themeState.colors.textColorSecondary)
                .frame(width: Self.chevronSize, height: Self.chevronSize)
                .rotationEffect(.radians(isExpanded ? .pi : 0))
                .animation(.easeOut(duration: Self.chevronRotationDuration), value: isExpanded)
        }
        .padding(.leading, Self.callIconLeadingPadding)
        .padding(.trailing, Self.chevronTrailingPadding)
        .padding(.vertical, Self.headerVerticalPadding)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeOut(duration: Self.expandDuration)) {
                isExpanded.toggle()
            }
        }
    }

    private var callIcon: some View {
        let lowercased = state.mediaType.lowercased()
        let iconName = (lowercased.contains("audio") || lowercased.contains("voice")) ? "message_call_audio" : "message_call_video"
        return Image(iconName, bundle: AtomicXChatResources.resourceBundle)
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .frame(width: Self.callIconSize, height: Self.callIconSize)
            .foregroundColor(themeState.colors.buttonColorPrimaryDefault)
    }

    private var expandedContent: some View {
        VStack(spacing: 0) {
            avatarRow
                .padding(.top, Self.avatarRowTopPadding)
            if state.shouldShowJoinButton {
                Rectangle()
                    .fill(themeState.colors.strokeColorSecondary)
                    .frame(height: 1.0 / UIScreen.main.scale)
                    .padding(.top, Self.dividerTopPadding)
                Button(action: {
                    ChatCallEventPublisher.publishStartJoin(callID: state.callID)
                }) {
                    Text(LocalizedChatString("MessageListJoinGroupCall"))
                        .font(FontScheme.caption1Regular)
                        .foregroundColor(themeState.colors.textColorPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: Self.joinButtonHeight)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    private var avatarRow: some View {
        let viewportWidth = Self.avatarSize * CGFloat(Self.maxVisibleAvatarCount)
            + Self.avatarSpacing * CGFloat(Self.maxVisibleAvatarCount - 1)
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Self.avatarSpacing) {
                ForEach(state.users, id: \.id) { user in
                    JoinCallAvatarView(url: user.avatarURL, name: user.displayName)
                }
            }
        }
        .frame(maxWidth: viewportWidth)
        .frame(height: Self.avatarSize)
        .frame(maxWidth: .infinity)
    }

    private func collapseIfNewCall() {
        if state.callID != boundCallID {
            boundCallID = state.callID
            isExpanded = false
        }
    }
}

private struct JoinCallChevronShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.25, y: rect.height * 0.38))
        path.addLine(to: CGPoint(x: rect.width * 0.5, y: rect.height * 0.62))
        path.addLine(to: CGPoint(x: rect.width * 0.75, y: rect.height * 0.38))
        return path
    }
}

private struct JoinCallAvatarView: View {
    @EnvironmentObject var themeState: ThemeState
    let url: String?
    let name: String

    private static let size: CGFloat = 52

    var body: some View {
        if let url = url, !url.isEmpty, let imageURL = URL(string: url) {
            KFImage(imageURL)
                .resizable()
                .scaledToFill()
                .frame(width: Self.size, height: Self.size)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(themeState.colors.bgColorAvatar)
                .frame(width: Self.size, height: Self.size)
                .overlay(
                    Text(name.isEmpty ? "" : String(name.prefix(1)).uppercased())
                        .font(FontScheme.body3Regular)
                        .foregroundColor(themeState.colors.textColorPrimary)
                )
        }
    }
}

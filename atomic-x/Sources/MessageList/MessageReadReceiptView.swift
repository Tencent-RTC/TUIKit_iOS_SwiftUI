import AtomicXCore
import SwiftUI

public struct MessageReadReceiptView: View {
    @EnvironmentObject var themeState: ThemeState
    
    private let messageActionStore: MessageActionStore
    private let messageListStore: MessageListStore
    private let message: MessageInfo
    
    @State private var isReadSectionExpanded: Bool = true
    @State private var isDeliveredSectionExpanded: Bool = true
    @State private var readMemberList: [GroupMember] = []
    @State private var hasMoreReadMembers: Bool = true
    @State private var unReadMemberList: [GroupMember] = []
    @State private var hasMoreUnReadMembers: Bool = true
    
    public init(messageActionStore: MessageActionStore, messageListStore: MessageListStore, message: MessageInfo) {
        self.messageActionStore = messageActionStore
        self.messageListStore = messageListStore
        self.message = message
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                dateLabel
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                messageBubble
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                readSection
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                deliveredSection
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                
                Spacer(minLength: 0)
            }
        }
        .navigationTitle(LocalizedChatString("MessageReadDetail"))
        .navigationBarTitleDisplayMode(.inline)
        .background(themeState.colors.bgColorDefault)
        .onAppear {
            loadInitialData()
        }
        .onReceive(messageActionStore.state.subscribe(StatePublisherSelector(keyPath: \.readMemberList))) { readMembers in
            readMemberList = readMembers
        }
        .onReceive(messageActionStore.state.subscribe(StatePublisherSelector(keyPath: \.hasMoreReadMembers))) { hasMore in
            hasMoreReadMembers = hasMore
        }
        .onReceive(messageActionStore.state.subscribe(StatePublisherSelector(keyPath: \.unreadMemberList))) { unReadMembers in
            unReadMemberList = unReadMembers
        }
        .onReceive(messageActionStore.state.subscribe(StatePublisherSelector(keyPath: \.hasMoreUnreadMembers))) { hasMore in
            hasMoreUnReadMembers = hasMore
        }
    }
    
    private var dateLabel: some View {
        Text(formattedDate)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(themeState.colors.textColorSecondary)
    }

    private var messageBubble: some View {
        HStack {
            Spacer()
            
            VStack(alignment: .trailing, spacing: 0) {
                messageContent
            }
        }
    }
    
    @ViewBuilder
    private var messageContent: some View {
        if let payload = message.messagePayload {
            switch payload {
            case .text(let payload):
                TextMessageView(
                    payload: payload,
                    message: message,
                    isLeft: false,
                    isSelf: true,
                    shouldHighlight: false
                )
                
            case .image(let payload):
                ImageMessageView(
                    payload: payload,
                    message: message,
                    messageListStore: messageListStore,
                    onImageTap: {}
                )
                
            case .video(let payload):
                VideoMessageView(
                    payload: payload,
                    message: message,
                    messageListStore: messageListStore,
                    onVideoTap: {},
                    onPlayVideo: {}
                )
                
            case .audio(let payload):
                ReadOnlyAudioMessageView(
                    payload: payload,
                    isSelf: true
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(themeState.colors.bgColorBubbleOwn)
                .cornerRadius(16)
                
            case .file(let payload):
                ReadOnlyFileMessageView(
                    payload: payload,
                    isSelf: true
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(themeState.colors.bgColorBubbleOwn)
                .cornerRadius(16)
                
            case .face:
                Text("[表情]")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(themeState.colors.textColorPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(themeState.colors.bgColorBubbleOwn)
                    .cornerRadius(16)
                
            case .custom:
                Text("[自定义消息]")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(themeState.colors.textColorPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(themeState.colors.bgColorBubbleOwn)
                    .cornerRadius(16)
                
            case .merged(let payload):
                if !payload.title.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Image(systemName: "doc.on.doc.fill")
                            .font(.system(size: 20))
                            .foregroundColor(themeState.colors.textColorLink)
                        Text(payload.title)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(themeState.colors.textColorPrimary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(themeState.colors.bgColorBubbleOwn)
                    .cornerRadius(16)
                } else {
                    Text("[聊天记录]")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(themeState.colors.textColorPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(themeState.colors.bgColorBubbleOwn)
                        .cornerRadius(16)
                }
                
            default:
                Text("[消息]")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(themeState.colors.textColorPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(themeState.colors.bgColorBubbleOwn)
                    .cornerRadius(16)
            }
        }
    }
    
    private var readSection: some View {
        VStack(spacing: 0) {
            sectionHeader(
                title: LocalizedChatString("GroupReadBy"),
                iconName: "checkmark.circle.fill",
                isExpanded: $isReadSectionExpanded
            )
            .background(themeState.colors.bgColorOperate)
            .cornerRadius(isReadSectionExpanded ? 40 : 30, corners: .allCorners)
            
            if isReadSectionExpanded {
                VStack(spacing: 0) {
                    ForEach(readMemberList) { member in
                        userRow(member: member)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 8)
                    }
                    
                    if hasMoreReadMembers {
                        loadMoreButton(isRead: true)
                            .padding(.vertical, 8)
                    }
                }
                .padding(.top, 12)
            }
        }
    }
    
    private var deliveredSection: some View {
        VStack(spacing: 0) {
            sectionHeader(
                title: LocalizedChatString("GroupDeliveredTo"),
                iconName: "checkmark.circle",
                isExpanded: $isDeliveredSectionExpanded
            )
            .background(themeState.colors.bgColorOperate)
            .cornerRadius(isDeliveredSectionExpanded ? 40 : 30, corners: .allCorners)
            
            if isDeliveredSectionExpanded {
                VStack(spacing: 0) {
                    ForEach(unReadMemberList) { member in
                        userRow(member: member)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 8)
                    }
                    
                    if hasMoreUnReadMembers {
                        loadMoreButton(isRead: false)
                            .padding(.vertical, 8)
                    }
                }
                .padding(.top, 12)
            }
        }
    }
    
    private func sectionHeader(title: String, iconName: String, isExpanded: Binding<Bool>) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.3)) {
                isExpanded.wrappedValue.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: iconName)
                    .font(.system(size: 14))
                    .foregroundColor(themeState.colors.textColorPrimary)

                Text(title)
                    .font(.system(size: 14))
                    .foregroundColor(themeState.colors.textColorPrimary)
                
                Spacer()
  
                Image(systemName: isExpanded.wrappedValue ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(themeState.colors.textColorSecondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
    }
    
    private func userRow(member: GroupMember) -> some View {
        HStack(spacing: 12) {
            Avatar(
                url: member.avatarURL,
                name: member.nickname ?? member.userID,
                size: .s
            )
            
            Text(member.nickname ?? member.userID)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(themeState.colors.textColorPrimary)
            
            Spacer()
        }
    }
    
    private func loadMoreButton(isRead: Bool) -> some View {
        Button {
            loadMoreMembers(isRead: isRead)
        } label: {
            HStack {
                Spacer()
                Text(LocalizedChatString("Loading more"))
                    .font(.system(size: 14))
                    .foregroundColor(themeState.colors.textColorLink)
                Spacer()
            }
            .padding(.vertical, 12)
            .background(themeState.colors.bgColorOperate.opacity(0.5))
            .cornerRadius(8)
        }
        .padding(.horizontal, 8)
    }
    
    private func loadInitialData() {
        messageActionStore.loadReadMembers(count: 20) { result in
            switch result {
            case .success:
                break
            case .failure(let error):
                print("MessageReadReceiptView: load read members failed. code: \(error.code), message: \(error.message)")
            }
        }
        
        messageActionStore.loadUnreadMembers(count: 20) { result in
            switch result {
            case .success:
                break
            case .failure(let error):
                print("MessageReadReceiptView: load unread members failed.code: \(error.code), message: \(error.message)")
            }
        }
    }
    
    private func loadMoreMembers(isRead: Bool) {
        messageActionStore.loadMoreMembers(isRead: isRead) { result in
            switch result {
            case .success:
                break
            case .failure(let error):
                print("MessageReadReceiptView: load members failed, isRead:\(isRead). code: \(error.code), message: \(error.message)")
            }
        }
    }
    
    private var formattedDate: String {
        guard let timestamp = date(from: message.timestamp) else {
            return ""
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:MM"
        return formatter.string(from: timestamp)
    }
    
    private var messageTimeString: String {
        guard let timestamp = date(from: message.timestamp) else {
            return "15:24"
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: timestamp)
    }

    private func date(from timestamp: Int64?) -> Date? {
        guard let timestamp = timestamp else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(timestamp))
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

private struct ReadOnlyAudioMessageView: View {
    @EnvironmentObject var themeState: ThemeState
    let payload: AudioMessagePayload
    let isSelf: Bool
    
    var body: some View {
        let duration = payload.audioDuration
        let displayText = formatDuration(duration)
        
        HStack(spacing: 12) {
            Image(systemName: "play.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isSelf ? themeState.colors.textColorPrimary : themeState.colors.buttonColorPrimaryDefault)
                .frame(width: 32, height: 32)
                .opacity(0.5)

            HStack(spacing: 2) {
                ForEach(0 ..< 8, id: \.self) { index in
                    let heights: [CGFloat] = [8, 16, 12, 20, 10, 14, 17, 8]
                    RoundedRectangle(cornerRadius: 1)
                        .frame(width: 2, height: heights[index])
                        .foregroundColor(isSelf ? themeState.colors.textColorPrimary : themeState.colors.buttonColorPrimaryDefault)
                        .opacity(0.6)
                }
            }
            .frame(height: 24)
            
            Text(displayText)
                .font(.system(size: 12))
                .foregroundColor(isSelf ? themeState.colors.textColorSecondary : themeState.colors.textColorSecondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
    }
    
    private func formatDuration(_ duration: Int) -> String {
        let seconds = duration % 60
        let minutes = duration / 60
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, seconds)
        } else {
            return String(format: "%d\"", seconds)
        }
    }
}

private struct ReadOnlyFileMessageView: View {
    @EnvironmentObject var themeState: ThemeState
    let payload: FileMessagePayload
    let isSelf: Bool
    
    var body: some View {
        HStack {
            Image(systemName: FilePreviewManager.fileTypeIcon(for: payload.fileName ?? "unknown"))
                .font(.system(size: 30))
                .foregroundColor(isSelf ? themeState.colors.textColorPrimary : themeState.colors.buttonColorPrimaryDefault)
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(payload.fileName ?? LocalizedChatString("UnknownFile"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(themeState.colors.textColorPrimary)
                    .lineLimit(1)
 
                Text(FilePreviewManager.formatFileSize(Int64(payload.fileSize)))
                    .font(.system(size: 12))
                    .foregroundColor(themeState.colors.textColorSecondary)
            }
            
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: 250, alignment: .leading)
    }
}

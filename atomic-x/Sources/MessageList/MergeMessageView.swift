import AtomicXCore
import SwiftUI

struct MergeMessageView: View {
    @EnvironmentObject var themeState: ThemeState
    @Environment(\.isInMergedDetailView) private var isInMergedDetailView
    let message: MessageInfo
    @State private var showDetailView = false
    
    private let bubbleWidth: CGFloat = UIScreen.main.bounds.width * 0.6
    
    private var mergedTitle: String {
        if case .merged(let payload) = message.messagePayload, !payload.title.isEmpty {
            return payload.title
        }
        return LocalizedChatString("RelayChatHistory")
    }
    
    private var abstractList: [String] {
        if case .merged(let payload) = message.messagePayload {
            return payload.abstractList ?? []
        }
        return []
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title
            Text(mergedTitle)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(themeState.colors.textColorPrimary)
                .lineLimit(1)
                .padding(.horizontal, 16)
                .padding(.top, 12)
            
            // Abstract list (max 4 lines)
            if !abstractList.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(abstractList.prefix(4), id: \.self) { abstract in
                        Text(EmojiManager.shared.createLocalizedStringFromEmojiCodes(abstract))
                            .font(.system(size: 12))
                            .foregroundColor(themeState.colors.textColorSecondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(height: 16, alignment: .leading)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            
            // Divider
            Rectangle()
                .fill(themeState.colors.shadowColor)
                .frame(height: 1)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            
            // Bottom hint
            Text(LocalizedChatString("RelayChatHistory"))
                .font(.system(size: 10))
                .foregroundColor(themeState.colors.textColorTertiary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
        }
        .frame(width: bubbleWidth)
        .background(themeState.colors.bgColorBubbleReciprocal)
        .cornerRadius(8)
        .overlay(
            Group {
                if MessageListHelper.shouldShowReadReceipt(message: message, isInMergedDetailView: isInMergedDetailView) {
                    let iconName = MessageListHelper.getReceiptIconName(message: message)
                    Image(iconName, bundle: AtomicXChatResources.resourceBundle)
                        .resizable()
                        .frame(width: 14, height: 14)
                        .padding(.trailing, 8)
                        .padding(.bottom, 6)
                }
            },
            alignment: .bottomTrailing
        )
        .onTapGesture {
            showDetailView = true
        }
        .sheet(isPresented: $showDetailView) {
            MergedMessageDetailView(mergedMessage: message)
                .environmentObject(themeState)
        }
    }
}

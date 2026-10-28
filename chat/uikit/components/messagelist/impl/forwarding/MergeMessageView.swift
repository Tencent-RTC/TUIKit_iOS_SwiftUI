import AtomicXCore
import SwiftUI

struct MergeMessageView: View {
    @EnvironmentObject var themeState: ThemeState
    @Environment(\.isInMergedDetailView) private var isInMergedDetailView
    @Environment(\.openMergedMessageDetail) private var openMergedMessageDetail
    let message: MessageInfo
    let conversationID: String
    var hideCardChrome: Bool = false
    @State private var showDetailView = false

    private let bubbleWidth: CGFloat = 214

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
            Text(mergedTitle)
                .font(themeState.fonts.caption1Regular)
                .foregroundColor(themeState.colors.textColorPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, CGFloat(SpacingScheme.iconIconSpacing))
                .padding(.top, CGFloat(SpacingScheme.iconIconSpacing))

            if !abstractList.isEmpty {
                VStack(alignment: .leading, spacing: CGFloat(SpacingScheme.iconTextSpacing)) {
                    ForEach(abstractList.prefix(4), id: \.self) { abstract in
                        emojiText(abstract, color: themeState.colors.textColorSecondary)
                            .font(themeState.fonts.caption3Regular)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(height: 16, alignment: .leading)
                    }
                }
                .padding(.horizontal, CGFloat(SpacingScheme.iconIconSpacing))
                .padding(.top, CGFloat(SpacingScheme.smallSpacing))
            }

            Rectangle()
                .fill(themeState.colors.strokeColorPrimary)
                .frame(height: 0.5)
                .padding(.horizontal, CGFloat(SpacingScheme.iconIconSpacing))
                .padding(.top, CGFloat(SpacingScheme.smallSpacing))

            Text(LocalizedChatString("RelayChatHistory"))
                .font(themeState.fonts.caption4Regular)
                .foregroundColor(themeState.colors.textColorSecondary)
                .padding(.horizontal, CGFloat(SpacingScheme.iconIconSpacing))
                .padding(.top, CGFloat(SpacingScheme.smallSpacing))
                .padding(.bottom, CGFloat(SpacingScheme.iconIconSpacing))
        }
        .frame(width: bubbleWidth)
        .background(hideCardChrome ? Color.clear : themeState.colors.bgColorDialog)
        .cornerRadius(CGFloat(RadiusScheme.alertRadius))
        .overlay(
            RoundedRectangle(cornerRadius: CGFloat(RadiusScheme.alertRadius))
                .stroke(hideCardChrome ? Color.clear : themeState.colors.strokeColorPrimary, lineWidth: 1)
        )
        .onTapGesture {
            if let open = openMergedMessageDetail {
                open(message)
            } else {
                showDetailView = true
            }
        }
        .sheet(isPresented: $showDetailView) {
            MergedMessageDetailView(mergedMessage: message, conversationID: conversationID, embedInNavigationView: true)
                .environmentObject(themeState)
        }
    }

    private let abstractEmojiSize: CGFloat = 14

    private func emojiText(_ string: String, color: Color) -> Text {
        var result = Text("")
        let pattern = "\\[TUIEmoji_[^\\]]+\\]"
        let regex = try? NSRegularExpression(pattern: pattern)
        let nsString = string as NSString
        let matches = regex?.matches(in: string, range: NSRange(location: 0, length: nsString.length)) ?? []
        var lastIndex = 0
        for match in matches {
            if match.range.location > lastIndex {
                result = result + Text(nsString.substring(with: NSRange(location: lastIndex, length: match.range.location - lastIndex))).foregroundColor(color)
            }
            let code = nsString.substring(with: match.range)
            if let image = emojiImage(for: code) {
                result = result + Text(Image(uiImage: image))
            } else {
                result = result + Text(code).foregroundColor(color)
            }
            lastIndex = match.range.location + match.range.length
        }
        if lastIndex < nsString.length {
            result = result + Text(nsString.substring(with: NSRange(location: lastIndex, length: nsString.length - lastIndex))).foregroundColor(color)
        }
        return result
    }

    private func emojiImage(for code: String) -> UIImage? {
        guard let faceGroup = EmojiConfig.shared.emojiGroups.first,
              let emojiData = faceGroup.emojis?.first(where: { $0.name == code }),
              let path = emojiData.path,
              let image = EmojiCache.shared.getImageFromCache(path) else { return nil }
        let size = CGSize(width: abstractEmojiSize, height: abstractEmojiSize)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
    }
}

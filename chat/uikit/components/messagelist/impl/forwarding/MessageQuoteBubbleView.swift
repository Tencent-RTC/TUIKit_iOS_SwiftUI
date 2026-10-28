import AtomicXCore
import Kingfisher
import SwiftUI
import UIKit

struct MessageQuoteThumbnail {
    let path: String
    let isVideo: Bool
}

struct MessageQuoteDisplayData {
    let senderName: String
    let contentText: String
    var thumbnail: MessageQuoteThumbnail? = nil
    var isStatusText: Bool = false
    var isPartial: Bool = false
    var shouldRenderEmoji: Bool = false
}

enum MessageQuoteDisplayResolver {
    private static let secondsPerMinute = 60

    static func resolve(quoteInfo: MessageQuoteInfo) -> MessageQuoteDisplayData {
        let senderName = resolveSenderName(quoteInfo)
        let payload = quoteInfo.messagePayload

        if quoteInfo.status == .revoked {
            return MessageQuoteDisplayData(
                senderName: senderName,
                contentText: LocalizedChatString("ReferenceOriginMessageRevoke"),
                isStatusText: true
            )
        }

        if payload == nil {
            return MessageQuoteDisplayData(
                senderName: senderName,
                contentText: "...",
                isPartial: true
            )
        }

        if quoteInfo.status == .deleted {
            return MessageQuoteDisplayData(
                senderName: senderName,
                contentText: LocalizedChatString("ReferenceOriginMessageDeleted"),
                isStatusText: true
            )
        }

        return MessageQuoteDisplayData(
            senderName: senderName,
            contentText: resolveContentText(payload!),
            thumbnail: resolveThumbnail(payload!),
            shouldRenderEmoji: isTextPayload(payload!)
        )
    }

    private static func resolveSenderName(_ quoteInfo: MessageQuoteInfo) -> String {
        let sender = quoteInfo.sender
        if let remark = sender.friendRemark, !remark.isEmpty { return remark }
        if let nameCard = sender.nameCard, !nameCard.isEmpty { return nameCard }
        if let nickname = sender.nickname, !nickname.isEmpty { return nickname }
        return sender.userID
    }

    private static func resolveContentText(_ payload: MessagePayload) -> String {
        switch payload {
        case .text(let text):
            return text.text
        case .image:
            return LocalizedChatString("MessageTypeImage")
        case .video:
            return LocalizedChatString("MessageTypeVideo")
        case .audio(let audio):
            return resolveAudioText(audio)
        case .file(let file):
            if let name = file.fileName, !name.isEmpty { return name }
            return LocalizedChatString("MessageTypeFile")
        case .face:
            return LocalizedChatString("MessageTypeAnimateEmoji")
        case .custom(let custom):
            if let desc = custom.description, !desc.isEmpty { return desc }
            return LocalizedChatString("MessageTipsUnsupportCustomMessage")
        case .merged(let merged):
            if !merged.title.isEmpty { return merged.title }
            return LocalizedChatString("MessageTypeMergedHistory")
        default:
            return LocalizedChatString("MessageTipsUnsupportCustomMessage")
        }
    }

    private static func resolveAudioText(_ payload: AudioMessagePayload) -> String {
        let voiceLabel = LocalizedChatString("MessageTypeVoice")
        let duration = payload.audioDuration
        guard duration > 0 else { return voiceLabel }
        let minutes = duration / secondsPerMinute
        let seconds = duration % secondsPerMinute
        let durationText = minutes > 0
            ? String(format: "%d:%02d\"", minutes, seconds)
            : "\(seconds)\""
        return "\(voiceLabel) \(durationText)"
    }

    private static func resolveThumbnail(_ payload: MessagePayload) -> MessageQuoteThumbnail? {
        switch payload {
        case .image(let image):
            let path = firstNonEmpty(image.thumbImagePath, image.thumbImageURL, image.originalImagePath, image.originalImageURL)
            return path.map { MessageQuoteThumbnail(path: $0, isVideo: false) }
        case .video(let video):
            let path = firstNonEmpty(video.videoSnapshotPath, video.videoSnapshotURL)
            return path.map { MessageQuoteThumbnail(path: $0, isVideo: true) }
        default:
            return nil
        }
    }

    private static func isTextPayload(_ payload: MessagePayload) -> Bool {
        if case .text = payload { return true }
        return false
    }

    private static func firstNonEmpty(_ candidates: String?...) -> String? {
        for candidate in candidates {
            if let value = candidate, !value.isEmpty { return value }
        }
        return nil
    }
}

struct MessageQuoteBubbleView: View {
    @EnvironmentObject var themeState: ThemeState
    let quoteInfo: MessageQuoteInfo
    var maxWidth: CGFloat = UIScreen.main.bounds.width * MessageQuoteBubbleView.maximumWidthRatio
    var onTap: (() -> Void)? = nil

    @State private var resolvedThumbPath: String?
    @State private var resolvedThumbImage: UIImage?
    @State private var thumbDecodeFailedPath: String?

    private static let thumbnailSize: CGFloat = 36
    private static let maximumWidthRatio: CGFloat = 0.72
    private static let horizontalPaddingEdges: CGFloat = 2

    var body: some View {
        let display = MessageQuoteDisplayResolver.resolve(quoteInfo: quoteInfo)
        let contentPadding = CGFloat(themeState.spacing.smallSpacing)
        let contentWidth = Self.measuredContentWidth(
            senderText: display.senderName.isEmpty ? "" : String(format: LocalizedChatString("QuoteSenderFormat"), display.senderName),
            contentText: display.thumbnail == nil ? measuredQuoteText(display.contentText) : nil,
            maxWidth: maxWidth,
            contentPadding: contentPadding
        )

        VStack(alignment: .leading, spacing: 0) {
            if !display.senderName.isEmpty {
                Text(String(format: LocalizedChatString("QuoteSenderFormat"), display.senderName))
                    .font(themeState.fonts.caption3Bold)
                    .foregroundColor(themeState.colors.textColorSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            if let thumbnail = display.thumbnail {
                thumbnailView(thumbnail)
                    .padding(.top, display.senderName.isEmpty ? 0 : CGFloat(SpacingScheme.smallSpacing))
            } else {
                quoteContentText(display)
                    .padding(.top, display.senderName.isEmpty ? 0 : CGFloat(SpacingScheme.iconTextSpacing))
            }
        }
        .frame(width: contentWidth, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .padding(contentPadding)
        .background(themeState.colors.bgColorBubbleReciprocal)
        .cornerRadius(CGFloat(themeState.radius.smallRadius))
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
    }

    static func measuredContentWidth(senderText: String, contentText: NSAttributedString?, maxWidth: CGFloat, contentPadding: CGFloat) -> CGFloat {
        let availableWidth = max(0, maxWidth - contentPadding * horizontalPaddingEdges)
        let senderWidth = ceil((senderText as NSString).size(withAttributes: [.font: UIKitFontScheme.caption3Bold]).width)
        let contentWidth = contentText.map { ceil($0.size().width) } ?? thumbnailSize
        return min(availableWidth, max(senderWidth, contentWidth))
    }

    private func measuredQuoteText(_ string: String) -> NSAttributedString {
        let attributedText = NSMutableAttributedString(string: string, attributes: [.font: UIKitFontScheme.caption3Regular])
        let regex = try? NSRegularExpression(pattern: "\\[TUIEmoji_[^\\]]+\\]")
        let range = NSRange(location: 0, length: attributedText.length)
        for match in (regex?.matches(in: string, range: range) ?? []).reversed() {
            let code = (string as NSString).substring(with: match.range)
            guard let image = quoteEmojiImage(for: code) else { continue }
            let attachment = NSTextAttachment()
            attachment.image = image
            attachment.bounds = CGRect(origin: .zero, size: CGSize(width: quoteEmojiSize, height: quoteEmojiSize))
            attributedText.replaceCharacters(in: match.range, with: NSAttributedString(attachment: attachment))
        }
        return attributedText
    }

    @ViewBuilder
    private func quoteContentText(_ display: MessageQuoteDisplayData) -> some View {
        quoteEmojiText(display.contentText)
            .font(themeState.fonts.caption3Regular)
            .lineLimit(2)
            .truncationMode(.tail)
    }

    private let quoteEmojiSize: CGFloat = 18

    private func quoteEmojiText(_ string: String) -> Text {
        var result = Text("")
        let pattern = "\\[TUIEmoji_[^\\]]+\\]"
        let regex = try? NSRegularExpression(pattern: pattern)
        let nsString = string as NSString
        let matches = regex?.matches(in: string, range: NSRange(location: 0, length: nsString.length)) ?? []
        var lastIndex = 0
        for match in matches {
            if match.range.location > lastIndex {
                result = result + Text(nsString.substring(with: NSRange(location: lastIndex, length: match.range.location - lastIndex)))
            }
            let code = nsString.substring(with: match.range)
            if let image = quoteEmojiImage(for: code) {
                result = result + Text(Image(uiImage: image))
            } else {
                result = result + Text(code)
            }
            lastIndex = match.range.location + match.range.length
        }
        if lastIndex < nsString.length {
            result = result + Text(nsString.substring(with: NSRange(location: lastIndex, length: nsString.length - lastIndex)))
        }
        return result.foregroundColor(themeState.colors.textColorSecondary)
    }

    private func quoteEmojiImage(for code: String) -> UIImage? {
        guard let faceGroup = EmojiConfig.shared.emojiGroups.first,
              let emojiData = faceGroup.emojis?.first(where: { $0.name == code }),
              let path = emojiData.path,
              let image = EmojiCache.shared.getImageFromCache(path) else { return nil }
        let size = CGSize(width: quoteEmojiSize, height: quoteEmojiSize)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
    }

    @ViewBuilder
    private func thumbnailView(_ thumbnail: MessageQuoteThumbnail) -> some View {
        let cached: UIImage? = {
            guard !thumbnail.path.hasPrefix("http"), !thumbnail.path.isEmpty else { return nil }
            if resolvedThumbPath == thumbnail.path, let resolvedThumbImage { return resolvedThumbImage }
            return MediaThumbnailCache.shared.cachedImage(for: thumbnail.path)
        }()
        ZStack {
            if let image = cached {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if !thumbnail.path.hasPrefix("http"),
                      FileManager.default.fileExists(atPath: thumbnail.path),
                      thumbDecodeFailedPath != thumbnail.path
            {
                Color.clear
                    .task(id: thumbnail.path) {
                        let decoded = await MediaThumbnailCache.shared.image(for: thumbnail.path, maxPixelSize: 216)
                        guard !Task.isCancelled else { return }
                        if let decoded {
                            resolvedThumbPath = thumbnail.path
                            resolvedThumbImage = decoded
                        } else {
                            thumbDecodeFailedPath = thumbnail.path
                        }
                    }
            } else if let url = URL(string: thumbnail.path) {
                KFImage(url)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.clear
            }
            if thumbnail.isVideo {
                Text("▶")
                    .font(themeState.fonts.caption1Regular)
                    .foregroundColor(themeState.colors.textColorAntiPrimary)
            }
        }
        .frame(width: Self.thumbnailSize, height: Self.thumbnailSize)
        .background(themeState.colors.bgColorBubbleReciprocal)
        .cornerRadius(CGFloat(themeState.radius.tipsRadius))
        .clipped()
    }
}


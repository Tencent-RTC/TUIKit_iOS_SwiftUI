import AtomicXCore
import SwiftUI

struct VideoMessageView: View {
    @EnvironmentObject var themeState: ThemeState
    @Environment(\.isInMergedDetailView) private var isInMergedDetailView
    let payload: VideoMessagePayload
    let message: MessageInfo
    let messageListStore: MessageListStore
    let onVideoTap: () -> Void

    private var sendProgress: Double {
        Double(message.uploadMediaProgress) / 100.0
    }

    private var isSending: Bool {
        message.status == .sending && message.isSentBySelf && message.uploadMediaProgress < 100
    }

    private var isCompressPhase: Bool {
        MessageListPlaceholderStore.shared.placeholdersByConversation.values
            .contains { $0.contains { $0.msgID == message.msgID } }
    }

    private var currentPayload: VideoMessagePayload {
        if let updatedMessage = messageListStore.state.value.messageList.first(where: { $0.msgID == message.msgID }),
           case .video(let payload) = updatedMessage.messagePayload {
            return payload
        }
        return payload
    }

    private static let maxBubbleSize: CGFloat = 200
    private static let minBubbleSize: CGFloat = 80

    private var displaySize: CGSize {
        let width = currentPayload.videoSnapshotWidth
        let height = currentPayload.videoSnapshotHeight
        guard width > 0, height > 0 else {
            return CGSize(width: Self.maxBubbleSize, height: Self.maxBubbleSize)
        }
        let ratio = CGFloat(width) / CGFloat(height)
        let unscaledWidth: CGFloat
        let unscaledHeight: CGFloat
        if ratio > 1 {
            unscaledWidth = Self.maxBubbleSize
            unscaledHeight = Self.maxBubbleSize / ratio
        } else {
            unscaledHeight = Self.maxBubbleSize
            unscaledWidth = Self.maxBubbleSize * ratio
        }
        return CGSize(
            width: min(max(unscaledWidth, Self.minBubbleSize), Self.maxBubbleSize),
            height: min(max(unscaledHeight, Self.minBubbleSize), Self.maxBubbleSize)
        )
    }

    var body: some View {
        ZStack(alignment: .center) {
            snapshotImageView

            if isSending {
                Rectangle()
                    .fill(Colors.Black1.opacity(0.5))
                    .frame(width: displaySize.width, height: displaySize.height)
                    .cornerRadius(CGFloat(RadiusScheme.largeRadius))

                VStack(spacing: CGFloat(SpacingScheme.smallSpacing)) {
                    ZStack {
                        Circle()
                            .stroke(Colors.White1.opacity(0.3), lineWidth: 4)
                            .frame(width: 60, height: 60)

                        Circle()
                            .trim(from: 0, to: CGFloat(sendProgress))
                            .stroke(Colors.White1, lineWidth: 4)
                            .frame(width: 60, height: 60)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 0.2), value: sendProgress)

                        Text("\(Int(sendProgress * 100))%")
                            .font(FontScheme.caption2Medium)
                            .foregroundColor(Colors.White1)
                    }

                    Text(LocalizedChatString(isCompressPhase ? "VideoTranscoding" : "Sending"))
                        .font(FontScheme.caption3Regular)
                        .foregroundColor(Colors.White1)
                }
            } else {
                Button(action: {
                    onVideoTap()
                }) {
                    if let playImage = AtomicXChatResources.image(named: "message_video_play_icon") {
                        Image(uiImage: playImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 44, height: 44)
                    } else {
                        Image(systemName: "play.fill")
                            .font(FontScheme.title2Regular)
                            .foregroundColor(Colors.White1)
                            .frame(width: 44, height: 44)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }

            if currentPayload.videoDuration > 0 && !isSending {
                Text(formatDuration(currentPayload.videoDuration))
                    .font(FontScheme.caption3Regular)
                    .foregroundColor(Colors.White1)
                    .padding(.horizontal, CGFloat(SpacingScheme.smallSpacing))
                    .padding(.vertical, CGFloat(SpacingScheme.iconTextSpacing))
                    .background(Colors.Black1.opacity(0.6))
                    .cornerRadius(CGFloat(RadiusScheme.tipsRadius))
                    .padding(CGFloat(SpacingScheme.smallSpacing))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
        .frame(width: displaySize.width, height: displaySize.height)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isSending else { return }
            DispatchQueue.main.async {
                onVideoTap()
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }

    @State private var resolvedSnapshotPath: String?
    @State private var resolvedSnapshot: UIImage?
    @State private var snapshotDecodeFailedPath: String?

    @ViewBuilder
    private var snapshotImageView: some View {
        let localPath = currentPayload.videoSnapshotPath
        let cachedImage: UIImage? = {
            guard let path = localPath, !path.isEmpty else { return nil }
            if resolvedSnapshotPath == path, let resolvedSnapshot { return resolvedSnapshot }
            return MediaThumbnailCache.shared.cachedImage(for: path)
        }()

        if let image = cachedImage {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: displaySize.width, height: displaySize.height)
                .cornerRadius(CGFloat(RadiusScheme.largeRadius))
                .clipped()
        } else if let snapshotPath = localPath,
                  !snapshotPath.isEmpty,
                  FileManager.default.fileExists(atPath: snapshotPath),
                  snapshotDecodeFailedPath != snapshotPath
        {
            snapshotPlaceholder
                .task(id: snapshotPath) {
                    let decoded = await MediaThumbnailCache.shared.image(for: snapshotPath, maxPixelSize: 600)
                    guard !Task.isCancelled else { return }
                    if let decoded {
                        resolvedSnapshotPath = snapshotPath
                        resolvedSnapshot = decoded
                    } else {
                        snapshotDecodeFailedPath = snapshotPath
                    }
                }
        } else if let urlString = currentPayload.videoSnapshotURL,
                  !urlString.isEmpty,
                  let url = URL(string: urlString)
        {
            CompatibleKFImage(
                url: url,
                width: displaySize.width,
                height: displaySize.height,
                contentMode: .fill,
                fallback: { AnyView(snapshotPlaceholder) }
            )
            .frame(width: displaySize.width, height: displaySize.height)
            .cornerRadius(CGFloat(RadiusScheme.largeRadius))
            .clipped()
        } else {
            snapshotPlaceholder
                .onAppear {
                    MessageActionStore.create(message: message).downloadMedia(quality: .thumbnail) { _ in }
                }
        }
    }

    private var snapshotPlaceholder: some View {
        ZStack {
            Rectangle()
                .fill(themeState.colors.bgColorBubbleReciprocal)
                .frame(width: displaySize.width, height: displaySize.height)
                .cornerRadius(CGFloat(RadiusScheme.largeRadius))
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}

import AtomicXCore
import SwiftUI

struct ImageMessageView: View {
    @EnvironmentObject var themeState: ThemeState
    @Environment(\.isInMergedDetailView) private var isInMergedDetailView
    @State private var isImageLoading = false
    let payload: ImageMessagePayload
    let message: MessageInfo
    let messageListStore: MessageListStore
    let onImageTap: () -> Void

    private var currentPayload: ImageMessagePayload {
        if let updatedMessage = messageListStore.state.value.messageList.first(where: { $0.msgID == message.msgID }),
           case .image(let payload) = updatedMessage.messagePayload {
            return payload
        }
        return payload
    }

    var body: some View {
        ZStack {
            thumbnailView
        }
        .contentShape(Rectangle())
        .onTapGesture(
            perform: {
                DispatchQueue.main.async {
                    onImageTap()
                }
            }
        )
        .buttonStyle(ScaleButtonStyle())
    }

    @State private var resolvedPath: String?
    @State private var resolvedImage: UIImage?
    @State private var decodeFailedPath: String?

    private static let maxBubbleWidth: CGFloat = 200
    private static let maxBubbleHeight: CGFloat = 300
    private static let minBubbleSide: CGFloat = 80

    private var displaySize: CGSize {
        let width = currentPayload.originalImageWidth
        let height = currentPayload.originalImageHeight
        guard width > 0, height > 0 else {
            return CGSize(width: Self.maxBubbleWidth, height: 150)
        }
        let scale = min(Self.maxBubbleWidth / CGFloat(width), Self.maxBubbleHeight / CGFloat(height))
        return CGSize(
            width: min(max(CGFloat(width) * scale, Self.minBubbleSide), Self.maxBubbleWidth),
            height: min(max(CGFloat(height) * scale, Self.minBubbleSide), Self.maxBubbleHeight)
        )
    }

    @ViewBuilder
    private var thumbnailView: some View {
        let localPath = currentPayload.largeImagePath ?? currentPayload.originalImagePath
        let cachedImage: UIImage? = {
            guard let path = localPath, !path.isEmpty else { return nil }
            if resolvedPath == path, let resolvedImage { return resolvedImage }
            return MediaThumbnailCache.shared.cachedImage(for: path)
        }()

        Group {
            if let image = cachedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if let imagePath = localPath,
                      !imagePath.isEmpty,
                      FileManager.default.fileExists(atPath: imagePath),
                      decodeFailedPath != imagePath
            {
                thumbnailPlaceholder
                    .task(id: imagePath) {
                        let decoded = await MediaThumbnailCache.shared.image(for: imagePath, maxPixelSize: 900)
                        guard !Task.isCancelled else { return }
                        if let decoded {
                            resolvedPath = imagePath
                            resolvedImage = decoded
                        } else {
                            decodeFailedPath = imagePath
                        }
                    }
            } else if let urlString = currentPayload.largeImageURL ?? currentPayload.originalImageURL ?? currentPayload.thumbImageURL,
                      !urlString.isEmpty,
                      let url = URL(string: urlString)
            {
                CompatibleKFImage(
                    url: url,
                    width: displaySize.width,
                    height: displaySize.height,
                    contentMode: .fill,
                    fallback: { AnyView(thumbnailPlaceholder) }
                )
            } else {
                thumbnailPlaceholder
                    .onAppear {
                        isImageLoading = true
                        MessageActionStore.create(message: message).downloadMedia(quality: .standard) { _ in
                            isImageLoading = false
                        }
                    }
            }
        }
        .frame(width: displaySize.width, height: displaySize.height)
        .cornerRadius(CGFloat(RadiusScheme.largeRadius))
        .clipped()
    }

    private var thumbnailPlaceholder: some View {
        ZStack {
            Rectangle()
                .fill(themeState.colors.bgColorBubbleReciprocal)
            if isImageLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            } else {
                Image(systemName: "photo")
                    .font(FontScheme.title1Regular)
                    .foregroundColor(themeState.colors.textColorSecondary)
            }
        }
    }
}

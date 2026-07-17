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
        .contentShape(Rectangle())
        .onTapGesture(
            perform: {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                DispatchQueue.main.async {
                    onImageTap()
                }
            }
        )
        .buttonStyle(ScaleButtonStyle())
    }

    @ViewBuilder
    private var thumbnailView: some View {
        // Local path is preferred so we never re-fetch when the SDK has already cached the
        // file. Fall back to the remote URL (already populated by ChatUtil for images), which
        // keeps merged-message previews working without depending on the store reactive pipe.
        // If neither is available we render a placeholder and trigger a one-shot download.
        if let imagePath = currentPayload.largeImagePath,
           !imagePath.isEmpty,
           FileManager.default.fileExists(atPath: imagePath),
           let image = UIImage(contentsOfFile: imagePath)
        {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: 200, maxHeight: 300)
                .cornerRadius(16)
                .clipped()
        } else if let urlString = currentPayload.largeImageURL ?? currentPayload.originalImageURL ?? currentPayload.thumbImageURL,
                  !urlString.isEmpty,
                  let url = URL(string: urlString)
        {
            CompatibleKFImage(
                url: url,
                width: 200,
                height: 300,
                contentMode: .fill,
                fallback: { AnyView(thumbnailPlaceholder) }
            )
            .frame(maxWidth: 200, maxHeight: 300)
            .cornerRadius(16)
            .clipped()
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

    private var thumbnailPlaceholder: some View {
        ZStack {
            Rectangle()
                .fill(themeState.colors.bgColorBubbleReciprocal)
                .frame(width: 200, height: 150)
                .cornerRadius(16)
            if isImageLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 40))
                    .foregroundColor(themeState.colors.textColorSecondary)
            }
        }
    }
}

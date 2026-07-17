import AtomicXCore
import SwiftUI

struct VideoMessageView: View {
    @EnvironmentObject var themeState: ThemeState
    @Environment(\.isInMergedDetailView) private var isInMergedDetailView
    let payload: VideoMessagePayload
    let message: MessageInfo
    let messageListStore: MessageListStore
    let onVideoTap: () -> Void
    let onPlayVideo: () -> Void
    
    private var sendProgress: Double {
        Double(message.uploadMediaProgress) / 100.0
    }
    
    private var isSending: Bool {
        message.status == .sending && message.isSentBySelf && message.uploadMediaProgress < 100
    }

    private var currentPayload: VideoMessagePayload {
        if let updatedMessage = messageListStore.state.value.messageList.first(where: { $0.msgID == message.msgID }),
           case .video(let payload) = updatedMessage.messagePayload {
            return payload
        }
        return payload
    }

    var body: some View {
        ZStack(alignment: .center) {
            snapshotImageView
            
            if isSending {
                Rectangle()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: 200, height: 300)
                    .cornerRadius(16)
                
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 4)
                            .frame(width: 60, height: 60)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(sendProgress))
                            .stroke(Color.white, lineWidth: 4)
                            .frame(width: 60, height: 60)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 0.2), value: sendProgress)
                        
                        Text("\(Int(sendProgress * 100))%")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                    }
                    
                    Text(LocalizedChatString("Sending"))
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                }
            } else {
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    onPlayVideo()
                }) {
                    ZStack {
                        Image(systemName: "play.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                    }
                    .frame(width: 44, height: 44)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            if currentPayload.videoDuration > 0 && !isSending {
                Text(formatDuration(currentPayload.videoDuration))
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(4)
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
        .overlay(
            Group {
                if MessageListHelper.shouldShowReadReceipt(message: message, isInMergedDetailView: isInMergedDetailView) {
                    let iconName = MessageListHelper.getReceiptIconName(message: message)
                    Image(iconName, bundle: AtomicXChatResources.resourceBundle)
                        .resizable()
                        .frame(width: 14, height: 14)
                        .padding(.trailing, 60)
                        .padding(.bottom, 6)
                }
            },
            alignment: .bottomTrailing
        )
        .frame(width: 200)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isSending else { return }
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            DispatchQueue.main.async {
                onPlayVideo()
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }

    @ViewBuilder
    private var snapshotImageView: some View {
        // Prefer a local snapshot file so we never hit the network when the SDK has already
        // cached it. Otherwise fall back to the remote snapshot URL (filled in by
        // ChatUtil.convertToMessagePayload for normal messages and by
        // MessageActionStoreImpl.fillMediaURLsForMergedMessages for merged sub-messages).
        // The placeholder still triggers a thumbnail download so that subsequent renders pick
        // up the local file via the messageListStore reactive path (normal chat list flow).
        if let snapshotPath = currentPayload.videoSnapshotPath,
           !snapshotPath.isEmpty,
           FileManager.default.fileExists(atPath: snapshotPath),
           let image = UIImage(contentsOfFile: snapshotPath)
        {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 200, height: 300)
                .cornerRadius(16)
                .clipped()
        } else if let urlString = currentPayload.videoSnapshotURL,
                  !urlString.isEmpty,
                  let url = URL(string: urlString)
        {
            CompatibleKFImage(
                url: url,
                width: 200,
                height: 300,
                contentMode: .fill,
                fallback: { AnyView(snapshotPlaceholder) }
            )
            .frame(width: 200, height: 300)
            .cornerRadius(16)
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
                .frame(width: 200, height: 150)
                .cornerRadius(16)
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

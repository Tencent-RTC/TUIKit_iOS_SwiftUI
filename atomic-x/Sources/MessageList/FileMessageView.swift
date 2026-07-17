import AtomicXCore
import SwiftUI

struct FileMessageView: View {
    @EnvironmentObject var themeState: ThemeState
    let payload: FileMessagePayload
    let message: MessageInfo
    let messageListStore: MessageListStore
    let isLeft: Bool
    let isSelf: Bool
    let shouldHighlight: Bool

    @State private var downloadProgress: Int = 0
    @State private var isDownloading: Bool = false

    private var currentMessage: MessageInfo {
        messageListStore.state.value.messageList.first(where: { $0.msgID == message.msgID }) ?? message
    }

    private var currentPayload: FileMessagePayload {
        if case .file(let payload) = currentMessage.messagePayload {
            return payload
        }
        return payload
    }

    private var isDownloaded: Bool {
        currentPayload.filePath != nil
    }

    private var showsActiveProgress: Bool {
        isDownloading && !isDownloaded && (1 ..< 100).contains(downloadProgress)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            if !isLeft && !isDownloaded {
                downloadAccessory
            }

            // File bubble
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: FilePreviewManager.fileTypeIcon(for: currentPayload.fileName ?? "unknown"))
                        .font(.system(size: 30))
                        .foregroundColor(isLeft ? themeState.colors.textColorPrimary : themeState.colors.buttonColorPrimaryDefault)
                        .frame(width: 40, height: 40)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(currentPayload.fileName ?? LocalizedChatString("UnknownFile"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(isLeft ? themeState.colors.textColorPrimary : themeState.colors.textColorPrimary)
                            .lineLimit(1)
                        HStack(spacing: 6) {
                            Text(FilePreviewManager.formatFileSize(Int64(currentPayload.fileSize)))
                                .font(.system(size: 12))
                                .foregroundColor(themeState.colors.textColorSecondary)
                            if showsActiveProgress {
                                Text("· \(downloadProgress)%")
                                    .font(.system(size: 12))
                                    .foregroundColor(themeState.colors.textColorSecondary)
                            }
                        }
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: 250, alignment: .leading)
            .bubbleBackground(isSelf: isSelf, isLeft: isLeft, shouldHighlight: shouldHighlight, message: message)
            .contentShape(Rectangle())
            .onTapGesture {
                if let filePath = currentPayload.filePath {
                    FilePreviewManager.openFile(at: filePath)
                }
            }

            if isLeft && !isDownloaded {
                downloadAccessory
            }
        }
        .onAppear {
            // Re-sync local state with the store, in case the user came back to the chat
            // while a download was still running.
            let progress = currentMessage.downloadMediaProgress
            if (1 ..< 100).contains(progress) {
                downloadProgress = progress
                isDownloading = true
            }
        }
        .onReceive(messageListStore.state.subscribe(StatePublisherSelector(keyPath: \MessageListState.messageList))) { messageList in
            guard let updated = messageList.first(where: { $0.msgID == message.msgID }) else { return }
            let progress = updated.downloadMediaProgress
            if progress != downloadProgress {
                downloadProgress = progress
            }
            if progress >= 100 || updated.downloadMediaProgress == 0 {
                isDownloading = false
            } else if (1 ..< 100).contains(progress) {
                isDownloading = true
            }
        }
    }

    @ViewBuilder
    private var downloadAccessory: some View {
        if showsActiveProgress {
            ProgressView(value: Double(downloadProgress), total: 100)
                .progressViewStyle(CircularProgressViewStyle(tint: themeState.colors.buttonColorPrimaryDefault))
                .scaleEffect(0.8)
        } else {
            downloadButton
        }
    }

    private var downloadButton: some View {
        Button(action: {
            downloadFile()
        }) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(themeState.colors.buttonColorPrimaryDefault)
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(Rectangle())
    }

    private func downloadFile() {
        isDownloading = true
        downloadProgress = max(downloadProgress, 1)
        MessageActionStore.create(message: message).downloadMedia(quality: nil) { result in
            DispatchQueue.main.async {
                isDownloading = false
                switch result {
                case .success:
                    downloadProgress = 100
                case .failure(let error):
                    downloadProgress = 0
                    print("\(LocalizedChatString("FileDownloadFailed")): \(error.code), \(error.message)")
                }
            }
        }
    }
}

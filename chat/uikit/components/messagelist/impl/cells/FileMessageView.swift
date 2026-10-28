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

    private static let bubbleWidth: CGFloat = 237
    private static let bubblePadding = CGFloat(SpacingScheme.iconIconSpacing)
    private static let iconTextGap = CGFloat(SpacingScheme.smallSpacing)
    private static let iconSize: CGFloat = 40
    private static let footerTopMargin = CGFloat(SpacingScheme.smallSpacing)
    private static let footerItemGap = CGFloat(SpacingScheme.smallSpacing)
    private static let downloadButtonSize: CGFloat = 20

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
        !(currentPayload.filePath?.isEmpty ?? true)
    }

    private var effectiveProgress: Int {
        let messageProgress = currentMessage.downloadMediaProgress
        if (1 ..< 100).contains(messageProgress) { return messageProgress }
        return downloadProgress
    }

    private var showsActiveProgress: Bool {
        !isDownloaded && (1 ..< 100).contains(effectiveProgress)
    }

    var body: some View {
        fileBubble
            .onAppear {
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

    private var fileBubble: some View {
        HStack(alignment: .top, spacing: Self.iconTextGap) {
            Image(FilePreviewManager.fileTypeIcon(for: currentPayload.fileName ?? ""), bundle: AtomicXChatResources.resourceBundle)
                .renderingMode(.original)
                .resizable()
                .frame(width: Self.iconSize, height: Self.iconSize)
            VStack(alignment: .leading, spacing: Self.footerTopMargin) {
                Text(currentPayload.fileName ?? LocalizedChatString("UnknownFile"))
                    .font(themeState.fonts.caption2Regular)
                    .foregroundColor(themeState.colors.textColorPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: Self.footerItemGap) {
                    Text(FilePreviewManager.formatFileSize(Int64(currentPayload.fileSize)))
                        .font(themeState.fonts.caption3Regular)
                        .foregroundColor(themeState.colors.textColorSecondary)
                    Spacer(minLength: 0)
                    if showsActiveProgress {
                        Text("\(effectiveProgress)%")
                            .font(themeState.fonts.caption3Regular)
                            .foregroundColor(themeState.colors.textColorSecondary)
                    }
                    if !isDownloaded && !showsActiveProgress {
                        downloadButton
                    }
                }
            }
        }
        .padding(Self.bubblePadding)
        .frame(width: Self.bubbleWidth, alignment: .leading)
        .bubbleBackground(isSelf: isSelf, isLeft: isLeft, shouldHighlight: shouldHighlight, message: message)
        .contentShape(Rectangle())
        .onTapGesture {
            if let filePath = currentPayload.filePath, !filePath.isEmpty,
               FileManager.default.fileExists(atPath: filePath) {
                FilePreviewManager.openFile(at: filePath)
            } else {
                downloadFile()
            }
        }
    }

    private var downloadButton: some View {
        Button(action: {
            downloadFile()
        }) {
            Image("message_file_download", bundle: AtomicXChatResources.resourceBundle)
                .renderingMode(.original)
                .resizable()
                .frame(width: Self.downloadButtonSize, height: Self.downloadButtonSize)
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

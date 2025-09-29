import AtomicXCore
import SwiftUI

struct FileMessageView: View {
    @EnvironmentObject var themeState: ThemeState
    let messageBody: MessageBody
    let message: MessageInfo
    let messageListStore: MessageListStore
    let isLeft: Bool
    let isSelf: Bool
    let shouldHighlight: Bool

    var body: some View {
        VStack(alignment: isLeft ? .trailing : .leading, spacing: 4) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: FilePreviewManager.fileTypeIcon(for: messageBody.fileName ?? "unknown"))
                        .font(.system(size: 30))
                        .foregroundColor(isLeft ? themeState.colors.textColorPrimary : themeState.colors.buttonColorPrimaryDefault)
                        .frame(width: 40, height: 40)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(messageBody.fileName ?? LocalizedChatString("UnknownFile"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(isLeft ? themeState.colors.textColorPrimary : themeState.colors.textColorPrimary)
                            .lineLimit(1)
                        Text(FilePreviewManager.formatFileSize(Int64(messageBody.fileSize)))
                            .font(.system(size: 12))
                            .foregroundColor(isLeft ? themeState.colors.textColorSecondary : themeState.colors.textColorSecondary)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: 250, alignment: .leading)
            .bubbleBackground(isSelf: isSelf, isLeft: isLeft, shouldHighlight: shouldHighlight)
            .contentShape(Rectangle())
            .onTapGesture {
                if let filePath = messageBody.filePath {
                    FilePreviewManager.openFile(at: filePath)
                }
            }
            if messageBody.filePath == nil {
                Button(action: {
                    downloadFile(messageBody)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 20))
                        Text(LocalizedChatString("Download"))
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(themeState.colors.buttonColorPrimaryDefault.opacity(0.1))
                    .foregroundColor(themeState.colors.buttonColorPrimaryDefault)
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
                .contentShape(Rectangle())
                .padding(.leading, isSelf ? 0 : 8)
                .padding(.trailing, isSelf ? 8 : 0)
            }
        }
    }

    private func downloadFile(_ messageBody: MessageBody) {
        messageListStore.downloadMessageResource(message, resourceType: .file) { result in
            switch result {
            case .success:
                if let filePath = messageBody.filePath {
                    FilePreviewManager.openFile(at: filePath)
                }

            case .failure(let error):
                print("\(LocalizedChatString("FileDownloadFailed")): \(error.code), \(error.message)")
            }
        }
    }
}

import AtomicXCore
import SwiftUI

struct VideoMessageView: View {
    @EnvironmentObject var themeState: ThemeState
    let messageBody: MessageBody
    let message: MessageInfo
    let messageListStore: MessageListStore
    let onVideoTap: () -> Void
    let onPlayVideo: () -> Void

    var body: some View {
        ZStack(alignment: .center) {
            if let snapshotPath = messageBody.videoSnapshotPath {
                Image(uiImage: UIImage(contentsOfFile: snapshotPath) ?? UIImage())
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 200, height: 300)
                    .cornerRadius(16)
                    .clipped()
            } else {
                ZStack {
                    Rectangle()
                        .fill(themeState.colors.bgColorBubbleReciprocal)
                        .frame(width: 200, height: 150)
                        .cornerRadius(16)
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .onAppear {
                            messageListStore.downloadMessageResource(message, resourceType: .videoSnapshot) { _ in }
                        }
                }
            }
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
            if messageBody.videoDuration > 0 {
                Text(formatDuration(messageBody.videoDuration))
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
        .frame(width: 200)
        .contentShape(Rectangle())
        .onTapGesture {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            DispatchQueue.main.async {
                onVideoTap()
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}

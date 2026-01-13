import AtomicXCore
import SwiftUI

struct VideoMessageView: View {
    @EnvironmentObject var themeState: ThemeState
    @Environment(\.isInMergedDetailView) private var isInMergedDetailView
    let messageBody: MessageBody
    let message: MessageInfo
    let messageListStore: MessageListStore
    let onVideoTap: () -> Void
    let onPlayVideo: () -> Void
    
    private var sendProgress: Double {
        Double(message.progress) / 100.0
    }
    
    private var isSending: Bool {
        message.status == .sending && message.isSelf && message.progress < 100
    }

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
            
            if messageBody.videoDuration > 0 && !isSending {
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

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}

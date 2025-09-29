import AtomicXCore
import SwiftUI

struct ImageMessageView: View {
    @EnvironmentObject var themeState: ThemeState
    @State private var isImageLoading = false
    let messageBody: MessageBody
    let message: MessageInfo
    let messageListStore: MessageListStore
    let onImageTap: () -> Void

    var body: some View {
        ZStack {
            if let imagePath = messageBody.largeImagePath, let image = UIImage(contentsOfFile: imagePath) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: 200, maxHeight: 300)
                    .cornerRadius(16)
                    .clipped()
            } else {
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
                .onAppear {
                    isImageLoading = true
                    messageListStore.downloadMessageResource(message, resourceType: .largeImage, completion: { result in
                        switch result {
                        case .success:
                            isImageLoading = false
                        case .failure(let error):
                            isImageLoading = false
                        }
                    })
                }
            }
        }
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
}

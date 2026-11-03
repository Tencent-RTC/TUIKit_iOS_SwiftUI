import AVFoundation
import SwiftUI

struct VideoRecorderPreviewView: View {
    private static let sendButtonSize = CGSize(width: 72, height: 34)

    private static let sendTrailingInset: CGFloat = 20

    private static let sendBottomInset: CGFloat = 25

    private static let sendCornerRadius: CGFloat = 5

    private static let cancelButtonSize: CGFloat = 24

    private static let cancelTopInset: CGFloat = 10

    private static let cancelLeadingInset: CGFloat = 15

    private static let bottomBackgroundHeight: CGFloat = 100

    private static let bottomBackgroundCornerRadius: CGFloat = 8

    private static let bottomBackgroundOpacity: Double = 0.05

    static let edgeWidth: CGFloat = 20

    static let dragMinimumDistance: CGFloat = 10

    private static let quitProgressThreshold: CGFloat = 0.5

    private static let quitAnimationDuration: TimeInterval = 0.3

    let player: AVPlayer
    let sendColor: Color
    let safeAreaInsets: EdgeInsets
    let onSend: () -> Void
    let onCancel: () -> Void

    @Environment(\.layoutDirection) private var layoutDirection

    @State private var isOperationVisible = true

    @State private var offsetX: CGFloat = 0

    @State private var isEdgeDragging = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                VideoRecorderPlayerView(player: player)
                if isOperationVisible {
                    operations
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .contentShape(Rectangle())
            .onTapGesture {
                isOperationVisible.toggle()
            }
            .offset(x: offsetX)
            .simultaneousGesture(edgeSwipeGesture(width: geometry.size.width))
        }
    }

    private var operations: some View {
        ZStack {
            Color.black
                .opacity(Self.bottomBackgroundOpacity)
                .frame(height: Self.bottomBackgroundHeight)
                .cornerRadius(Self.bottomBackgroundCornerRadius)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

            Button(action: onSend) {
                Text(LocalizedChatString("send"))
                    .foregroundColor(.white)
                    .frame(width: Self.sendButtonSize.width, height: Self.sendButtonSize.height)
                    .background(sendColor)
                    .cornerRadius(Self.sendCornerRadius)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.trailing, Self.sendTrailingInset)
            .padding(.bottom, Self.sendBottomInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)

            Button(action: onCancel) {
                Image("return_arrow", bundle: AtomicXChatResources.resourceBundle)
                    .resizable()
                    .frame(width: Self.cancelButtonSize, height: Self.cancelButtonSize)
                    .scaleEffect(x: layoutDirection == .rightToLeft ? -1 : 1, y: 1)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.top, safeAreaInsets.top + Self.cancelTopInset)
            .padding(.leading, safeAreaInsets.leading + Self.cancelLeadingInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func edgeSwipeGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: Self.dragMinimumDistance, coordinateSpace: .global)
            .onChanged { value in
                if !isEdgeDragging {
                    guard value.startLocation.x <= Self.edgeWidth, value.translation.width > 0 else { return }
                    isEdgeDragging = true
                }
                offsetX = min(width, max(0, abs(value.translation.width)))
            }
            .onEnded { value in
                guard isEdgeDragging else { return }
                isEdgeDragging = false
                let progress = abs(value.translation.width) / max(width, 1)
                let predictedProgress = abs(value.predictedEndTranslation.width) / max(width, 1)
                if progress > Self.quitProgressThreshold || predictedProgress > 1 {
                    withAnimation(.easeInOut(duration: Self.quitAnimationDuration)) {
                        offsetX = width
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + Self.quitAnimationDuration) {
                        offsetX = 0
                        onCancel()
                    }
                } else {
                    withAnimation(.easeInOut(duration: Self.quitAnimationDuration)) {
                        offsetX = 0
                    }
                }
            }
    }
}

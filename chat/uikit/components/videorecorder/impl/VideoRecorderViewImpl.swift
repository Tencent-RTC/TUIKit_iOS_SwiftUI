import SwiftUI
import UIKit

struct VideoRecorderViewImpl: View {
    private static let defaultThemeColor = Color(hexValue: 0xFF147AFF)

    private static let edgeExitProgressThreshold: CGFloat = 0.5

    let primaryColor: String?
    let onVideoCaptured: (String?, Int, String?) -> Void
    let onPhotoCaptured: (String?) -> Void

    @Environment(\.presentationMode) private var presentationMode

    @StateObject private var model: VideoRecorderModel

    init(config: VideoRecorderConfig?,
         primaryColor: String?,
         onVideoCaptured: @escaping (String?, Int, String?) -> Void,
         onPhotoCaptured: @escaping (String?) -> Void) {
        self.primaryColor = primaryColor
        self.onVideoCaptured = onVideoCaptured
        self.onPhotoCaptured = onPhotoCaptured
        _model = StateObject(wrappedValue: VideoRecorderModel(settings: VideoRecorderSettings(config: config)))
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width

            ZStack(alignment: .top) {
                Color.black

                VideoRecorderCameraPreview(onCreate: model.attachPreviewView)
                    .frame(width: width, height: width * VideoRecorderControlView.previewAspectRatio)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                if isCapturing {
                    VideoRecorderControlView(model: model, themeColor: themeColor, safeAreaInsets: geometry.safeAreaInsets)
                }

                if let player = model.previewPlayer {
                    VideoRecorderPreviewView(
                        player: player,
                        sendColor: themeColor,
                        safeAreaInsets: geometry.safeAreaInsets,
                        onSend: model.acceptPreview,
                        onCancel: model.cancelPreview
                    )
                }

                if let photo = model.editingPhoto {
                    VideoRecorderPhotoEditView(
                        image: photo.image,
                        onConfirm: model.confirmEditing,
                        onCancel: model.cancelEditing
                    )
                    .id(photo.id)
                    .transition(.opacity)
                }
            }
            .simultaneousGesture(edgeExitGesture(size: geometry.size), including: isCapturing ? .all : .subviews)
            .ignoresSafeArea()
        }
        .alert(item: $model.alert) { alert in
            Alert(
                title: Text(LocalizedChatString("record_failed")),
                message: Text(""),
                dismissButton: .default(Text("OK")) {
                    model.alertConfirmed(alert)
                }
            )
        }
        .onAppear(perform: model.onAppear)
        .onDisappear(perform: model.onDisappear)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            model.appDidBecomeActive()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            model.appWillResignActive()
        }
        .onReceive(model.$captureResult.compactMap { $0 }) { result in
            deliver(result)
        }
    }

    private var isCapturing: Bool {
        return model.previewPlayer == nil && model.editingPhoto == nil
    }

    private var themeColor: Color {
        guard let primaryColor = primaryColor, !primaryColor.isEmpty else {
            return Self.defaultThemeColor
        }
        return Color(hexString: primaryColor)
    }

    private func edgeExitGesture(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: VideoRecorderPreviewView.dragMinimumDistance, coordinateSpace: .global)
            .onEnded { value in
                guard value.startLocation.x <= VideoRecorderPreviewView.edgeWidth else { return }
                let width = max(size.width, 1)
                let height = max(size.height, 1)
                let xProgress = abs(value.translation.width) / width
                let yProgress = abs(value.translation.height) / height
                let isFastHorizontal = value.predictedEndTranslation.width / width > 1
                let isFastVertical = value.predictedEndTranslation.height / height > 1
                if xProgress > Self.edgeExitProgressThreshold || isFastHorizontal
                    || yProgress > Self.edgeExitProgressThreshold || isFastVertical {
                    model.cancelByEdgeSwipe()
                }
            }
    }

    private func deliver(_ result: VideoRecorderCaptureResult) {
        presentationMode.wrappedValue.dismiss()
        switch result {
        case .cancelled:
            onPhotoCaptured(nil)
        case let .video(path, durationMs):
            onVideoCaptured(path, durationMs, VideoRecorderMediaFiles.thumbnailPath(for: path))
        case let .photo(image):
            onPhotoCaptured(VideoRecorderMediaFiles.saveImage(image))
        }
    }
}

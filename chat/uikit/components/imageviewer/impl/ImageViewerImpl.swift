import Photos
import SwiftUI
import UIKit

private struct PlayButtonView: View {
    let element: ImageElement
    let isDownloading: Bool
    let onPlayTap: () -> Void
    let onDownloadTap: () -> Void

    var body: some View {
        Button(action: {
            if let videoPath = element.videoPath, !videoPath.isEmpty {
                onPlayTap()
            } else if !isDownloading {
                onDownloadTap()
            }
        }) {
            ZStack {
                if isDownloading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Colors.White1))
                        .scaleEffect(1.5)
                } else if let videoPath = element.videoPath, !videoPath.isEmpty {
                    Image(systemName: "play.circle.fill")
                        .resizable()
                        .frame(width: 60, height: 60)
                        .foregroundColor(Colors.White1)
                        .shadow(color: Colors.Black1.opacity(0.5), radius: 2, x: 0, y: 1)
                } else {
                    Image(systemName: "arrow.down.circle.fill")
                        .resizable()
                        .frame(width: 60, height: 60)
                        .foregroundColor(Colors.White1)
                        .shadow(color: Colors.Black1.opacity(0.5), radius: 2, x: 0, y: 1)
                }
            }
        }
        .disabled(isDownloading)
        .accessibilityValue(isDownloading ? "downloading" : (element.videoPath?.isEmpty == false ? "play" : "download"))
        .accessibilityIdentifier("chat_media_play")
    }
}

private struct MediaItemView: View {
    @ObservedObject private var themeState = ThemeState.shared
    let element: ImageElement
    let isDownloading: Bool
    let onPlayButtonTap: () -> Void
    let onDownloadButtonTap: () -> Void
    let onImageTap: () -> Void

    private var isRemoteURL: Bool {
        element.imagePath.hasPrefix("http://") || element.imagePath.hasPrefix("https://")
    }

    var body: some View {
        ZStack {
            mediaView
                .contentShape(Rectangle())
                .onTapGesture {
                    handleMediaTap()
                }
            if element.type == 1 {
                PlayButtonView(
                    element: element,
                    isDownloading: isDownloading,
                    onPlayTap: onPlayButtonTap,
                    onDownloadTap: onDownloadButtonTap
                )
            }
        }
    }

    @ViewBuilder
    private var mediaView: some View {
        if element.imagePath.isEmpty {
            placeholder
        } else if isRemoteURL, let url = URL(string: element.imagePath) {
            ZoomableImageView(url: url)
        } else if let image = UIImage(contentsOfFile: element.imagePath) {
            ZoomableImageView(image: image)
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        Rectangle()
            .fill(themeState.colors.bgColorFunction.opacity(0.3))
            .aspectRatio(1, contentMode: .fit)
            .overlay(
                Image(systemName: element.type == 0 ? "photo" : "video")
                    .foregroundColor(themeState.colors.textColorSecondary)
                    .font(FontScheme.title1Regular)
            )
    }

    private func handleMediaTap() {
        if element.type == 0 {
            onImageTap()
        } else if element.type == 1 {
            if let videoPath = element.videoPath, !videoPath.isEmpty {
                onPlayButtonTap()
            } else if !isDownloading {
                onDownloadButtonTap()
            }
        }
    }
}

private struct ToastView: View {
    let message: String
    @Binding var isShowing: Bool
    var body: some View {
        if isShowing {
            Text(message)
                .font(FontScheme.caption1Regular)
                .foregroundColor(Colors.White1)
                .padding(.horizontal, CGFloat(SpacingScheme.contentSpacing))
                .padding(.vertical, CGFloat(SpacingScheme.iconIconSpacing))
                .background(Colors.Black1.opacity(0.8))
                .cornerRadius(CGFloat(RadiusScheme.superLargeRadius))
                .transition(.opacity.combined(with: .scale))
                .zIndex(1000)
        }
    }
}

private struct LoadingIndicatorView: View {
    @Binding var isShowing: Bool

    var body: some View {
        if isShowing {
            VStack(spacing: CGFloat(SpacingScheme.iconIconSpacing)) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Colors.White1))
                    .scaleEffect(1.2)
                Text(LocalizedChatString("Loading"))
                    .font(FontScheme.caption1Regular)
                    .foregroundColor(Colors.White1)
            }
            .padding(CGFloat(SpacingScheme.contentSpacing))
            .background(Colors.Black1.opacity(0.7))
            .cornerRadius(CGFloat(RadiusScheme.alertRadius))
            .transition(.opacity.combined(with: .scale))
            .zIndex(999)
        }
    }
}

private struct SwipeDetectionOverlay: View {
    @State private var dragStartLocation: CGPoint = .zero
    @State private var isHorizontalSwipe = false
    enum SwipeDirection {
        case left, right, up, down
    }

    let onSwipe: (SwipeDirection) -> Void

    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        if dragStartLocation == .zero {
                            dragStartLocation = value.startLocation
                        }
                        let horizontalAmount = abs(value.location.x - dragStartLocation.x)
                        let verticalAmount = abs(value.location.y - dragStartLocation.y)
                        if horizontalAmount > verticalAmount, horizontalAmount > 30 {
                            isHorizontalSwipe = true
                        }
                    }
                    .onEnded { value in
                        if isHorizontalSwipe {
                            let horizontalAmount = value.location.x - dragStartLocation.x
                            if abs(horizontalAmount) > 50 {
                                if horizontalAmount > 0 {
                                    onSwipe(.right)
                                } else {
                                    onSwipe(.left)
                                }
                            }
                        }
                        dragStartLocation = .zero
                        isHorizontalSwipe = false
                    }
            )
    }
}

struct ImageViewerImpl: View {
    @State private var imageElements: [ImageElement]
    @State private var selectedImagePath: String
    @State private var previousImagePath: String

    private var currentIndex: Int {
        imageElements.firstIndex(where: { $0.imagePath == selectedImagePath }) ?? 0
    }

    @State private var isLoadingOlder = false
    @State private var isLoadingNewer = false
    @State private var pagingSession: UUID?
    @State private var showLoadingIndicator = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var loadingTimer: Timer?
    @State private var hasMoreOlder = true
    @State private var hasMoreNewer = true
    @State private var downloadingVideoElements = Set<String>()
    @State private var isSavingMedia = false

    private let onImageTap: () -> Void
    private let onLoadMore: ((Bool, @escaping (ImageViewerPage?) -> Void) -> Void)?
    private let onDownloadVideo: ((String, @escaping (String?) -> Void) -> Void)?
    private let onPlayVideo: ((String) -> Void)?
    private let presentsVideoPlayer: Bool

    init(imageElements: [ImageElement], initialIndex: Int = 0, presentsVideoPlayer: Bool = true, onEventTriggered: @escaping ([String: Any], @escaping (Any?) -> Void) -> Void) {
        self.presentsVideoPlayer = presentsVideoPlayer
        self._imageElements = State(initialValue: imageElements)
        self.onImageTap = {
            let eventData = ["event": "onImageTap"]
            onEventTriggered(eventData) { _ in }
        }
        self.onLoadMore = { isOlder, completion in
            let eventData = [
                "event": "onLoadMore",
                "param": ["isOlder": isOlder]
            ] as [String: Any]
            onEventTriggered(eventData) { result in
                if let page = result as? ImageViewerPage {
                    completion(page)
                } else if let elements = result as? [ImageElement] {
                    completion(ImageViewerPage(elements: elements, hasMore: !elements.isEmpty))
                } else if let dictionaries = result as? [[String: Any]] {
                    let elements = Self.convertToImageElements(dictionaries)
                    completion(ImageViewerPage(elements: elements, hasMore: !dictionaries.isEmpty))
                } else {
                    completion(nil)
                }
            }
        }
        self.onDownloadVideo = { imagePath, completion in
            let eventData = [
                "event": "onDownloadVideo",
                "param": ["path": imagePath]
            ] as [String: Any]
            onEventTriggered(eventData) { result in
                if let resultArray = result as? [String], let videoPath = resultArray.first {
                    completion(videoPath)
                } else {
                    completion(nil)
                }
            }
        }
        self.onPlayVideo = { videoPath in
            let eventData = [
                "event": "onPlayVideo",
                "param": ["path": videoPath]
            ] as [String: Any]
            onEventTriggered(eventData) { _ in }
        }
        let validIndex = max(0, min(initialIndex, imageElements.count - 1))
        let selectedPath = imageElements.isEmpty ? "" : imageElements[validIndex].imagePath
        self._selectedImagePath = State(initialValue: selectedPath)
        self._previousImagePath = State(initialValue: selectedPath)
    }

    var body: some View {
        ZStack {
            Colors.Black1.ignoresSafeArea(.all)
            TabView(selection: $selectedImagePath) {
                ForEach(imageElements, id: \.imagePath) { element in
                    MediaItemView(
                        element: element,
                        isDownloading: downloadingVideoElements.contains(element.imagePath),
                        onPlayButtonTap: {
                            if let videoPath = element.videoPath {
                                onPlayVideo?(videoPath)
                            }
                        },
                        onDownloadButtonTap: {
                            downloadVideo(element: element)
                        },
                        onImageTap: {
                            onImageTap()
                        }
                    )
                    .tag(element.imagePath)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onChange(of: selectedImagePath) { _ in
                let previousIndex = imageElements.firstIndex(where: { $0.imagePath == previousImagePath }) ?? currentIndex
                previousImagePath = selectedImagePath
                handleIndexChange(newIndex: currentIndex, previousIndex: previousIndex)
            }

            VStack {
                Spacer()
                LoadingIndicatorView(isShowing: $showLoadingIndicator)
                Spacer()
            }
            VStack {
                Spacer()
                ToastView(message: toastMessage, isShowing: $showToast)
                    .padding(.bottom, 100)
                Spacer()
            }
            VStack {
                HStack {
                    Button(action: { onImageTap() }) {
                        if let closeImage = AtomicXChatResources.image(named: "image_viewer_close_icon") {
                            Image(uiImage: closeImage)
                        } else {
                            Image(systemName: "xmark")
                                .font(FontScheme.body4Regular)
                                .foregroundColor(Colors.White1)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(width: 48, height: 48)
                    .contentShape(Rectangle())
                    .accessibilityLabel(LocalizedChatString("Close"))
                    .accessibilityIdentifier("chat_media_close")
                    Spacer()
                }
                .padding(.leading, CGFloat(SpacingScheme.smallSpacing))
                .padding(.top, CGFloat(SpacingScheme.smallSpacing))
                Spacer()
            }
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: saveCurrentMedia) {
                        Image("image_viewer_save_button", bundle: AtomicXChatResources.resourceBundle)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(width: 48, height: 48)
                    .contentShape(Rectangle())
                    .disabled(isSavingMedia)
                    .padding(.trailing, CGFloat(SpacingScheme.bubbleSpacing))
                    .padding(.bottom, CGFloat(SpacingScheme.smallSpacing))
                }
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    if value.translation.width < 0, currentIndex == imageElements.count - 1 {
                        requestLoadMore(isOlder: false)
                    } else if value.translation.width > 0, currentIndex == 0 {
                        requestLoadMore(isOlder: true)
                    }
                }
        )
        .onAppear {
            pagingSession = UUID()
            if currentIndex <= 1 { requestLoadMore(isOlder: true) }
            if currentIndex >= imageElements.count - 2 { requestLoadMore(isOlder: false) }
        }
        .modifier(VideoPlayerSupportModifier(presentsInCover: presentsVideoPlayer))
        .onDisappear {
            pagingSession = nil
            downloadingVideoElements.removeAll()
            isLoadingOlder = false
            isLoadingNewer = false
            if !VideoPlayer.shared.isPresented {
                VideoPlayer.shared.dismiss()
            }
            cancelLoadingTimer()
        }
    }

    private func handleIndexChange(newIndex: Int, previousIndex: Int) {
        VideoPlayer.shared.dismiss()
        checkIfLoadMore(newIndex: newIndex, previousIndex: previousIndex)
    }

    private static func convertToImageElements(_ newElementsData: [[String: Any]]) -> [ImageElement] {
        return newElementsData.compactMap { dict -> ImageElement? in
            guard let type = dict["type"] as? Int,
                  let imagePath = dict["imagePath"] as? String
            else {
                return nil
            }
            let videoPath = dict["videoPath"] as? String
            let finalVideoPath = (videoPath?.isEmpty == true) ? nil : videoPath
            return ImageElement(
                type: type,
                imagePath: imagePath,
                videoPath: finalVideoPath
            )
        }
    }

    private func checkIfLoadMore(newIndex: Int, previousIndex: Int) {
        if newIndex <= 1, newIndex < previousIndex {
            requestLoadMore(isOlder: true)
        } else if newIndex >= imageElements.count - 2, newIndex > previousIndex {
            requestLoadMore(isOlder: false)
        }
    }

    private func requestLoadMore(isOlder: Bool) {
        guard let session = pagingSession, !isLoadingOlder, !isLoadingNewer,
              isOlder ? hasMoreOlder : hasMoreNewer,
              let onLoadMore = onLoadMore else { return }
        if isOlder { isLoadingOlder = true } else { isLoadingNewer = true }
        startLoadingTimer()
        onLoadMore(isOlder) { page in
            DispatchQueue.main.async {
                guard self.pagingSession == session else { return }
                self.handleLoadMoreResponse(page: page, isOlder: isOlder)
            }
        }
    }

    private func handleLoadMoreResponse(page: ImageViewerPage?, isOlder: Bool) {
        cancelLoadingTimer()
        if let page = page {
            updateImageElements(newElements: page.elements, isOlder: isOlder)
            if isOlder { hasMoreOlder = page.hasMore } else { hasMoreNewer = page.hasMore }
        }
        if isOlder { isLoadingOlder = false } else { isLoadingNewer = false }
        guard let page = page, page.hasMore else { return }
        let nearBoundary = isOlder ? currentIndex <= 1 : currentIndex >= imageElements.count - 2
        if nearBoundary {
            DispatchQueue.main.async {
                self.requestLoadMore(isOlder: isOlder)
            }
        }
    }

    private func updateImageElements(newElements: [ImageElement], isOlder: Bool) {
        var seenPaths = Set(imageElements.map { $0.imagePath })
        let uniqueNewElements = newElements.filter { seenPaths.insert($0.imagePath).inserted }
        guard !uniqueNewElements.isEmpty else { return }
        VideoPlayer.withoutAnimation {
            imageElements = isOlder ? uniqueNewElements + imageElements : imageElements + uniqueNewElements
        }
    }

    private func startLoadingTimer() {
        cancelLoadingTimer()
        loadingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.showLoadingIndicator = true
                }
            }
        }
    }

    private func cancelLoadingTimer() {
        loadingTimer?.invalidate()
        loadingTimer = nil
        withAnimation(.easeInOut(duration: 0.3)) {
            showLoadingIndicator = false
        }
    }

    private func saveCurrentMedia() {
        guard !isSavingMedia, currentIndex < imageElements.count else { return }
        let element = imageElements[currentIndex]
        isSavingMedia = true
        requestPhotoAddPermission { granted in
            guard granted else {
                finishSave(success: false)
                return
            }
            if element.type == 1 {
                saveVideo(element: element)
            } else {
                saveImage(element: element)
            }
        }
    }

    private func requestPhotoAddPermission(completion: @escaping (Bool) -> Void) {
        let handler: (PHAuthorizationStatus) -> Void = { status in
            DispatchQueue.main.async {
                completion(status == .authorized || status == .limited)
            }
        }
        if #available(iOS 14, *) {
            PHPhotoLibrary.requestAuthorization(for: .addOnly, handler: handler)
        } else {
            PHPhotoLibrary.requestAuthorization(handler)
        }
    }

    private func saveImage(element: ImageElement) {
        let path = element.imagePath
        if FileManager.default.fileExists(atPath: path), let data = FileManager.default.contents(atPath: path) {
            writePhotoData(data)
        } else if path.hasPrefix("http://") || path.hasPrefix("https://"), let url = URL(string: path) {
            URLSession.shared.dataTask(with: url) { data, _, _ in
                DispatchQueue.main.async {
                    if let data = data {
                        writePhotoData(data)
                    } else {
                        finishSave(success: false)
                    }
                }
            }.resume()
        } else {
            finishSave(success: false)
        }
    }

    private func saveVideo(element: ImageElement) {
        if let path = element.videoPath, FileManager.default.fileExists(atPath: path) {
            writeVideoFile(URL(fileURLWithPath: path))
        } else {
            finishSave(success: false)
        }
    }

    private func writePhotoData(_ data: Data) {
        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, data: data, options: nil)
        }, completionHandler: { success, _ in
            DispatchQueue.main.async {
                finishSave(success: success)
            }
        })
    }

    private func writeVideoFile(_ fileURL: URL) {
        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .video, fileURL: fileURL, options: nil)
        }, completionHandler: { success, _ in
            DispatchQueue.main.async {
                finishSave(success: success)
            }
        })
    }

    private func finishSave(success: Bool) {
        isSavingMedia = false
        toastMessage = LocalizedChatString(success ? "ImageViewerSaveSuccess" : "ImageViewerSaveFailed")
        withAnimation(.easeInOut(duration: 0.3)) {
            showToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showToast = false
            }
        }
    }

    private func downloadVideo(element: ImageElement) {
        guard element.type == 1,
              element.videoPath?.isEmpty != false,
              !downloadingVideoElements.contains(element.imagePath),
              let onDownloadVideo = onDownloadVideo
        else {
            return
        }
        let session = pagingSession
        downloadingVideoElements.insert(element.imagePath)
        onDownloadVideo(element.imagePath) { videoPath in
            DispatchQueue.main.async {
                guard let session = session, self.pagingSession == session else { return }
                self.downloadingVideoElements.remove(element.imagePath)
                if let videoPath = videoPath, !videoPath.isEmpty {
                    if let index = self.imageElements.firstIndex(where: { $0.imagePath == element.imagePath }) {
                        self.imageElements[index] = ImageElement(
                            type: element.type,
                            imagePath: element.imagePath,
                            videoPath: videoPath
                        )
                    }
                } else {
                    self.toastMessage = LocalizedChatString("VideoDownloadFailed")
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.showToast = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            self.showToast = false
                        }
                    }
                }
            }
        }
    }
}

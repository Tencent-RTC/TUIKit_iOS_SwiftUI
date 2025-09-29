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
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                } else if let videoPath = element.videoPath, !videoPath.isEmpty {
                    Image(systemName: "play.circle.fill")
                        .resizable()
                        .frame(width: 60, height: 60)
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                } else {
                    Image(systemName: "arrow.down.circle.fill")
                        .resizable()
                        .frame(width: 60, height: 60)
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                }
            }
        }
        .disabled(isDownloading)
    }
}

private struct MediaItemView: View {
    let element: ImageElement
    let isDownloading: Bool
    let onPlayButtonTap: () -> Void
    let onDownloadButtonTap: () -> Void
    let onImageTap: () -> Void

    var body: some View {
        ZStack {
            if let image = UIImage(contentsOfFile: element.imagePath) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .contentShape(Rectangle())
                    .onTapGesture {
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
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(
                        Image(systemName: element.type == 0 ? "photo" : "video")
                            .foregroundColor(.gray)
                            .font(.system(size: 50))
                    )
                    .onTapGesture {
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
}

private struct ToastView: View {
    let message: String
    @Binding var isShowing: Bool
    var body: some View {
        if isShowing {
            Text(message)
                .font(.system(size: 16))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.8))
                .cornerRadius(25)
                .transition(.opacity.combined(with: .scale))
                .zIndex(1000)
        }
    }
}

private struct LoadingIndicatorView: View {
    @Binding var isShowing: Bool

    var body: some View {
        if isShowing {
            VStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)
                Text(LocalizedChatString("Loading"))
                    .font(.system(size: 16))
                    .foregroundColor(.white)
            }
            .padding(20)
            .background(Color.black.opacity(0.7))
            .cornerRadius(12)
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

public struct ImageViewer: View {
    @State private var imageElements: [ImageElement]
    @State private var currentIndex: Int
    @State private var previousIndex: Int

    @State private var isLoadingOlder = false
    @State private var isLoadingNewer = false
    @State private var isUpdatingData = false
    @State private var showLoadingIndicator = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var loadingTimer: Timer?
    @State private var hasMoreData = true
    @State private var downloadingVideoElements = Set<String>()

    private let onImageTap: () -> Void
    private let onLoadMore: ((Bool, @escaping ([[String: Any]]) -> Void) -> Void)?
    private let onDownloadVideo: ((String, @escaping (String?) -> Void) -> Void)?

    public init(imageElements: [ImageElement], initialIndex: Int = 0, onEventTriggered: @escaping ([String: Any], @escaping (Any?) -> Void) -> Void) {
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
                if let elements = result as? [[String: Any]] {
                    completion(elements)
                } else {
                    completion([])
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
        let validIndex = max(0, min(initialIndex, imageElements.count - 1))
        self._currentIndex = State(initialValue: validIndex)
        self._previousIndex = State(initialValue: validIndex)
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea(.all)
            if isUpdatingData {
                if currentIndex < imageElements.count {
                    MediaItemView(
                        element: imageElements[currentIndex],
                        isDownloading: downloadingVideoElements.contains(imageElements[currentIndex].imagePath),
                        onPlayButtonTap: {
                            if let videoPath = imageElements[currentIndex].videoPath {
                                let videoData = VideoData(
                                    uri: videoPath,
                                    localPath: videoPath,
                                    width: 1920,
                                    height: 1080
                                )
                                VideoPlayer.shared.play(videoData: videoData)
                            }
                        },
                        onDownloadButtonTap: {
                            downloadVideo(element: imageElements[currentIndex])
                        },
                        onImageTap: {
                            onImageTap()
                        }
                    )
                }
            } else {
                TabView(selection: $currentIndex) {
                    ForEach(Array(imageElements.enumerated()), id: \.element.imagePath) { index, element in
                        MediaItemView(
                            element: element,
                            isDownloading: downloadingVideoElements.contains(element.imagePath),
                            onPlayButtonTap: {
                                if let videoPath = element.videoPath {
                                    let videoData = VideoData(
                                        uri: videoPath,
                                        localPath: videoPath,
                                        width: 1920,
                                        height: 1080
                                    )
                                    VideoPlayer.shared.play(videoData: videoData)
                                }
                            },
                            onDownloadButtonTap: {
                                downloadVideo(element: element)
                            },
                            onImageTap: {
                                onImageTap()
                            }
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .onChange(of: currentIndex) { newIndex in
                    handleIndexChange(newIndex: newIndex, previousIndex: previousIndex)
                    previousIndex = newIndex
                }
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
        }
        .onDisappear {
            VideoPlayer.shared.dismiss()
            cancelLoadingTimer()
        }
    }

    private func handleIndexChange(newIndex: Int, previousIndex: Int) {
        VideoPlayer.shared.dismiss()
        checkIfLoadMore(newIndex: newIndex, previousIndex: previousIndex)
    }

    private func convertToImageElements(_ newElementsData: [[String: Any]]) -> [ImageElement] {
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
        let preloadThreshold = 1
        let isSwipingLeft = newIndex < previousIndex
        let isSwipingRight = newIndex > previousIndex
        if newIndex <= preloadThreshold && isSwipingLeft && !isLoadingOlder {
            isLoadingOlder = true
            startLoadingTimer()
            onLoadMore?(true) { newElementsData in
                self.handleLoadMoreResponse(newElementsData: newElementsData, isOlder: true)
                showNoMoreDataToastIfNeeded()
            }
        } else if newIndex >= (imageElements.count - 1 - preloadThreshold) && isSwipingRight && !isLoadingNewer {
            isLoadingNewer = true
            startLoadingTimer()
            onLoadMore?(false) { newElementsData in
                self.handleLoadMoreResponse(newElementsData: newElementsData, isOlder: false)
                showNoMoreDataToastIfNeeded()
            }
        }
    }

    private func handleLoadMoreResponse(newElementsData: [[String: Any]], isOlder: Bool) {
        cancelLoadingTimer()
        let newElements = convertToImageElements(newElementsData)
        if newElements.isEmpty {
            hasMoreData = false
        } else {
            updateImageElements(newElements: newElements, isOlder: isOlder)
        }
        if isOlder {
            isLoadingOlder = false
        } else {
            isLoadingNewer = false
        }
    }

    private func updateImageElements(newElements: [ImageElement], isOlder: Bool) {
        isUpdatingData = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if isOlder {
                let newElementsCount = newElements.count
                let newCurrentIndex = self.currentIndex + newElementsCount
                self.imageElements = newElements + self.imageElements
                self.currentIndex = newCurrentIndex
            } else {
                self.imageElements = self.imageElements + newElements
            }
            self.isUpdatingData = false
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

    private func showNoMoreDataToastIfNeeded() {
        guard !hasMoreData else { return }
        toastMessage = LocalizedChatString("MessageReadNoMoreData")
        withAnimation(.easeInOut(duration: 0.3)) {
            showToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.3)) {
                self.showToast = false
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
        downloadingVideoElements.insert(element.imagePath)
        onDownloadVideo(element.imagePath) { videoPath in
            DispatchQueue.main.async {
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

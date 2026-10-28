import Kingfisher
import SwiftUI

struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage?
    let url: URL?

    init(image: UIImage? = nil, url: URL? = nil) {
        self.image = image
        self.url = url
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = ZoomableScrollView()
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 3
        scrollView.bouncesZoom = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.delegate = context.coordinator
        context.coordinator.imageView = scrollView.hostedImageView
        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        // updateUIView 可能早于有效布局，图片加载完成不会再次调用它；在 layoutSubviews 同步尺寸。
        guard let imageView = context.coordinator.imageView else { return }
        if let image = image {
            imageView.image = image
        } else if let url = url {
            imageView.kf.setImage(with: url)
        } else {
            imageView.image = nil
        }
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var imageView: UIImageView?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return imageView
        }
    }
}

private final class ZoomableScrollView: UIScrollView {
    let hostedImageView = UIImageView()
    private var lastBoundsSize: CGSize = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        hostedImageView.contentMode = .scaleAspectFit
        hostedImageView.isUserInteractionEnabled = true
        addSubview(hostedImageView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // 仅 bounds 尺寸变化时重置布局，避免覆盖缩放的 contentSize。
        guard bounds.size != lastBoundsSize else { return }
        lastBoundsSize = bounds.size
        hostedImageView.frame = bounds
        contentSize = bounds.size
    }
}

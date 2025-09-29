import Kingfisher
import SwiftUI

extension View {
    @ViewBuilder
    func compatibleIgnoreSafeArea() -> some View {
        if #available(iOS 14.0, *) {
            self.ignoresSafeArea()
        } else {
            edgesIgnoringSafeArea(.all)
        }
    }
}

public struct CompatibleKFImage: View {
    let url: URL?
    let path: String?
    let fallback: () -> AnyView
    let width: CGFloat?
    let height: CGFloat?
    let contentMode: SwiftUI.ContentMode
    public init(
        url: URL? = nil,
        path: String? = nil,
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        contentMode: SwiftUI.ContentMode = .fill,
        fallback: @escaping () -> AnyView
    ) {
        self.url = url
        self.path = path
        self.width = width
        self.height = height
        self.contentMode = contentMode
        self.fallback = fallback
    }

    public var body: some View {
        Group {
            if #available(iOS 14.0, *) {
                if let url = url, !url.absoluteString.isEmpty {
                    KFImage(url)
                        .placeholder { fallback() }
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                        .frame(width: width, height: height)
                } else if let path = path, !path.isEmpty {
                    if FileManager.default.fileExists(atPath: path) {
                        let provider = LocalFileImageDataProvider(fileURL: URL(fileURLWithPath: path))
                        KFImage(source: .provider(provider))
                            .placeholder { fallback() }
                            .resizable()
                            .frame(width: width, height: height)
                    } else {
                        fallback()
                    }
                } else {
                    fallback()
                }
            } else {
                if let url = url, !url.absoluteString.isEmpty {
                    KFImageView(url: url, width: width, height: height, contentMode: contentMode, fallback: fallback)
                } else {
                    fallback()
                }
            }
        }
    }
}

struct KFImageView: UIViewRepresentable {
    let url: URL
    let width: CGFloat?
    let height: CGFloat?
    let contentMode: SwiftUI.ContentMode
    let fallback: () -> AnyView
    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = contentMode == .fill ? .scaleAspectFill : .scaleAspectFit
        imageView.clipsToBounds = true
        if let width = width, let height = height {
            imageView.frame = CGRect(x: 0, y: 0, width: width, height: height)
        }
        return imageView
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        uiView.kf.setImage(with: url, completionHandler: { result in
            switch result {
            case .success:
                break
            case .failure:
                let fallbackView = UIHostingController(rootView: fallback())
                fallbackView.view.frame = uiView.bounds
                fallbackView.view.backgroundColor = .clear
                uiView.addSubview(fallbackView.view)
            }
        })
    }
}

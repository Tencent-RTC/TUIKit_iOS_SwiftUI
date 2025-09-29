import Foundation
import Kingfisher
import SwiftUI

public enum AvatarType {
    case image
    case text
    case symbol
    case local
}

public enum AvatarSize: CGFloat, CaseIterable {
    case xs = 24
    case s = 32
    case m = 40
    case l = 48
    case xl = 64
    case xxl = 96
    var borderRadius: CGFloat {
        switch self {
        case .xs, .s, .m: return 4
        case .l: return 8
        case .xl, .xxl: return 12
        }
    }
}

public enum AvatarShape {
    case round
    case roundedRectangle
    case rectangle
}

public enum AvatarBadgePosition {
    case up
    case bottom
}

public enum AvatarStatus {
    case none
    case online
    case offline
}

public enum AvatarContent {
    case image(url: String?, name: String? = "")
    case text(name: String)
    case symbol
    case local(isGroup: Bool = false)
}

public enum AvatarBadge {
    case none
    case dot
    case text(String)
    case count(Int)
}

struct AnyShape: Shape, @unchecked Sendable {
    private let pathBuilder: @Sendable (CGRect) -> Path
    init<S: Shape>(_ shape: S) {
        self.pathBuilder = { rect in shape.path(in: rect) }
    }

    func path(in rect: CGRect) -> Path {
        pathBuilder(rect)
    }
}

public struct Avatar: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var themeState: ThemeState
    let content: AvatarContent
    let size: AvatarSize
    let shape: AvatarShape?
    let status: AvatarStatus
    let badge: AvatarBadge
    let onClick: (() -> Void)?
    public init(
        content: AvatarContent,
        size: AvatarSize = .m,
        shape: AvatarShape? = nil,
        status: AvatarStatus = .none,
        badge: AvatarBadge = .none,
        onClick: (() -> Void)? = nil
    ) {
        self.content = content
        self.size = size
        self.shape = shape
        self.status = status
        self.badge = badge
        self.onClick = onClick
    }

    public init(
        url: String?,
        name: String?,
        size: AvatarSize = .m,
        shape: AvatarShape? = nil,
        onClick: (() -> Void)? = nil
    ) {
        self.init(content: .image(url: url, name: name), size: size, shape: shape, status: .none, badge: .none, onClick: onClick)
    }

    public var body: some View {
        let avatar = avatarContent
            .frame(width: size.rawValue, height: size.rawValue)
            .clipShape(avatarShape)
        ZStack(alignment: .center) {
            if let onClick = onClick {
                avatar.onTapGesture { onClick() }
            } else {
                avatar
            }
            if status == .online || status == .offline {
                statusDot
            }
            badgeView
        }
    }

    private var avatarShape: AnyShape {
        let result: AvatarShape
        if let userShape = shape {
            result = userShape
        } else {
            let config = AppBuilderConfig.shared
            switch config.avatarShape {
            case .circular:
                result = .round
            case .rounded:
                result = .roundedRectangle
            case .square:
                result = .rectangle
            }
        }
        switch result {
        case .round:
            return AnyShape(Circle())
        case .roundedRectangle:
            return AnyShape(RoundedRectangle(cornerRadius: size.borderRadius))
        case .rectangle:
            return AnyShape(Rectangle())
        }
    }

    @ViewBuilder
    private var avatarContent: some View {
        switch content {
        case .image(let url, let name):
            CompatibleKFImage(url: URL(string: url ?? ""), fallback: { AnyView(defaultTextOrSymbol(name)) })
        case .text(let name):
            defaultTextOrSymbol(name)
        case .symbol:
            ZStack {
                avatarShape.fill(avatarBackgroundColor)
                Image("avatar-contact", bundle: Bundle(for: AvatarObject.self))
                    .resizable()
                    .scaledToFit()
                    .frame(width: size.rawValue * 0.6, height: size.rawValue * 0.6)
            }
        case .local(let isGroup):
            Image(isGroup ? "avatar-default-group" : "avatar-default-contact", bundle: Bundle(for: AvatarObject.self))
                .resizable()
                .aspectRatio(contentMode: .fill)
        }
    }

    @ViewBuilder
    private func defaultTextOrSymbol(_ name: String?) -> some View {
        ZStack {
            avatarShape.fill(avatarBackgroundColor)
            if let name = name, !name.isEmpty, let first = name.first {
                Text(String(first).uppercased())
                    .font(fontForAvatarSize(size))
                    .background(themeState.colors.bgColorAvatar)
                    .foregroundColor(themeState.colors.textColorPrimary)
            } else {
                Image("avatar-contact", bundle: Bundle(for: AvatarObject.self))
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(themeState.colors.textColorPrimary)
                    .frame(width: size.rawValue * 0.6, height: size.rawValue * 0.6)
            }
        }
    }

    private var avatarBackgroundColor: Color {
        themeState.colors.bgColorAvatar
    }

    private func fontForAvatarSize(_ size: AvatarSize) -> Font {
        switch size {
        case .xs: return themeState.fonts.caption3Bold
        case .s: return themeState.fonts.caption2Bold
        case .m: return themeState.fonts.caption1Bold
        case .l: return themeState.fonts.body4Bold
        case .xl: return themeState.fonts.body1Bold
        case .xxl: return themeState.fonts.title2Bold
        }
    }

    @ViewBuilder
    private var statusDot: some View {
        let dotColor: Color = {
            switch status {
            case .online: return themeState.colors.textColorSuccess
            case .offline: return Color.gray.opacity(0.5)
            default: return .clear
            }
        }()
        Circle()
            .fill(dotColor)
            .frame(width: 8, height: 8)
            .overlay(Circle().stroke(themeState.colors.bgColorDefault, lineWidth: 1))
            .offset(x: size.rawValue/2 - 8, y: size.rawValue/2 - 8)
    }

    @ViewBuilder
    private var badgeView: some View {
        switch badge {
        case .none:
            EmptyView()
        case .dot:
            Circle()
                .fill(Color.red)
                .frame(width: 10, height: 10)
                .offset(x: size.rawValue/2 - 6, y: -size.rawValue/2 + 6)
        case .text(let text):
            Text(text)
                .font(.system(size: 10))
                .foregroundColor(.white)
                .padding(4)
                .background(Circle().fill(Color.red))
                .offset(x: size.rawValue/2 - 10, y: -size.rawValue/2 + 10)
        case .count(let count):
            let text = count > 99 ? "99+" : "\(count)"
            Text(text)
                .font(.system(size: 10))
                .foregroundColor(.white)
                .padding(4)
                .background(Circle().fill(Color.red))
                .offset(x: size.rawValue/2 - 10, y: -size.rawValue/2 + 10)
        }
    }
}

public class AvatarObject: ObservableObject {}
public extension Avatar {
    static func configureKingfisher() {
        let cache = ImageCache.default
        cache.memoryStorage.config.totalCostLimit = 10 * 1024 * 1024
        cache.diskStorage.config.sizeLimit = UInt(50 * 1024 * 1024)
        let downloader = KingfisherManager.shared.downloader
        downloader.sessionConfiguration.timeoutIntervalForRequest = 15
        KingfisherManager.shared.defaultOptions = [
            .cacheOriginalImage
        ]
    }

    static func configureKingfisherSmart() {
        let cache = ImageCache.default
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        let memoryInGB = totalMemory/(1024 * 1024 * 1024)
        let memoryCacheSize: Int
        if memoryInGB >= 4 {
            memoryCacheSize = 20 * 1024 * 1024
        } else if memoryInGB >= 2 {
            memoryCacheSize = 15 * 1024 * 1024
        } else {
            memoryCacheSize = 10 * 1024 * 1024
        }
        let diskCacheSize: Int
        if let availableSpace = getAvailableDiskSpace() {
            let availableSpaceInGB = availableSpace/(1024 * 1024 * 1024)
            if availableSpaceInGB >= 10 {
                diskCacheSize = 80 * 1024 * 1024
            } else if availableSpaceInGB >= 5 {
                diskCacheSize = 50 * 1024 * 1024
            } else {
                diskCacheSize = 30 * 1024 * 1024
            }
        } else {
            diskCacheSize = 50 * 1024 * 1024
        }
        cache.memoryStorage.config.totalCostLimit = memoryCacheSize
        cache.diskStorage.config.sizeLimit = UInt(diskCacheSize)
        let downloader = KingfisherManager.shared.downloader
        downloader.sessionConfiguration.timeoutIntervalForRequest = 15
        KingfisherManager.shared.defaultOptions = [
            .cacheOriginalImage
        ]
    }

    private static func getAvailableDiskSpace() -> Int64? {
        let fileManager = FileManager.default
        guard let path = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        do {
            let attributes = try fileManager.attributesOfFileSystem(forPath: path.path)
            return attributes[.systemFreeSize] as? Int64
        } catch {
            return nil
        }
    }
}

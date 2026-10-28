import SwiftUI

struct MessageTongueView: View {
    @EnvironmentObject var themeState: ThemeState
    let entry: MessageListFloatingEntry
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: CGFloat(SpacingScheme.smallSpacing)) {
                Image(uiImage: Self.makeDoubleArrowImage())
                    .renderingMode(.template)
                    .foregroundColor(themeState.colors.textColorLink)
                    .rotationEffect(.degrees(iconRotationDegrees))
                Text(text)
                    .font(themeState.fonts.caption2Regular)
                    .foregroundColor(themeState.colors.textColorLink)
                    .lineLimit(1)
            }
            .padding(.horizontal, CGFloat(SpacingScheme.iconIconSpacing))
            .frame(minWidth: 94, minHeight: 35)
            .background(themeState.colors.floatingColorDefault)
            .cornerRadius(CGFloat(RadiusScheme.smallRadius))
            .shadow(color: Colors.Black1.opacity(0.12), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityIdentifier(accessibilityID)
    }

    private var accessibilityID: String {
        if case .mention = entry { return "chat_mention_tongue" }
        return "chat_message_tongue"
    }

    private var iconRotationDegrees: Double {
        switch entry {
        case .mention:
            return 180
        case .backToLatest, .backToQuote, .newMessages:
            return 0
        }
    }

    private var text: String {
        switch entry {
        case .backToLatest:
            return LocalizedChatString("ChatBackToLatestLocation")
        case .newMessages(let count, _):
            return String(format: LocalizedChatString("ChatNewMessages"), "\(count)")
        case .mention(_, let isAtAll):
            return isAtAll ? LocalizedChatString("MentionAtAllTag") : LocalizedChatString("MentionAtMeTag")
        case .backToQuote:
            return LocalizedChatString("ChatBackToQuoteLocation")
        }
    }

    private static func makeDoubleArrowImage() -> UIImage {
        let iconWidth: CGFloat = 12
        let iconHeight: CGFloat = 11
        let viewportWidth: CGFloat = 24
        let viewportHeight: CGFloat = 22
        let size = CGSize(width: iconWidth, height: iconHeight)
        let transform = CGAffineTransform(scaleX: iconWidth / viewportWidth, y: iconHeight / viewportHeight)

        let lowerChevron = UIBezierPath()
        lowerChevron.move(to: CGPoint(x: 11.9802, y: 18.72669))
        lowerChevron.addLine(to: CGPoint(x: 1.6453, y: 9.69699))
        lowerChevron.addLine(to: CGPoint(x: 0, y: 11.53559))
        lowerChevron.addLine(to: CGPoint(x: 11.977, y: 22))
        lowerChevron.addLine(to: CGPoint(x: 24, y: 11.53729))
        lowerChevron.addLine(to: CGPoint(x: 22.3582, y: 9.69529))
        lowerChevron.close()

        let upperChevron = UIBezierPath()
        upperChevron.move(to: CGPoint(x: 24, y: 1.842))
        upperChevron.addLine(to: CGPoint(x: 22.3582, y: 0))
        upperChevron.addLine(to: CGPoint(x: 11.9802, y: 9.0314))
        upperChevron.addLine(to: CGPoint(x: 1.6453, y: 0.0017))
        upperChevron.addLine(to: CGPoint(x: 0, y: 1.8406))
        upperChevron.addLine(to: CGPoint(x: 11.977, y: 12.305))
        upperChevron.close()

        lowerChevron.apply(transform)
        upperChevron.apply(transform)

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            lowerChevron.fill()
            upperChevron.fill()
        }
    }
}

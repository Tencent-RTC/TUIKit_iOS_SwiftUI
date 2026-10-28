import SwiftUI
import UIKit

struct ListenPlaybackBar: View {
    @EnvironmentObject var themeState: ThemeState
    @ObservedObject var controller: ListenFromHereController

    private static let rowHeight: CGFloat = 36
    private static let maxExpandedWidth: CGFloat = 320
    private static let horizontalPadding = CGFloat(SpacingScheme.iconIconSpacing)
    private static let iconSize: CGFloat = 20
    private static let textIconSpacing = CGFloat(SpacingScheme.smallSpacing)
    private static let closeWidth: CGFloat = 36
    private static let textFont = UIKitFontScheme.caption2Regular
    private static let maxTextWidth = maxExpandedWidth - horizontalPadding - iconSize - textIconSpacing - closeWidth
    private static let expandAnimationDuration: TimeInterval = 0.2

    private var expanded: Bool {
        controller.isExpanded
    }

    private static func measuredTextWidth(_ text: String) -> CGFloat {
        let width = ceil((text as NSString).size(withAttributes: [.font: textFont]).width)
        return min(width, maxTextWidth)
    }

    var body: some View {
        let state = controller.state
        HStack(spacing: 0) {
            ZStack {
                if state.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    Image("message_listen", bundle: AtomicXChatResources.resourceBundle)
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .foregroundColor(themeState.colors.textColorLink)
                }
            }
            .frame(width: Self.iconSize, height: Self.iconSize)

            Text(state.currentText)
                .font(Font(Self.textFont))
                .foregroundColor(themeState.colors.textColorSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.leading, Self.textIconSpacing)
                .frame(width: expanded ? Self.measuredTextWidth(state.currentText) + Self.textIconSpacing : 0, alignment: .leading)
                .opacity(expanded ? 1 : 0)
                .allowsHitTesting(false)

            Button(action: {
                controller.stop()
            }) {
                Image("message_listen_close", bundle: AtomicXChatResources.resourceBundle)
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                    .foregroundColor(themeState.colors.textColorPrimary)
            }
            .frame(width: expanded ? Self.closeWidth : 0, height: Self.rowHeight)
            .opacity(expanded ? 1 : 0)
            .disabled(!expanded)
        }
        .padding(.leading, Self.horizontalPadding)
        .frame(height: Self.rowHeight)
        .background(themeState.colors.bgColorOperate)
        .cornerRadius(CGFloat(RadiusScheme.roundRadius))
        .overlay(
            RoundedRectangle(cornerRadius: CGFloat(RadiusScheme.roundRadius))
                .stroke(themeState.colors.strokeColorPrimary, lineWidth: 0.5)
        )
        .shadow(color: Colors.Black1.opacity(0.15), radius: 4, x: 0, y: 2)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: Self.expandAnimationDuration)) {
                controller.isExpanded.toggle()
            }
        }
    }
}

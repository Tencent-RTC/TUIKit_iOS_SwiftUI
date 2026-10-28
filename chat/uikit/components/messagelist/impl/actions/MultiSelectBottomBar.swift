import SwiftUI

struct MultiSelectBottomBar: View {
    let selectedCount: Int
    let onForwardSeparate: () -> Void
    let onForwardMerge: () -> Void
    let onDelete: () -> Void

    @EnvironmentObject var themeState: ThemeState

    private var isEnabled: Bool { selectedCount > 0 }

    var body: some View {
        HStack(spacing: 0) {
            actionItem(icon: "message_multi_forward_separate", title: LocalizedChatString("RelayOneByOneForward"), action: onForwardSeparate)
            actionItem(icon: "message_multi_forward_merge", title: LocalizedChatString("RelayCombineForwad"), action: onForwardMerge)
            actionItem(icon: "message_multi_delete", title: LocalizedChatString("Delete"), action: onDelete)
        }
        .padding(.vertical, CGFloat(SpacingScheme.iconIconSpacing))
        .padding(.horizontal, CGFloat(SpacingScheme.bubbleSpacing))
        .frame(maxWidth: .infinity)
        .background(themeState.colors.bgColorBottomBar.ignoresSafeArea(edges: .bottom))
    }

    private func actionItem(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: CGFloat(SpacingScheme.smallSpacing)) {
                Image(icon, bundle: AtomicXChatResources.resourceBundle)
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .foregroundColor(themeState.colors.textColorSecondary)
                Text(title)
                    .font(themeState.fonts.caption3Regular)
                    .foregroundColor(themeState.colors.textColorSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.4)
    }
}

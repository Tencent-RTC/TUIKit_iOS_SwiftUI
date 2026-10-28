import SwiftUI

struct SelectionCheckBox: View {
    @EnvironmentObject var themeState: ThemeState
    let isChecked: Bool
    var isLocked: Bool = false
    var size: CGFloat = 16

    private static let iconRadiusRatio: CGFloat = 0.375
    private static let checkmarkHorizontalRatio: CGFloat = 0.5
    private static let checkmarkJointXRatio: CGFloat = 0.1
    private static let checkmarkVerticalRatio: CGFloat = 0.35
    private static let strokeLineWidth: CGFloat = 1.5
    private static let crossRadiusRatio: CGFloat = 0.4

    var body: some View {
        let colors = themeState.colors
        let center = size / 2
        let iconRadius = size * Self.iconRadiusRatio
        let stroke = StrokeStyle(lineWidth: Self.strokeLineWidth, lineCap: .round, lineJoin: .round)
        ZStack {
            if isChecked {
                Circle()
                    .fill(isLocked ? colors.textColorLinkDisabled : colors.textColorLink)
                Path { path in
                    path.move(to: CGPoint(x: center - iconRadius * Self.checkmarkHorizontalRatio, y: center))
                    path.addLine(to: CGPoint(x: center - iconRadius * Self.checkmarkJointXRatio,
                                             y: center + iconRadius * Self.checkmarkVerticalRatio))
                    path.addLine(to: CGPoint(x: center + iconRadius * Self.checkmarkHorizontalRatio,
                                             y: center - iconRadius * Self.checkmarkVerticalRatio))
                }
                .stroke(isLocked ? colors.textColorButtonDisabled : colors.textColorButton, style: stroke)
            } else {
                Circle()
                    .inset(by: 0.5)
                    .stroke(colors.scrollbarColorDefault, lineWidth: 1)
                if isLocked {
                    let crossRadius = iconRadius * Self.crossRadiusRatio
                    Path { path in
                        path.move(to: CGPoint(x: center - crossRadius, y: center - crossRadius))
                        path.addLine(to: CGPoint(x: center + crossRadius, y: center + crossRadius))
                        path.move(to: CGPoint(x: center + crossRadius, y: center - crossRadius))
                        path.addLine(to: CGPoint(x: center - crossRadius, y: center + crossRadius))
                    }
                    .stroke(colors.textColorButtonDisabled, style: stroke)
                }
            }
        }
        .frame(width: size, height: size)
        .allowsHitTesting(false)
    }
}

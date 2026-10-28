import SwiftUI

extension View {
    // 滚动标记须位于非懒加载容器，直接回调可规避 iOS 26 偏好值更新问题。
    func scrollOffsetMarker(coordinateSpace: String, onOffsetChange: @escaping (CGFloat) -> Void) -> some View {
        background(
            GeometryReader { geo in
                let minY = geo.frame(in: .named(coordinateSpace)).minY
                Color.clear
                    .onAppear { onOffsetChange(minY) }
                    .onChange(of: minY) { newMinY in
                        onOffsetChange(newMinY)
                    }
            }
        )
    }
}

func visibleSectionLetter(
    atScrollOffset offset: CGFloat,
    orderedLetters: [String],
    sectionRowCounts: [Int],
    sectionHeaderHeight: CGFloat = 32,
    rowHeight: CGFloat = 60
) -> String? {
    guard !orderedLetters.isEmpty, orderedLetters.count == sectionRowCounts.count else { return nil }
    var current: String? = orderedLetters.first
    var start: CGFloat = 0
    for (index, letter) in orderedLetters.enumerated() {
        if start <= offset + 1 {
            current = letter
        } else {
            break
        }
        start += sectionHeaderHeight + rowHeight * CGFloat(sectionRowCounts[index])
    }
    return current
}

struct LetterIndexBar: View {
    @EnvironmentObject var themeState: ThemeState
    let sectionTitles: [String]
    let onLetterSelected: (String) -> Void
    @Binding var scrubbingLetter: String?
    var currentLetter: String? = nil

    private let rowHeight: CGFloat = 16
    private let letterSpacing: CGFloat = 1
    private let verticalPadding = CGFloat(SpacingScheme.smallSpacing)
    private let barWidth: CGFloat = 24
    private let highlightedDiameter: CGFloat = 20

    var body: some View {
        VStack(spacing: letterSpacing) {
            ForEach(Array(sectionTitles.enumerated()), id: \.offset) { _, letter in
                let isHighlighted = scrubbingLetter == letter || (scrubbingLetter == nil && currentLetter == letter)
                Text(letter)
                    .font(themeState.fonts.caption3Regular)
                    .foregroundColor(isHighlighted ? themeState.colors.textColorButton : themeState.colors.textColorLink)
                    .frame(width: barWidth, height: rowHeight)
                    .background(
                        Circle()
                            .fill(isHighlighted ? themeState.colors.textColorLink : Color.clear)
                            .frame(width: highlightedDiameter, height: highlightedDiameter)
                    )
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("index_\(letter)")
                    .accessibilityValue(isHighlighted ? "selected" : "normal")
            }
        }
        .padding(.vertical, verticalPadding)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let letter = letter(at: value.location.y)
                    if letter != scrubbingLetter {
                        scrubbingLetter = letter
                        onLetterSelected(letter)
                    }
                }
                .onEnded { _ in
                    let current = scrubbingLetter
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        if scrubbingLetter == current {
                            scrubbingLetter = nil
                        }
                    }
                }
        )
        .accessibilityLabel("Section index")
    }

    private func letter(at y: CGFloat) -> String {
        let index = Int(floor((y - verticalPadding) / (rowHeight + letterSpacing)))
        let clamped = max(0, min(index, sectionTitles.count - 1))
        return sectionTitles[clamped]
    }
}

struct LetterIndexCenterBubble: View {
    @EnvironmentObject var themeState: ThemeState
    let letter: String

    private let size: CGFloat = 80

    var body: some View {
        Text(letter)
            .font(themeState.fonts.body1Bold)
            .foregroundColor(themeState.colors.textColorPrimary)
            .frame(width: size, height: size)
            .background(themeState.colors.bgColorBubbleReciprocal.opacity(0.9))
            .cornerRadius(CGFloat(RadiusScheme.roundRadius))
            .allowsHitTesting(false)
    }
}

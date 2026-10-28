import SwiftUI

struct TextInputDialog: View {
    @EnvironmentObject var themeState: ThemeState
    @Binding var isPresented: Bool
    let title: String
    let initialText: String
    let maxLength: Int?
    let multiline: Bool
    let onConfirm: (String) -> Void

    @State private var text: String = ""
    @FocusState private var focused: Bool

    init(
        isPresented: Binding<Bool>,
        title: String,
        initialText: String,
        maxLength: Int? = nil,
        multiline: Bool = false,
        onConfirm: @escaping (String) -> Void
    ) {
        self._isPresented = isPresented
        self.title = title
        self.initialText = initialText
        self.maxLength = maxLength
        self.multiline = multiline
        self.onConfirm = onConfirm
    }

    private static let dimAlpha: Double = 0.4
    private static let panelCornerRadius = CGFloat(RadiusScheme.alertRadius)
    private static let panelHorizontalMargin = CGFloat(SpacingScheme.cardSpacing)
    private static let panelMaxWidth: CGFloat = 360
    private static let contentPadding = CGFloat(SpacingScheme.contentSpacing)
    private static let inputCornerRadius = CGFloat(RadiusScheme.smallRadius)
    private static let inputHorizontalPadding = CGFloat(SpacingScheme.bubbleSpacing)
    private static let inputHeight: CGFloat = 40
    private static let confirmButtonHeight: CGFloat = 36
    private static let keyboardBottomSpacing = CGFloat(SpacingScheme.iconIconSpacing)
    private static let multilineMinHeight: CGFloat = 160
    private static let multilineMaxHeight: CGFloat = 280

    var body: some View {
        if isPresented {
            ZStack {
                Colors.Black1.opacity(Self.dimAlpha)
                    .ignoresSafeArea()
                    .onTapGesture { dismiss() }
                VStack(spacing: Self.contentPadding) {
                    Text(title)
                        .font(themeState.fonts.caption1Bold)
                        .foregroundColor(themeState.colors.textColorPrimary)
                        .frame(maxWidth: .infinity)
                    if multiline {
                        TextEditor(text: $text)
                            .font(themeState.fonts.caption1Regular)
                            .foregroundColor(themeState.colors.textColorPrimary)
                            .padding(.horizontal, Self.inputHorizontalPadding - 5)
                            .frame(minHeight: Self.multilineMinHeight, maxHeight: Self.multilineMaxHeight)
                            .modifier(HiddenScrollContentBackground())
                            .background(themeState.colors.bgColorDialog)
                            .cornerRadius(Self.inputCornerRadius)
                            .overlay(
                                RoundedRectangle(cornerRadius: Self.inputCornerRadius)
                                    .stroke(themeState.colors.strokeColorPrimary, lineWidth: 1)
                            )
                            .focused($focused)
                            .onChange(of: text) { newValue in
                                if let maxLength = maxLength, newValue.count > maxLength {
                                    text = String(newValue.prefix(maxLength))
                                }
                            }
                    } else {
                        TextField("", text: $text)
                            .font(themeState.fonts.caption1Regular)
                            .foregroundColor(themeState.colors.textColorPrimary)
                            .padding(.horizontal, Self.inputHorizontalPadding)
                            .frame(height: Self.inputHeight)
                            .background(themeState.colors.bgColorDialog)
                            .cornerRadius(Self.inputCornerRadius)
                            .overlay(
                                RoundedRectangle(cornerRadius: Self.inputCornerRadius)
                                    .stroke(themeState.colors.strokeColorPrimary, lineWidth: 1)
                            )
                            .focused($focused)
                            .submitLabel(.done)
                            .onSubmit { confirm() }
                            .onChange(of: text) { newValue in
                                if let maxLength = maxLength, newValue.count > maxLength {
                                    text = String(newValue.prefix(maxLength))
                                }
                            }
                    }
                    Button(action: confirm) {
                        Text(LocalizedChatString("Confirm"))
                            .font(themeState.fonts.caption1Regular)
                            .foregroundColor(themeState.colors.textColorButton)
                            .frame(maxWidth: .infinity)
                            .frame(height: Self.confirmButtonHeight)
                            .background(themeState.colors.buttonColorPrimaryDefault)
                            .cornerRadius(CGFloat(RadiusScheme.roundRadius))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(Self.contentPadding)
                .frame(maxWidth: Self.panelMaxWidth)
                .frame(width: UIScreen.main.bounds.width - Self.panelHorizontalMargin * 2)
                .background(themeState.colors.bgColorOperate)
                .cornerRadius(Self.panelCornerRadius)
            }
            .transition(.opacity)
            .onAppear {
                text = initialText
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { focused = true }
            }
        }
    }

    private func dismiss() {
        focused = false
        withAnimation(.easeInOut(duration: 0.15)) { isPresented = false }
    }

    private func confirm() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onConfirm(trimmed) }
    }
}

private struct HiddenScrollContentBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.scrollContentBackground(.hidden)
        } else {
            content
        }
    }
}

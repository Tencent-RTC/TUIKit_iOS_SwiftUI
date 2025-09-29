import Combine
import SwiftUI
import UIKit

public class KeyboardHandler: ObservableObject {
    @Published public var keyboardHeight: CGFloat = 0
    @Published public var isKeyboardVisible: Bool = false
    private var isResponseEnabled: Bool = true
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .compactMap { [weak self] notification -> CGFloat? in
                guard let self = self, self.isResponseEnabled else { return nil }
                guard let userInfo = notification.userInfo,
                      let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
                else {
                    return nil
                }
                let safeAreaBottom: CGFloat
                if #available(iOS 15.0, *) {
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first
                    {
                        safeAreaBottom = window.safeAreaInsets.bottom
                    } else {
                        safeAreaBottom = 0
                    }
                } else {
                    if let window = UIApplication.shared.windows.first {
                        safeAreaBottom = window.safeAreaInsets.bottom
                    } else {
                        safeAreaBottom = 0
                    }
                }
                return keyboardFrame.height - safeAreaBottom
            }
            .sink { [weak self] height in
                guard let self = self, self.isResponseEnabled else { return }
                withAnimation(.easeOut(duration: 0.25)) {
                    self.keyboardHeight = height
                    self.isKeyboardVisible = true
                }
            }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .sink { [weak self] _ in
                guard let self = self, self.isResponseEnabled else { return }
                withAnimation(.easeOut(duration: 0.25)) {
                    self.keyboardHeight = 0
                    self.isKeyboardVisible = false
                }
            }
            .store(in: &cancellables)
    }

    func disableResponse(for duration: TimeInterval = 1.0) {
        isResponseEnabled = false
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.isResponseEnabled = true
        }
    }
}

public extension View {
    func hideKeyboard() {
        let resign: Selector = #selector(UIResponder.resignFirstResponder)
        UIApplication.shared.sendAction(resign, to: nil, from: nil, for: nil)
    }
}

struct KeyboardAwarePadding: ViewModifier {
    @ObservedObject private var keyboard = KeyboardHandler()
    func body(content: Content) -> some View {
        content
            .padding(.bottom, keyboard.keyboardHeight)
            .animation(.easeOut(duration: 0.25), value: keyboard.keyboardHeight)
    }
}

extension View {
    func keyboardAwarePadding() -> some View {
        modifier(KeyboardAwarePadding())
    }
}

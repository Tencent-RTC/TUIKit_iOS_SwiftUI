import Combine
import SwiftUI
import UIKit

class KeyboardHandler: ObservableObject {
    @Published var keyboardHeight: CGFloat = 0
    @Published var isKeyboardVisible: Bool = false
    private(set) var keyboardAnimation: Animation = .easeInOut(duration: 0.25)
    let didShowPublisher = PassthroughSubject<Void, Never>()
    private var isResponseEnabled: Bool = true
    private var cancellables = Set<AnyCancellable>()

    init() {
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .compactMap { [weak self] notification -> (CGFloat, Animation)? in
                guard let self = self, self.isResponseEnabled else { return nil }
                guard let userInfo = notification.userInfo,
                      let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
                else {
                    return nil
                }
                let safeAreaBottom: CGFloat
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first
                {
                    safeAreaBottom = window.safeAreaInsets.bottom
                } else {
                    safeAreaBottom = 0
                }
                return (keyboardFrame.height - safeAreaBottom, Self.animation(from: notification))
            }
            .sink { [weak self] height, animation in
                guard let self = self, self.isResponseEnabled else { return }
                self.keyboardAnimation = animation
                withAnimation(animation) {
                    self.keyboardHeight = height
                    self.isKeyboardVisible = true
                }
            }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .sink { [weak self] notification in
                guard let self = self, self.isResponseEnabled else { return }
                let animation = Self.animation(from: notification)
                self.keyboardAnimation = animation
                withAnimation(animation) {
                    self.keyboardHeight = 0
                    self.isKeyboardVisible = false
                }
            }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)
            .sink { [weak self] _ in
                guard let self = self, self.isResponseEnabled else { return }
                self.didShowPublisher.send()
            }
            .store(in: &cancellables)
    }

    private static func animation(from notification: Notification) -> Animation {
        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
        return .easeInOut(duration: duration)
    }

    func disableResponse(for duration: TimeInterval = 1.0) {
        isResponseEnabled = false
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.isResponseEnabled = true
        }
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

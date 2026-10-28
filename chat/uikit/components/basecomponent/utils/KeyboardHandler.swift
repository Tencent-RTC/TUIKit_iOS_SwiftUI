import SwiftUI
import UIKit

public extension View {
    func hideKeyboard() {
        let resign: Selector = #selector(UIResponder.resignFirstResponder)
        UIApplication.shared.sendAction(resign, to: nil, from: nil, for: nil)
    }
}

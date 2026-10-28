import AtomicXCore
import SwiftUI

public struct TextEditSheetView: View {
    private let implementation: TextEditSheetImpl

    public init(title: String, currentText: String, placeholder: String, helpText: String?, onSave: @escaping (String) -> Void) {
        implementation = TextEditSheetImpl(
            title: title,
            currentText: currentText,
            placeholder: placeholder,
            helpText: helpText,
            onSave: onSave
        )
    }

    public var body: some View { implementation }
}

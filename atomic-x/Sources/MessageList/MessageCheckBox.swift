import SwiftUI

struct MessageCheckBox: View {
    let isSelected: Bool
    let isEnabled: Bool
    
    @EnvironmentObject var themeState: ThemeState
    
    init(isSelected: Bool, isEnabled: Bool = true) {
        self.isSelected = isSelected
        self.isEnabled = isEnabled
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? themeState.colors.buttonColorPrimaryDefault : Color.clear)
                .frame(width: 20, height: 20)
            
            if !isSelected {
                Circle()
                    .strokeBorder(
                        isEnabled ? themeState.colors.strokeColorPrimary : themeState.colors.textColorDisable,
                        lineWidth: 1.5
                    )
                    .frame(width: 20, height: 20)
            }
            
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .frame(width: 20, height: 20)
//        .scaleEffect(isSelected ? 1.0 : 0.9)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

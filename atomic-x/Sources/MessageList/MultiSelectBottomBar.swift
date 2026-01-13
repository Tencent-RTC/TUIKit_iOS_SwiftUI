import SwiftUI

struct MultiSelectBottomBar: View {
    let selectedCount: Int
    let onCancel: () -> Void
    let onDelete: () -> Void
    let onForward: () -> Void
    
    @EnvironmentObject var themeState: ThemeState
    
    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 24) {
                Button(action: onForward) {
                    Image("message_forward", bundle: AtomicXChatResources.resourceBundle)
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .foregroundColor(themeState.colors.textColorLink)
                }
                .disabled(selectedCount == 0)
                
                Button(action: onDelete) {
                    Image("message_delete", bundle: AtomicXChatResources.resourceBundle)
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 16, height: 16)
                        .scaledToFit()
                        .foregroundColor(themeState.colors.textColorLink)
                }
                .disabled(selectedCount == 0)
            }
            .padding(.leading, 16)
            
            Spacer()
            
            Text("\(selectedCount) \(LocalizedChatString("Selected"))")
                .font(.system(size: 14))
                .foregroundColor(themeState.colors.textColorPrimary)
            
            Spacer()
            
            Button(action: onCancel) {
                Text(LocalizedChatString("Cancel"))
                    .font(.system(size: 14))
                    .foregroundColor(themeState.colors.textColorLink)
            }
            .padding(.trailing, 16)
        }
        .frame(height: 56)
        .background(themeState.colors.bgColorOperate)
    }
}

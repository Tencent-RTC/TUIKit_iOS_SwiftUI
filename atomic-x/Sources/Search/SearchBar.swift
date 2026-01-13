import AtomicXCore
import SwiftUI

public struct SearchBar: View {
    @EnvironmentObject private var themeState: ThemeState
    @State private var isSearchPresented = false
    let onTapItem: (Any) -> Void

    public init(onTapItem: @escaping (Any) -> Void) {
        self.onTapItem = onTapItem
    }

    public var body: some View {
        Button(action: {
            isSearchPresented = true
        }) {
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(themeState.colors.textColorSecondary)
                    .font(.system(size: 20))
                Text(LocalizedChatString("Search"))
                    .font(.system(size: 16))
                    .foregroundColor(themeState.colors.textColorSecondary)
                Spacer()
            }
            .padding(.horizontal, 8)
            .frame(height: 36)
            .background(themeState.colors.bgColorInput)
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 16)
        .fullScreenCover(isPresented: $isSearchPresented) {
            NavigationView {
                SearchResultView(onTapItem: { result in
                    isSearchPresented = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        onTapItem(result)
                    }
                })
                .environmentObject(themeState)
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
    }
}

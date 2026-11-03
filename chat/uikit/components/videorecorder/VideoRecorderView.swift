import AtomicXCore
import SwiftUI

public struct VideoRecorderView: View {
    @EnvironmentObject var themeState: ThemeState

    let config: VideoRecorderConfig?
    let onVideoCaptured: (_ path: String?, _ durationMs: Int, _ thumbnailPath: String?) -> Void
    let onPhotoCaptured: (_ path: String?) -> Void

    public init(config: VideoRecorderConfig? = nil,
                onVideoCaptured: @escaping (String?, Int, String?) -> Void,
                onPhotoCaptured: @escaping (String?) -> Void) {
        self.config = config
        self.onVideoCaptured = onVideoCaptured
        self.onPhotoCaptured = onPhotoCaptured
    }

    public var body: some View {
        VideoRecorderViewImpl(
            config: config,
            primaryColor: themeState.currentPrimaryColor,
            onVideoCaptured: onVideoCaptured,
            onPhotoCaptured: onPhotoCaptured
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Colors.Black1.edgesIgnoringSafeArea(.all))
        .navigationBarHidden(true)
        .statusBar(hidden: true)
    }
}

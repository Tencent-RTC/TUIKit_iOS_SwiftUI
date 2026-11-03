import SwiftUI
import UIKit

struct VideoRecorderControlView: View {
    static let previewAspectRatio: CGFloat = 16.0 / 9.0

    private static let recordButtonBottomGap: CGFloat = 15

    private static let sideButtonSize: CGFloat = 28

    private static let sideButtonGap: CGFloat = 55

    private static let functionButtonTop: CGFloat = 64

    private static let functionButtonTrailing: CGFloat = 16

    private static let functionIconSize: CGFloat = 28

    private static let functionIconTextGap: CGFloat = 4

    private static let functionButtonGap: CGFloat = 24

    private static let functionTitleFontSize: CGFloat = 12

    private static let durationFontSize: CGFloat = 18

    private static let durationLabelGap: CGFloat = 8

    private static let tipFontSize: CGFloat = 16

    private static let tipBottomGap: CGFloat = 16

    private static let disabledOpacity: Double = 0.5

    @ObservedObject var model: VideoRecorderModel
    let themeColor: Color
    let safeAreaInsets: EdgeInsets

    @State private var lastMagnification: CGFloat = 1

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let recordTop = height - safeAreaInsets.bottom - Self.recordButtonBottomGap - VideoRecorderRecordButton.size
            let durationBottom = recordTop - Self.durationLabelGap
            let maskTop = durationBottom - Self.durationLineHeight - Self.durationLabelGap
            let tipBottom = min(width * Self.previewAspectRatio, maskTop) - Self.tipBottomGap

            ZStack(alignment: .topLeading) {
                Color.clear
                    .contentShape(Rectangle())

                Color.black
                    .frame(width: width, height: max(0, height - maskTop))
                    .offset(y: maskTop)

                Text(model.tipText)
                    .font(.system(size: Self.tipFontSize))
                    .foregroundColor(.white)
                    .frame(width: width, height: max(0, tipBottom), alignment: .bottom)
                    .opacity(model.areOperationsHidden ? 0 : 1)

                Text(model.durationText)
                    .font(.system(size: Self.durationFontSize, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(width: width, height: max(0, durationBottom), alignment: .bottom)
                    .opacity(model.isDurationVisible ? 1 : 0)

                recordRow
                    .frame(width: width)
                    .offset(y: recordTop)

                functionButtons
                    .padding(.top, Self.functionButtonTop)
                    .padding(.trailing, Self.functionButtonTrailing)
                    .frame(width: width, height: height, alignment: .topTrailing)
                    .opacity(model.areOperationsHidden ? 0 : 1)
                    .allowsHitTesting(!model.areOperationsHidden)
            }
            .frame(width: width, height: height)
        }
        .simultaneousGesture(
            MagnificationGesture()
                .onChanged { value in
                    model.zoom(by: value / lastMagnification)
                    lastMagnification = value
                }
                .onEnded { _ in
                    lastMagnification = 1
                }
        )
    }

    private static var durationLineHeight: CGFloat {
        return UIFont.monospacedSystemFont(ofSize: durationFontSize, weight: .medium).lineHeight
    }

    private var recordRow: some View {
        HStack(spacing: Self.sideButtonGap) {
            iconButton("cross", action: model.exit)
                .opacity(model.areOperationsHidden ? 0 : 1)
                .allowsHitTesting(!model.areOperationsHidden)
            VideoRecorderRecordButton(
                progress: model.progress,
                progressColor: themeColor,
                growsProgressRingWhenPressed: model.settings.recordMode == .photoOnly,
                onTap: model.recordButtonTapped,
                onLongPressBegan: model.recordButtonLongPressBegan,
                onLongPressEnded: model.recordButtonLongPressEnded,
                onLongPressCancelled: model.recordButtonLongPressCancelled
            )
            iconButton("camera_switch", action: model.switchCamera)
                .opacity(model.areOperationsHidden ? 0 : 1)
                .allowsHitTesting(!model.areOperationsHidden)
        }
    }

    private var functionButtons: some View {
        VStack(spacing: Self.functionButtonGap) {
            if model.settings.isSupportTorch {
                functionButton(image: model.isFlashOn ? "flash_open" : "flash_close",
                               title: LocalizedChatString("flash"),
                               action: model.toggleFlash)
                    .disabled(model.isUsingFrontCamera)
                    .opacity(model.isUsingFrontCamera ? Self.disabledOpacity : 1)
            }
            if model.isAspectSupported {
                functionButton(image: model.aspectRatio == .ratio3x4 ? "record_aspect_3_4" : "record_aspect_9_16",
                               title: LocalizedChatString("aspect"),
                               action: model.toggleAspectRatio)
            }
        }
    }

    private func iconButton(_ imageName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(imageName, bundle: AtomicXChatResources.resourceBundle)
                .resizable()
                .frame(width: Self.sideButtonSize, height: Self.sideButtonSize)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func functionButton(image: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: Self.functionIconTextGap) {
                Image(image, bundle: AtomicXChatResources.resourceBundle)
                    .resizable()
                    .frame(width: Self.functionIconSize, height: Self.functionIconSize)
                Text(title)
                    .font(.system(size: Self.functionTitleFontSize))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

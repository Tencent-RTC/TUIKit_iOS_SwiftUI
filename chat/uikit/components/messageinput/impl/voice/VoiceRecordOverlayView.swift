import SwiftUI
import UIKit

struct VoiceRecordOverlayView: View {
    @EnvironmentObject var themeState: ThemeState
    @Environment(\.layoutDirection) private var layoutDirection
    @ObservedObject var controller: VoiceInputRecordController

    private let actionSize: CGFloat = 80
    private let circleSideMargin: CGFloat = CGFloat(SpacingScheme.maxSpacing)
    private let circleBottomMargin: CGFloat = 107
    private let statusBottomMargin: CGFloat = 199
    private let statusHorizontalMargin: CGFloat = CGFloat(SpacingScheme.contentSpacing)
    private let bubbleHorizontalMargin: CGFloat = CGFloat(SpacingScheme.smallSpacing)
    private let bubbleBottomMargin: CGFloat = 43
    private let bubbleHeight: CGFloat = 40

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let isRTL = layoutDirection == .rightToLeft

            ZStack {
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: themeState.colors.bgColorOperate.opacity(0), location: 0),
                        .init(color: themeState.colors.bgColorOperate.opacity(0xB3 / 255.0), location: 0.42),
                        .init(color: themeState.colors.bgColorOperate, location: 0.67),
                        .init(color: themeState.colors.bgColorOperate, location: 1.0),
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                Text(statusText)
                    .font(themeState.fonts.caption2Medium)
                    .foregroundColor(themeState.colors.textColorSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, statusHorizontalMargin)
                    .position(x: width / 2, y: height - statusBottomMargin - 10)

                RecorderBubbleRepresentable(
                    bubbleColor: bubbleColor,
                    contentColor: UIColor(themeState.colors.textColorButton),
                    powerLevel: controller.currentPowerLevel,
                    durationText: controller.durationText
                )
                .frame(width: width - 2 * bubbleHorizontalMargin, height: bubbleHeight)
                .position(
                    x: width / 2,
                    y: height - bubbleBottomMargin - bubbleHeight / 2
                )

                circleButton(
                    title: LocalizedChatString("message_input_cancel"),
                    isActive: controller.activeZone == .cancel,
                    activeColor: themeState.colors.buttonColorHangupDefault
                )
                .position(
                    x: isRTL
                        ? width - circleSideMargin - actionSize / 2
                        : circleSideMargin + actionSize / 2,
                    y: height - circleBottomMargin - actionSize / 2
                )

                circleButton(
                    title: LocalizedChatString("message_input_transcribe_to_text"),
                    isActive: controller.activeZone == .transcribe,
                    activeColor: themeState.colors.buttonColorPrimaryDefault
                )
                .position(
                    x: isRTL
                        ? circleSideMargin + actionSize / 2
                        : width - circleSideMargin - actionSize / 2,
                    y: height - circleBottomMargin - actionSize / 2
                )
            }
            .onAppear {
                updateZoneFrames(width: width, height: height, isRTL: isRTL)
            }
            .onChange(of: geometry.size) { _ in
                updateZoneFrames(width: width, height: height, isRTL: isRTL)
            }
        }
        // 拖动和取消区域均使用窗口坐标，遮罩须覆盖整个窗口。
        .ignoresSafeArea()
        .transition(.opacity.animation(.easeIn(duration: 0.12)))
    }

    private var bubbleColor: UIColor {
        controller.activeZone == .cancel
            ? UIColor(themeState.colors.buttonColorHangupDefault)
            : UIColor(themeState.colors.buttonColorPrimaryDefault)
    }

    private var statusText: String {
        switch controller.activeZone {
        case .cancel:
            return LocalizedChatString("message_input_release_cancel_hint")
        case .transcribe:
            return LocalizedChatString("message_input_release_transcribe_hint")
        default:
            if controller.remainingSeconds <= 10 {
                return String(format: LocalizedChatString("message_input_auto_stop_countdown"), controller.remainingSeconds)
            }
            return LocalizedChatString("message_input_release_send_hint")
        }
    }

    private func circleButton(title: String, isActive: Bool, activeColor: Color) -> some View {
        Text(title)
            .font(themeState.fonts.caption1Bold)
            .foregroundColor(isActive ? themeState.colors.textColorButton : themeState.colors.textColorPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(width: actionSize, height: actionSize)
            .background(isActive ? activeColor : themeState.colors.buttonColorSecondaryDefault)
            .clipShape(Circle())
    }

    private func updateZoneFrames(width: CGFloat, height: CGFloat, isRTL: Bool) {
        let cancelX = isRTL ? width - circleSideMargin - actionSize : circleSideMargin
        let transcribeX = isRTL ? circleSideMargin : width - circleSideMargin - actionSize
        let y = height - circleBottomMargin - actionSize
        controller.zoneFrames = (
            cancel: CGRect(x: cancelX, y: y, width: actionSize, height: actionSize),
            transcribe: CGRect(x: transcribeX, y: y, width: actionSize, height: actionSize)
        )
    }
}

private struct RecorderBubbleRepresentable: UIViewRepresentable {
    let bubbleColor: UIColor
    let contentColor: UIColor
    let powerLevel: Int
    let durationText: String

    func makeUIView(context: Context) -> RecorderBubbleUIView {
        let view = RecorderBubbleUIView()
        view.setBubbleColor(bubbleColor)
        view.setContentColor(contentColor)
        view.setPowerLevel(powerLevel)
        view.setDurationText(durationText)
        return view
    }

    func updateUIView(_ uiView: RecorderBubbleUIView, context: Context) {
        uiView.setBubbleColor(bubbleColor)
        uiView.setContentColor(contentColor)
        uiView.setPowerLevel(powerLevel)
        uiView.setDurationText(durationText)
    }

    static func dismantleUIView(_ uiView: RecorderBubbleUIView, coordinator: ()) {
        uiView.stopAnimating()
    }
}

final class RecorderBubbleUIView: UIView {
    private static let totalBars = 24
    private static let barWidth: CGFloat = 2.5
    private static let barGap: CGFloat = 3
    private static let cornerRadius: CGFloat = CGFloat(RadiusScheme.alertRadius)
    private static let amplitudeBase: CGFloat = 13
    private static let minBarHeight: CGFloat = 3
    private static let durationRightPadding: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)
    private static let minBarFrequency: CGFloat = 2.4
    private static let barFrequencySpan: CGFloat = 3.2
    private static let amplitudeBaseFactor: CGFloat = 0.45
    private static let amplitudePowerFactor: CGFloat = 0.55

    private static let pseudoUpdateInterval: CFTimeInterval = 0.08
    private static let pseudoTargetMinValue: CGFloat = 0.1
    private static let pseudoSmoothingFactor: CGFloat = 0.35

    private var bubbleColor: UIColor = .clear
    private var contentColor: UIColor = UIColor(Colors.White1)
    private var powerLevel: Int = 0
    private var isFlat = false
    private var pseudoSpeaking = false
    private var pseudoTargets: [CGFloat] = []
    private var pseudoCurrent: [CGFloat] = []
    private var pseudoTimer: CFTimeInterval = 0
    private var durationText: String = "--:--"

    private let phases: [CGFloat]
    private let freqs: [CGFloat]
    private let startTime = CACurrentMediaTime()
    private let durationFont = UIKitFontScheme.caption3Bold
    private var displayLink: CADisplayLink?

    override init(frame: CGRect) {
        var seed: UInt32 = 20260421
        func nextRandom() -> CGFloat {
            seed = (seed &* 1103515245 &+ 12345) & 0x7fffffff
            return CGFloat(seed) / CGFloat(0x7fffffff)
        }
        phases = (0..<RecorderBubbleUIView.totalBars).map { _ in nextRandom() * .pi * 2 }
        freqs = (0..<RecorderBubbleUIView.totalBars).map { _ in RecorderBubbleUIView.minBarFrequency + nextRandom() * RecorderBubbleUIView.barFrequencySpan }
        pseudoTargets = Array(repeating: 0.5, count: RecorderBubbleUIView.totalBars)
        pseudoCurrent = Array(repeating: 0.5, count: RecorderBubbleUIView.totalBars)
        super.init(frame: frame)
        backgroundColor = .clear
        startAnimating()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        stopAnimating()
    }

    func startAnimating() {
        displayLink?.invalidate()
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stopAnimating() {
        displayLink?.invalidate()
        displayLink = nil
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        let bubblePath = UIBezierPath(roundedRect: rect, cornerRadius: RecorderBubbleUIView.cornerRadius)
        ctx.addPath(bubblePath.cgPath)
        ctx.setFillColor(bubbleColor.cgColor)
        ctx.fillPath()

        let centerY = rect.height / 2
        let totalWidth = CGFloat(RecorderBubbleUIView.totalBars) * RecorderBubbleUIView.barWidth
            + CGFloat(RecorderBubbleUIView.totalBars - 1) * RecorderBubbleUIView.barGap
        let startX = (rect.width - totalWidth) / 2
        let t = CACurrentMediaTime() - startTime
        let normalizedPower = CGFloat(min(max(powerLevel, 0), 100)) / 100
        let amplitude = isFlat ? 0 : RecorderBubbleUIView.amplitudeBase * (RecorderBubbleUIView.amplitudeBaseFactor + normalizedPower * RecorderBubbleUIView.amplitudePowerFactor)

        for i in 0..<RecorderBubbleUIView.totalBars {
            let noise: CGFloat
            if pseudoSpeaking {
                noise = pseudoCurrent[i]
            } else {
                noise = abs(sin(t * Double(freqs[i]) + Double(phases[i])))
            }
            let barHeight = RecorderBubbleUIView.minBarHeight + amplitude * noise
            let x = startX + CGFloat(i) * (RecorderBubbleUIView.barWidth + RecorderBubbleUIView.barGap)
            let barRect = CGRect(x: x, y: centerY - barHeight / 2, width: RecorderBubbleUIView.barWidth, height: barHeight)
            ctx.addPath(UIBezierPath(roundedRect: barRect, cornerRadius: RecorderBubbleUIView.barWidth / 2).cgPath)
        }
        ctx.setFillColor(contentColor.cgColor)
        ctx.fillPath()

        let attributes: [NSAttributedString.Key: Any] = [
            .font: durationFont,
            .foregroundColor: contentColor,
        ]
        let textSize = (durationText as NSString).size(withAttributes: attributes)
        let isRTL = effectiveUserInterfaceLayoutDirection == .rightToLeft
        let textX = isRTL
            ? RecorderBubbleUIView.durationRightPadding
            : rect.width - RecorderBubbleUIView.durationRightPadding - textSize.width
        let textY = centerY - textSize.height / 2
        (durationText as NSString).draw(at: CGPoint(x: textX, y: textY), withAttributes: attributes)
    }

    func setBubbleColor(_ color: UIColor) {
        if bubbleColor != color {
            bubbleColor = color
            setNeedsDisplay()
        }
    }

    func setContentColor(_ color: UIColor) {
        if contentColor != color {
            contentColor = color
            setNeedsDisplay()
        }
    }

    func setPowerLevel(_ level: Int) {
        powerLevel = level
    }

    func setDurationText(_ text: String) {
        if durationText != text {
            durationText = text
            setNeedsDisplay()
        }
    }

    func setFlat(_ flat: Bool) {
        isFlat = flat
        setNeedsDisplay()
    }

    func setPseudoSpeaking(_ speaking: Bool) {
        pseudoSpeaking = speaking
        if speaking {
            isFlat = false
            startAnimating()
        } else {
            isFlat = true
            stopAnimating()
            setNeedsDisplay()
        }
    }

    @objc private func tick() {
        if pseudoSpeaking {
            updatePseudoAudio()
        }
        setNeedsDisplay()
    }

    private func updatePseudoAudio() {
        let now = CACurrentMediaTime()
        guard now - pseudoTimer > RecorderBubbleUIView.pseudoUpdateInterval else { return }
        pseudoTimer = now
        for index in 0..<RecorderBubbleUIView.totalBars {
            if Bool.random() {
                pseudoTargets[index] = CGFloat.random(in: RecorderBubbleUIView.pseudoTargetMinValue ... 1.0)
            }
            pseudoCurrent[index] += (pseudoTargets[index] - pseudoCurrent[index]) * RecorderBubbleUIView.pseudoSmoothingFactor
        }
    }
}

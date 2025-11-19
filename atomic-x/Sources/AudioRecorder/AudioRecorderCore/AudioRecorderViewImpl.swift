import AVFoundation
import AVKit
import SwiftUI

struct AudioRecorderViewImpl: View {
    @StateObject private var recorder = AudioRecorder.shared
    @Binding var shouldCancelRecording: Bool

    private let config: AudioRecorderViewConfig
    private let primaryColor: Color
    private var onRecordingComplete: ((String?, Int) -> Void)?

    @State private var animationValues: [CGFloat] = Array(repeating: 0, count: 30)
    @State private var animationTimer: Timer?
    @State private var currentTimeMs: Int = 0
    @State private var currentPower: CGFloat = 0

    init(cancelRecording: Binding<Bool>,
         config: AudioRecorderViewConfig,
         onRecordingComplete: ((String?, Int) -> Void)?) {
        self._shouldCancelRecording = cancelRecording
        self.config = config
        self.onRecordingComplete = onRecordingComplete
        self.primaryColor = Color(config.primaryColor) ?? Color.blue
    }
    //bgColorOperate
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Spacer()
                Text(shouldCancelRecording ? LocalizedChatString("VoiceSendMessageCancelDesc") : LocalizedChatString("VoiceSendMessageDesc"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(shouldCancelRecording ? .red : .secondary)
                    .multilineTextAlignment(.center)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 15)

            HStack {
                Text("\(formatDuration(currentTimeMs))")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                HStack(spacing: 3) {
                    ForEach(0..<animationValues.count, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.white)
                            .frame(width: 2, height: 6 + animationValues[index])
                    }
                }
                .frame(maxHeight: 20)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(shouldCancelRecording ? Color.red : primaryColor)
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 15)
        }
        .frame(height: 150)
        .background(Color(config.backgroundColor) ?? Color.white)
        .onAppear {
            self.recorder.onRecordingComplete = { retCode, filepath, duration in
                if retCode == .errorLessThanMinDuration {
                    WindowToastManager.shared.show(LocalizedChatString("AudioRecorderLessThanMinTime"), type: .warning, duration: 3)
                }
                
                if retCode == .exceedMaxDuration {
                    WindowToastManager.shared.show(LocalizedChatString("AudioRecordTimeLimitReached"), type: .warning, duration: 3)
                }
                onRecordingComplete?(retCode.rawValue >= 0 ? filepath : nil, duration)
            }

            self.recorder.onRecordTime = { ms in
                self.currentTimeMs = ms
            }

            self.recorder.onPowerLevel = { power in
                self.currentPower = CGFloat(power)
            }

            startWaveformAnimation()
            recorder.startRecord(enableAIDeNoise: config.enableAIDeNoise, minDurationMs: config.minDurationMs, maxDurationMs: config.maxDurationMs)
        }
        .onDisappear {
            stopWaveformAnimation()
            if shouldCancelRecording {
                recorder.cancelRecord()
            } else {
                recorder.stopRecord()
            }
        }
    }

    // MARK: - Private Helpers

    private func formatDuration(_ millisecond: Int) -> String {
        let seconds = millisecond / 1000
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }

    private func startWaveformAnimation() {
        animationValues = Array(repeating: 0, count: 30)
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            updateWaveformAnimation()
        }
    }

    private func updateWaveformAnimation() {
        let power = currentPower

        for i in 0..<animationValues.count {
            let normalizedPower = min(max(CGFloat(power + 50) * 0.3, 1), 10)
            let randomOffset = CGFloat.random(in: -2 ... 2)
            animationValues[i] = normalizedPower + randomOffset
        }
    }

    private func stopWaveformAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
}

// Local utility kept internal to implementation file
extension Color {
    init?(_ hex: String?) {
        guard let hex = hex else { return nil }

        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        var r: CGFloat = 0.0
        var g: CGFloat = 0.0
        var b: CGFloat = 0.0
        var a: CGFloat = 1.0

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        r = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
        g = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
        b = CGFloat(rgb & 0x000000FF) / 255.0

        if g + b - r < 0 { a = 0.5 }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

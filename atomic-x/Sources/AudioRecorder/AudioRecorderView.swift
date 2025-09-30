import AVFoundation
import AVKit
import SwiftUI

// To use AI noise reduction, the app must depend on TXLiteAVSDK_Professional v12.7+ and have the feature enabled.
// For enabling permissions, see documentation: https://cloud.tencent.com/document/product/269/113290
public struct AudioRecorderView: View {
    @StateObject private var recorder = AudioRecorder.shared
    @Binding var shouldCancelRecording: Bool

    private var onRecordingComplete: ((AudioRecordResultCode, String, Int) -> Void)?
    private var onTimeLimitReached: (() -> Void)?
    private let enableAIDeNoise: Bool
    private let horizontalPadding: CGFloat
    private let messageInputHeight: CGFloat
    private let primaryColor: Color
    
    @State private var animationValues: [CGFloat] = Array(repeating: 0, count: 30)
    @State private var animationTimer: Timer?
    @State private var recordingTimer: Timer?
    private let maxRecordingDuration: Int = 60 * 1000 // 60s
    
    public init(shouldCancelRecording: Binding<Bool>,
                messageInputHeight: CGFloat,
                horizontalPadding: CGFloat = 20,
                enableAIDeNoise: Bool = false,
                primary: String? = nil,
                onRecordingComplete: ((AudioRecordResultCode, String, Int) -> Void)? = nil,
                onTimeLimitReached: (() -> Void)? = nil)
    {
        self._shouldCancelRecording = shouldCancelRecording
        self.messageInputHeight = messageInputHeight
        self.horizontalPadding = horizontalPadding
        self.onRecordingComplete = onRecordingComplete
        self.onTimeLimitReached = onTimeLimitReached
        self.enableAIDeNoise = enableAIDeNoise
        self.primaryColor = Color(primary) ?? Color.blue
        print("AudioRecorderView init")
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            HStack {
                Spacer()
                Text(shouldCancelRecording ? LocalizedChatString("VoiceSendMessageCancelDesc") : LocalizedChatString("VoiceSendMessageDesc"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(shouldCancelRecording ? .red : .secondary)
                    .multilineTextAlignment(.center)
                Spacer()
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.top, 15)
            
            HStack {
                Text("\(formatDuration(recorder.currentTime))")
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
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(shouldCancelRecording ? Color.red : primaryColor)
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            )
            .padding(.horizontal, horizontalPadding)
            .padding(.bottom, 15)
        }
        .frame(height: 150)
        .background(Color.white)
        .onAppear {
            self.recorder.onRecordingComplete = onRecordingComplete
            startWaveformAnimation()
            startRecordingTimeCheck()
            recorder.startRecord(enableAIDeNoise: enableAIDeNoise)
        }
        .onDisappear {
            stopWaveformAnimation()
            stopRecordingTimeCheck()
            if shouldCancelRecording {
                recorder.cancelRecord()
            } else {
                recorder.stopRecord()
            }
        }
    }
    
    // MARK: - Private Methods

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
        let power = recorder.currentPower
        
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
    
    private func startRecordingTimeCheck() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            if recorder.currentTime >= maxRecordingDuration {
                DispatchQueue.main.async {
                    onTimeLimitReached?()
                    
                    recorder.stopRecord()
                }
                
                stopRecordingTimeCheck()
            }
        }
    }
    
    private func stopRecordingTimeCheck() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
}

extension Color {
    init?(_ hex: String?) {
        guard let hex = hex else {
            return nil
        }
        
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        var r: CGFloat = 0.0
        var g: CGFloat = 0.0
        var b: CGFloat = 0.0
        var a: CGFloat = 1.0
        
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }
        r = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
        g = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
        b = CGFloat(rgb & 0x000000FF) / 255.0
        
        // If the color is close to red, adjust the transparency
        if g + b - r < 0 {
            a = 0.5
        }
        
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

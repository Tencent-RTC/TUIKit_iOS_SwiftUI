import AtomicXCore
import SwiftUI

struct AudioMessageView: View {
    @EnvironmentObject var themeState: ThemeState
    @ObservedObject private var audioPlayer: AudioPlayer
    @State private var currentPlayTime: Double = 0
    @State private var timer: Timer?
    let messageBody: MessageBody
    let message: MessageInfo
    let messageListStore: MessageListStore
    let isLeft: Bool
    let isSelf: Bool
    let shouldHighlight: Bool
    
    init(messageBody: MessageBody, message: MessageInfo, messageListStore: MessageListStore, isLeft: Bool, isSelf: Bool, shouldHighlight: Bool, audioPlayer: AudioPlayer) {
        self.messageBody = messageBody
        self.message = message
        self.messageListStore = messageListStore
        self.isLeft = isLeft
        self.isSelf = isSelf
        self.shouldHighlight = shouldHighlight
        self.audioPlayer = audioPlayer
    }

    var body: some View {
        let duration = messageBody.soundDuration
        let isCurrentlyPlaying: Bool = {
            guard let soundPath = messageBody.soundPath,
                  audioPlayer.isPlaying,
                  let currentURL = audioPlayer.currentPlayingURL
            else {
                return false
            }
            let currentSoundURL = URL(fileURLWithPath: soundPath)
            return currentURL.path == currentSoundURL.path
        }()        
        let displayText = isCurrentlyPlaying ? formatDuration(Int(currentPlayTime)) : formatDuration(duration)
        return HStack(spacing: 12) {
            ZStack {
                Image(systemName: isCurrentlyPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelf ? themeState.colors.textColorPrimary : themeState.colors.buttonColorPrimaryDefault)
            }
            .frame(width: 32, height: 32)
            .contentShape(Rectangle())
            .onTapGesture {
                if isCurrentlyPlaying {
                    audioPlayer.pause()
                    stopTimer()
                } else {
                    if messageBody.soundPath == nil || !FileManager.default.fileExists(atPath: messageBody.soundPath!) {
                        messageListStore.downloadMessageResource(message, resourceType: .sound, completion: { result in
                            switch result {
                            case .success:
                                DispatchQueue.main.async {
                                    if let soundPath = messageBody.soundPath {
                                        let url = URL(fileURLWithPath: soundPath)
                                        self.startPlayback(url: url)
                                    }
                                }
                            case .failure(let error):
                                break
                            }
                        })
                    } else {
                        if let soundPath = messageBody.soundPath {
                            let url = URL(fileURLWithPath: soundPath)
                            startPlayback(url: url)
                        }
                    }
                }
            }
            HStack(spacing: 2) {
                ForEach(0 ..< 8, id: \.self) { index in
                    let heights: [CGFloat] = [8, 16, 12, 20, 10, 14, 17, 8]
                    RoundedRectangle(cornerRadius: 1)
                        .frame(width: 2, height: heights[index])
                        .foregroundColor(isSelf ? themeState.colors.textColorPrimary : themeState.colors.buttonColorPrimaryDefault)
                        .opacity(isCurrentlyPlaying ? 0.4 + Double(index % 3) * 0.2 : 0.6)
                        .scaleEffect(y: isCurrentlyPlaying ? (0.3 + Double(index % 4) * 0.2) : 1.0)
                        .animation(
                            isCurrentlyPlaying ?
                                .easeInOut(duration: 0.4 + Double(index) * 0.1)
                                .repeatForever(autoreverses: true) :
                                .default,
                            value: isCurrentlyPlaying
                        )
                }
            }
            .frame(height: 24)
            Text(displayText)
                .font(.system(size: 12))
                .foregroundColor(isSelf ? themeState.colors.textColorSecondary : themeState.colors.textColorSecondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .bubbleBackground(isSelf: isSelf, isLeft: isLeft, shouldHighlight: shouldHighlight)
        .onDisappear {
            stopTimer()
        }
        .onReceive(audioPlayer.$isPlaying) { isPlaying in
            if !isPlaying {
                stopTimer()
            } else {
                if let soundPath = messageBody.soundPath,
                   let currentURL = audioPlayer.currentPlayingURL {
                    let currentSoundURL = URL(fileURLWithPath: soundPath)
                    if currentURL.path == currentSoundURL.path {
                        currentPlayTime = 0  
                        startTimer()
                    }
                }
            }
        }
        .onReceive(audioPlayer.$currentPlayingURL) { currentURL in
            if let soundPath = messageBody.soundPath {
                let currentSoundURL = URL(fileURLWithPath: soundPath)
                if currentURL?.path == currentSoundURL.path {
                    if audioPlayer.isPlaying {
                        print("AudioMessageView: URL changed to current audio, starting timer")
                        currentPlayTime = 0
                        startTimer()
                    }
                } else {
                    print("AudioMessageView: URL changed to other audio, stopping timer")
                    stopTimer()
                }
            }
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
    
    private func startPlayback(url: URL) {
        print("AudioMessageView: Starting playback for \(url.lastPathComponent)")
        currentPlayTime = 0
        audioPlayer.play(url)
        startTimer()
    }
    
    private func startTimer() {
        print("AudioMessageView: Starting timer")
        stopTimer() 
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            
            if audioPlayer.isPlaying {
                currentPlayTime += 0.1
                if Int(currentPlayTime) >= messageBody.soundDuration {
                    print("AudioMessageView: Playback completed")
                    stopTimer()
                }
            } else {
                print("AudioMessageView: Player not playing, stopping timer")
                stopTimer()
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

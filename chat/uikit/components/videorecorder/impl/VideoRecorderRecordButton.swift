import SwiftUI

struct VideoRecorderRecordButton: View {
    static let size: CGFloat = 72

    private static let dotSizeNormal: CGFloat = 56

    private static let dotSizePressed: CGFloat = 20

    private static let progressSizeNormal: CGFloat = 72

    private static let progressSizePressed: CGFloat = 80

    private static let progressWidthNormal: CGFloat = 2

    private static let progressWidthPressed: CGFloat = 4

    private static let pressAnimationDuration: TimeInterval = 0.3

    private static let allowableMovement: CGFloat = 10

    let progress: CGFloat
    let progressColor: Color
    let growsProgressRingWhenPressed: Bool
    let onTap: () -> Void
    let onLongPressBegan: () -> Void
    let onLongPressEnded: () -> Void
    let onLongPressCancelled: () -> Void

    @State private var isPressed = false

    @State private var tracker = VideoRecorderPressTracker()

    @GestureState private var isTouching = false

    var body: some View {
        ZStack {
            progressRing
                .frame(width: Self.size, height: Self.size)
                .scaleEffect(ringSize / Self.size)
            Circle()
                .fill(Color.white)
                .frame(width: dotSize, height: dotSize)
        }
        .frame(width: Self.size, height: Self.size)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .updating($isTouching) { _, state, _ in
                    state = true
                }
                .onChanged(handleChanged)
                .onEnded { _ in
                    finish(cancelled: false)
                }
        )
        .onChange(of: isTouching) { touching in
            guard !touching else { return }
            DispatchQueue.main.async {
                finish(cancelled: true)
            }
        }
    }

    private var ringSize: CGFloat {
        return isPressed && growsProgressRingWhenPressed ? Self.progressSizePressed : Self.progressSizeNormal
    }

    private var dotSize: CGFloat {
        return isPressed ? Self.dotSizePressed : Self.dotSizeNormal
    }

    private var lineWidth: CGFloat {
        return isPressed ? Self.progressWidthPressed : Self.progressWidthNormal
    }

    private var progressRing: some View {
        ZStack {
            Circle()
                .inset(by: lineWidth / 2)
                .stroke(Color.white, lineWidth: lineWidth)
            Circle()
                .inset(by: lineWidth / 2)
                .trim(from: 0, to: progress)
                .stroke(progressColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                .rotationEffect(.degrees(-90))
        }
    }

    private func handleChanged(_ value: DragGesture.Value) {
        if !tracker.isTracking {
            tracker.begin(after: Self.pressAnimationDuration, onLongPress: onLongPressBegan)
            withAnimation(.easeInOut(duration: Self.pressAnimationDuration)) {
                isPressed = true
            }
            return
        }
        let distance = hypot(value.translation.width, value.translation.height)
        if distance > Self.allowableMovement {
            tracker.failIfPending()
        }
    }

    private func finish(cancelled: Bool) {
        guard tracker.isTracking else { return }
        let phase = tracker.end()
        withAnimation(.easeInOut(duration: Self.pressAnimationDuration)) {
            isPressed = false
        }
        switch phase {
        case .longPress:
            cancelled ? onLongPressCancelled() : onLongPressEnded()
        case .pending:
            if !cancelled {
                onTap()
            }
        case .failed, .idle:
            break
        }
    }
}

final class VideoRecorderPressTracker {
    enum Phase {
        case idle
        case pending
        case longPress
        case failed
    }

    private(set) var phase: Phase = .idle

    private var longPressWorkItem: DispatchWorkItem?

    var isTracking: Bool {
        return phase != .idle
    }

    func begin(after delay: TimeInterval, onLongPress: @escaping () -> Void) {
        phase = .pending
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self, self.phase == .pending else { return }
            self.phase = .longPress
            onLongPress()
        }
        longPressWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    func failIfPending() {
        guard phase == .pending else { return }
        longPressWorkItem?.cancel()
        longPressWorkItem = nil
        phase = .failed
    }

    func end() -> Phase {
        let endedPhase = phase
        longPressWorkItem?.cancel()
        longPressWorkItem = nil
        phase = .idle
        return endedPhase
    }
}

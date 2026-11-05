#if os(iOS)
import SwiftUI
import UIKit

// MARK: - Settings

enum TrackpadSettings {
    static let pointerSpeedKey  = "tapp.pointerSpeed"
    static let scrollSpeedKey   = "tapp.scrollSpeed"
    static let naturalScrollKey = "tapp.naturalScroll"

    static let defaultPointerSpeed: Double = 1.6
    static let defaultScrollSpeed: Double  = 1.6
}

/// Feedback events the touch surface reports back to SwiftUI for visuals.
enum TrackpadFeedback {
    case leftClick(CGPoint)
    case rightClick(CGPoint)
    case dragBegan(CGPoint)
    case dragEnded
    case touching(Bool)
}

// MARK: - SwiftUI Trackpad

/// The virtual trackpad, behaving like a Mac trackpad:
/// - 1 finger drag  → move the pointer
/// - 1 finger tap   → left click (tap twice quickly → double click)
/// - 2 finger tap   → right click
/// - 2 finger drag  → scroll (with inertia)
/// - press & hold, then drag → click-and-drag (selection, moving windows…)
struct TrackpadView: View {
    let inputSender: InputSender

    @AppStorage(TrackpadSettings.pointerSpeedKey)  private var pointerSpeed = TrackpadSettings.defaultPointerSpeed
    @AppStorage(TrackpadSettings.scrollSpeedKey)   private var scrollSpeed  = TrackpadSettings.defaultScrollSpeed
    @AppStorage(TrackpadSettings.naturalScrollKey) private var naturalScroll = true

    @State private var ripples: [Ripple] = []
    @State private var isTouching = false
    @State private var isDragLocked = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(isTouching ? 0.075 : 0.045))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(isDragLocked ? Color.accentColor.opacity(0.8)
                                                   : Color.white.opacity(isTouching ? 0.14 : 0.07),
                                      lineWidth: isDragLocked ? 2 : 1)
                )
                .animation(.easeInOut(duration: 0.18), value: isTouching)
                .animation(.easeInOut(duration: 0.18), value: isDragLocked)

            if !isTouching {
                hints.transition(.opacity)
            }

            if isDragLocked {
                VStack {
                    Label("Trascinamento", systemImage: "hand.draw.fill")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                        .padding(.top, 12)
                    Spacer()
                }
            }

            ForEach(ripples) { ripple in
                RippleView(ripple: ripple)
            }

            TrackpadSurface(
                inputSender: inputSender,
                pointerSpeed: CGFloat(pointerSpeed),
                scrollSpeed: CGFloat(scrollSpeed),
                naturalScroll: naturalScroll,
                onFeedback: handleFeedback
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var hints: some View {
        VStack(spacing: 10) {
            Text("TRACKPAD")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .tracking(4)
                .foregroundColor(.white.opacity(0.18))
            HStack(spacing: 14) {
                hint("hand.tap", "Click")
                hint("hand.tap.fill", "2 dita: destro")
                hint("arrow.up.and.down", "2 dita: scroll")
                hint("hand.draw", "Tieni: trascina")
            }
        }
        .allowsHitTesting(false)
    }

    private func hint(_ icon: String, _ text: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 13))
            Text(text).font(.system(size: 9, weight: .medium, design: .rounded))
        }
        .foregroundColor(.white.opacity(0.22))
    }

    private func handleFeedback(_ feedback: TrackpadFeedback) {
        switch feedback {
        case .leftClick(let p):  addRipple(at: p, color: .white)
        case .rightClick(let p): addRipple(at: p, color: .orange)
        case .dragBegan(let p):
            isDragLocked = true
            addRipple(at: p, color: .accentColor)
        case .dragEnded:
            isDragLocked = false
        case .touching(let t):
            withAnimation(.easeInOut(duration: 0.15)) { isTouching = t }
        }
    }

    private func addRipple(at point: CGPoint, color: Color) {
        let ripple = Ripple(position: point, color: color)
        ripples.append(ripple)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            ripples.removeAll { $0.id == ripple.id }
        }
    }
}

// MARK: - Ripple

private struct Ripple: Identifiable {
    let id = UUID()
    let position: CGPoint
    let color: Color
}

private struct RippleView: View {
    let ripple: Ripple
    @State private var animate = false

    var body: some View {
        Circle()
            .fill(ripple.color.opacity(0.4))
            .frame(width: 56, height: 56)
            .scaleEffect(animate ? 1.9 : 0.4)
            .opacity(animate ? 0 : 1)
            .position(ripple.position)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.easeOut(duration: 0.45)) { animate = true }
            }
    }
}

// MARK: - UIKit multi-touch surface

private struct TrackpadSurface: UIViewRepresentable {
    let inputSender: InputSender
    let pointerSpeed: CGFloat
    let scrollSpeed: CGFloat
    let naturalScroll: Bool
    let onFeedback: (TrackpadFeedback) -> Void

    func makeUIView(context: Context) -> TrackpadTouchView {
        let view = TrackpadTouchView()
        configure(view)
        return view
    }

    func updateUIView(_ view: TrackpadTouchView, context: Context) {
        configure(view)
    }

    private func configure(_ view: TrackpadTouchView) {
        view.send = { [inputSender] packet in inputSender.send(packet) }
        view.pointerSpeed = pointerSpeed
        view.scrollSpeed = scrollSpeed
        view.naturalScroll = naturalScroll
        view.onFeedback = onFeedback
    }
}

final class TrackpadTouchView: UIView {

    // Configuration
    var send: (TappPacket) -> Void = { _ in }
    var onFeedback: (TrackpadFeedback) -> Void = { _ in }
    var pointerSpeed: CGFloat = 1.6
    var scrollSpeed: CGFloat = 1.6
    var naturalScroll = true

    // Tunables
    private let moveThreshold: CGFloat = 6        // pt before a touch counts as movement
    private let tapMaxDuration: TimeInterval = 0.28
    private let holdToDragDelay: TimeInterval = 0.45

    // Gesture state
    private var activeTouches = Set<UITouch>()
    private var maxTouchCount = 0
    private var gestureStart: TimeInterval = 0
    private var startCentroid: CGPoint = .zero
    private var lastCentroid: CGPoint = .zero
    private var hasMoved = false
    private var isDragging = false
    private var holdTimer: Timer?

    // Scroll & inertia
    private var scrollVelocity: CGPoint = .zero      // pt / s
    private var lastScrollTime: TimeInterval = 0
    private var momentumLink: CADisplayLink?
    private var lastMomentumTime: CFTimeInterval = 0
    private var scrollRemainder: CGPoint = .zero

    // Haptics
    private let lightHaptic  = UIImpactFeedbackGenerator(style: .light)
    private let mediumHaptic = UIImpactFeedbackGenerator(style: .medium)
    private let rigidHaptic  = UIImpactFeedbackGenerator(style: .rigid)

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        stopMomentum()
        let wasEmpty = activeTouches.isEmpty
        activeTouches.formUnion(touches)

        if wasEmpty {
            maxTouchCount = 0
            gestureStart = CACurrentMediaTime()
            hasMoved = false
            scrollVelocity = .zero
            scrollRemainder = .zero
            mediumHaptic.prepare()
            onFeedback(.touching(true))
        }
        maxTouchCount = max(maxTouchCount, activeTouches.count)
        startCentroid = centroid()
        lastCentroid = startCentroid

        holdTimer?.invalidate()
        if activeTouches.count == 1 && !isDragging {
            holdTimer = Timer.scheduledTimer(withTimeInterval: holdToDragDelay, repeats: false) { [weak self] _ in
                self?.beginDragIfStill()
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        let current = centroid()
        let delta = CGPoint(x: current.x - lastCentroid.x, y: current.y - lastCentroid.y)
        lastCentroid = current

        if !hasMoved {
            let total = hypot(current.x - startCentroid.x, current.y - startCentroid.y)
            guard total > moveThreshold else { return }
            hasMoved = true
            holdTimer?.invalidate()
        }

        if maxTouchCount >= 2 && !isDragging {
            // Two-finger gesture → scroll (ignore leftover finger after one lifts)
            guard activeTouches.count >= 2 else { return }
            sendScroll(fingerDelta: delta)
        } else {
            sendMove(delta: delta)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        endTouches(touches, cancelled: false)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        endTouches(touches, cancelled: true)
    }

    private func endTouches(_ touches: Set<UITouch>, cancelled: Bool) {
        let lastPoint = touches.first?.location(in: self) ?? lastCentroid
        activeTouches.subtract(touches)
        if !activeTouches.isEmpty {
            // Re-base centroid so remaining fingers don't produce a jump
            lastCentroid = centroid()
            return
        }

        holdTimer?.invalidate()
        onFeedback(.touching(false))

        if isDragging {
            isDragging = false
            send(.leftUp())
            lightHaptic.impactOccurred()
            onFeedback(.dragEnded)
        } else if !cancelled && !hasMoved && CACurrentMediaTime() - gestureStart < tapMaxDuration {
            if maxTouchCount >= 2 {
                send(.rightClick())
                rigidHaptic.impactOccurred()
                onFeedback(.rightClick(startCentroid))
            } else {
                send(.leftClick())
                mediumHaptic.impactOccurred()
                onFeedback(.leftClick(lastPoint))
            }
        } else if maxTouchCount >= 2 && hasMoved {
            startMomentumIfNeeded()
        }
    }

    // MARK: Pointer

    private func sendMove(delta: CGPoint) {
        // Simple acceleration curve: slow moves are precise, fast flicks travel far
        let speed = hypot(delta.x, delta.y)
        let gain = pointerSpeed * (0.8 + min(speed, 40) * 0.07)
        send(.mouseMove(deltaX: Float(delta.x * gain), deltaY: Float(delta.y * gain)))
    }

    private func beginDragIfStill() {
        guard activeTouches.count == 1, maxTouchCount == 1, !hasMoved, !isDragging else { return }
        isDragging = true
        send(.leftDown())
        mediumHaptic.impactOccurred(intensity: 1.0)
        onFeedback(.dragBegan(lastCentroid))
    }

    // MARK: Scroll

    private func sendScroll(fingerDelta: CGPoint) {
        let direction: CGFloat = naturalScroll ? 1 : -1
        let d = CGPoint(x: fingerDelta.x * scrollSpeed * direction,
                        y: fingerDelta.y * scrollSpeed * direction)
        emitScroll(d)

        // Track velocity for inertia (exponentially smoothed)
        let now = CACurrentMediaTime()
        let dt = max(now - lastScrollTime, 1.0 / 120.0)
        lastScrollTime = now
        if dt < 0.1 {
            let instant = CGPoint(x: d.x / dt, y: d.y / dt)
            scrollVelocity = CGPoint(x: scrollVelocity.x * 0.6 + instant.x * 0.4,
                                     y: scrollVelocity.y * 0.6 + instant.y * 0.4)
        } else {
            scrollVelocity = .zero
        }
    }

    /// Sends whole-pixel scroll deltas, carrying fractional remainders over.
    private func emitScroll(_ d: CGPoint) {
        let total = CGPoint(x: d.x + scrollRemainder.x, y: d.y + scrollRemainder.y)
        let whole = CGPoint(x: total.x.rounded(.towardZero), y: total.y.rounded(.towardZero))
        scrollRemainder = CGPoint(x: total.x - whole.x, y: total.y - whole.y)
        guard whole.x != 0 || whole.y != 0 else { return }
        send(.scroll(deltaX: Float(whole.x), deltaY: Float(whole.y)))
    }

    private func startMomentumIfNeeded() {
        // Ignore if the fingers rested before lifting
        guard CACurrentMediaTime() - lastScrollTime < 0.08,
              hypot(scrollVelocity.x, scrollVelocity.y) > 150 else { return }
        lastMomentumTime = CACurrentMediaTime()
        let link = CADisplayLink(target: self, selector: #selector(momentumStep(_:)))
        link.add(to: .main, forMode: .common)
        momentumLink = link
    }

    @objc private func momentumStep(_ link: CADisplayLink) {
        let now = link.timestamp
        let dt = min(now - lastMomentumTime, 1.0 / 30.0)
        lastMomentumTime = now
        let decay = pow(0.94, dt * 60)
        scrollVelocity = CGPoint(x: scrollVelocity.x * decay, y: scrollVelocity.y * decay)
        if hypot(scrollVelocity.x, scrollVelocity.y) < 25 {
            stopMomentum()
            return
        }
        emitScroll(CGPoint(x: scrollVelocity.x * dt, y: scrollVelocity.y * dt))
    }

    private func stopMomentum() {
        momentumLink?.invalidate()
        momentumLink = nil
    }

    // MARK: Helpers

    private func centroid() -> CGPoint {
        guard !activeTouches.isEmpty else { return lastCentroid }
        var sum = CGPoint.zero
        for t in activeTouches {
            let p = t.location(in: self)
            sum.x += p.x; sum.y += p.y
        }
        let n = CGFloat(activeTouches.count)
        return CGPoint(x: sum.x / n, y: sum.y / n)
    }

    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        if newWindow == nil {
            stopMomentum()
            holdTimer?.invalidate()
            if isDragging { isDragging = false; send(.leftUp()) }
        }
    }
}
#endif

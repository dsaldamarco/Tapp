#if os(macOS)
import Foundation
import AppKit
import CoreGraphics
import ApplicationServices

/// Injects real keyboard, mouse and scroll events into macOS using CoreGraphics.
final class EventInjector {

    private let eventSource = CGEventSource(stateID: .hidSystemState)

    // Drag state
    private var isLeftButtonDown = false

    // Double / triple click detection
    private var lastClickTime: TimeInterval = 0
    private var lastClickPosition: CGPoint = .zero
    private var clickCount: Int64 = 0

    // MARK: - Keyboard

    func keyDown(keyCode: UInt16, modifiers: KeyModifiers) {
        postKeyEvent(keyCode: keyCode, keyDown: true, modifiers: modifiers)
    }

    func keyUp(keyCode: UInt16, modifiers: KeyModifiers) {
        postKeyEvent(keyCode: keyCode, keyDown: false, modifiers: modifiers)
    }

    private func postKeyEvent(keyCode: UInt16, keyDown: Bool, modifiers: KeyModifiers) {
        guard let event = CGEvent(keyboardEventSource: eventSource,
                                  virtualKey: CGKeyCode(keyCode),
                                  keyDown: keyDown) else { return }
        event.flags = cgFlags(from: modifiers)
        event.post(tap: .cghidEventTap)
    }

    /// Types arbitrary Unicode text (accents, emoji, any keyboard layout).
    func typeText(_ text: String) {
        for character in text {
            switch character {
            case "\n", "\r":
                tapKey(36)              // Return
            case "\t":
                tapKey(48)              // Tab
            default:
                let utf16 = Array(String(character).utf16)
                guard let down = CGEvent(keyboardEventSource: eventSource, virtualKey: 0, keyDown: true),
                      let up   = CGEvent(keyboardEventSource: eventSource, virtualKey: 0, keyDown: false)
                else { continue }
                down.flags = []
                up.flags = []
                down.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
                up.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
                down.post(tap: .cghidEventTap)
                up.post(tap: .cghidEventTap)
            }
        }
    }

    private func tapKey(_ keyCode: UInt16) {
        postKeyEvent(keyCode: keyCode, keyDown: true, modifiers: [])
        postKeyEvent(keyCode: keyCode, keyDown: false, modifiers: [])
    }

    // MARK: - Mouse Movement (relative)

    func mouseMove(deltaX: CGFloat, deltaY: CGFloat) {
        let current = currentCGMousePosition()
        let target = clampToDisplays(CGPoint(x: current.x + deltaX, y: current.y + deltaY))

        let type: CGEventType = isLeftButtonDown ? .leftMouseDragged : .mouseMoved
        guard let event = CGEvent(mouseEventSource: eventSource,
                                  mouseType: type,
                                  mouseCursorPosition: target,
                                  mouseButton: .left) else { return }
        event.setIntegerValueField(.mouseEventDeltaX, value: Int64(deltaX.rounded()))
        event.setIntegerValueField(.mouseEventDeltaY, value: Int64(deltaY.rounded()))
        event.post(tap: .cghidEventTap)

        // Make sure the visible cursor follows even in apps that ignore synthetic moves
        CGWarpMouseCursorPosition(target)
    }

    // MARK: - Scrolling

    /// Pixel-precise, continuous (trackpad-like) scrolling.
    func scroll(deltaX: CGFloat, deltaY: CGFloat) {
        guard let event = CGEvent(scrollWheelEvent2Source: eventSource,
                                  units: .pixel,
                                  wheelCount: 2,
                                  wheel1: Int32(deltaY.rounded()),
                                  wheel2: Int32(deltaX.rounded()),
                                  wheel3: 0) else { return }
        event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
        event.location = currentCGMousePosition()
        event.post(tap: .cghidEventTap)
    }

    // MARK: - Mouse Clicks

    func leftClick() {
        let pos = currentCGMousePosition()
        let count = nextClickCount(at: pos)
        postMouseEvent(type: .leftMouseDown, pos: pos, clickCount: count)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { [weak self] in
            guard let self else { return }
            self.postMouseEvent(type: .leftMouseUp, pos: self.currentCGMousePosition(), clickCount: count)
        }
    }

    func rightClick() {
        let pos = currentCGMousePosition()
        postMouseEvent(type: .rightMouseDown, pos: pos, clickCount: 1)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { [weak self] in
            guard let self else { return }
            self.postMouseEvent(type: .rightMouseUp, pos: self.currentCGMousePosition(), clickCount: 1)
        }
    }

    func leftDown() {
        guard !isLeftButtonDown else { return }
        isLeftButtonDown = true
        postMouseEvent(type: .leftMouseDown, pos: currentCGMousePosition(), clickCount: 1)
    }

    func leftUp() {
        guard isLeftButtonDown else { return }
        isLeftButtonDown = false
        postMouseEvent(type: .leftMouseUp, pos: currentCGMousePosition(), clickCount: 1)
    }

    /// Called when the iPhone disconnects, so no button stays stuck down.
    func releaseAll() {
        leftUp()
    }

    private func postMouseEvent(type: CGEventType, pos: CGPoint, clickCount: Int64) {
        let button: CGMouseButton = (type == .rightMouseDown || type == .rightMouseUp) ? .right : .left
        guard let event = CGEvent(mouseEventSource: eventSource,
                                  mouseType: type,
                                  mouseCursorPosition: pos,
                                  mouseButton: button) else { return }
        // Click state is required for apps to recognise (double) clicks
        event.setIntegerValueField(.mouseEventClickState, value: clickCount)
        event.post(tap: .cghidEventTap)
    }

    private func nextClickCount(at pos: CGPoint) -> Int64 {
        let now = ProcessInfo.processInfo.systemUptime
        let distance = hypot(pos.x - lastClickPosition.x, pos.y - lastClickPosition.y)
        if now - lastClickTime <= NSEvent.doubleClickInterval && distance < 6 {
            clickCount = min(clickCount + 1, 3)
        } else {
            clickCount = 1
        }
        lastClickTime = now
        lastClickPosition = pos
        return clickCount
    }

    // MARK: - Helpers

    /// Current cursor position in global CoreGraphics coordinates (origin top-left of main display).
    private func currentCGMousePosition() -> CGPoint {
        CGEvent(source: nil)?.location ?? .zero
    }

    /// Keeps the cursor inside the union of all active displays (multi-monitor aware).
    private func clampToDisplays(_ point: CGPoint) -> CGPoint {
        var count: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &count)
        guard count > 0 else { return point }
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetActiveDisplayList(count, &displays, &count)
        let bounds = displays.map { CGDisplayBounds($0) }

        if bounds.contains(where: { $0.contains(point) }) { return point }

        // Snap to the closest point on the nearest display
        var best = point
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for b in bounds {
            let p = CGPoint(x: min(max(point.x, b.minX), b.maxX - 1),
                            y: min(max(point.y, b.minY), b.maxY - 1))
            let d = hypot(p.x - point.x, p.y - point.y)
            if d < bestDistance { bestDistance = d; best = p }
        }
        return best
    }

    private func cgFlags(from modifiers: KeyModifiers) -> CGEventFlags {
        var flags: CGEventFlags = []
        if modifiers.contains(.command)  { flags.insert(.maskCommand) }
        if modifiers.contains(.shift)    { flags.insert(.maskShift) }
        if modifiers.contains(.option)   { flags.insert(.maskAlternate) }
        if modifiers.contains(.control)  { flags.insert(.maskControl) }
        if modifiers.contains(.capsLock) { flags.insert(.maskAlphaShift) }
        return flags
    }
}
#endif

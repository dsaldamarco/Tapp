#if os(iOS)
import SwiftUI
import UIKit

// MARK: - System keyboard capture

/// An invisible view that summons the native iPhone keyboard and forwards
/// every keystroke (text, backspace, return) instead of editing a text field.
struct SystemKeyboardCapture: UIViewRepresentable {
    @Binding var isActive: Bool
    let onText: (String) -> Void
    let onDelete: () -> Void

    func makeUIView(context: Context) -> KeyCaptureView {
        let view = KeyCaptureView()
        view.onText = onText
        view.onDelete = onDelete
        view.onResign = { DispatchQueue.main.async { isActive = false } }
        return view
    }

    func updateUIView(_ view: KeyCaptureView, context: Context) {
        view.onText = onText
        view.onDelete = onDelete
        view.onResign = { DispatchQueue.main.async { isActive = false } }
        DispatchQueue.main.async {
            if isActive && !view.isFirstResponder {
                view.becomeFirstResponder()
            } else if !isActive && view.isFirstResponder {
                view.resignFirstResponder()
            }
        }
    }

    static func dismantleUIView(_ view: KeyCaptureView, coordinator: ()) {
        view.onResign = nil
        view.resignFirstResponder()
    }
}

final class KeyCaptureView: UIView, UIKeyInput {
    var onText: (String) -> Void = { _ in }
    var onDelete: () -> Void = {}
    var onResign: (() -> Void)?

    // Plain keyboard: no autocorrect, no smart punctuation — every key goes straight to the Mac
    var autocorrectionType: UITextAutocorrectionType = .no
    var autocapitalizationType: UITextAutocapitalizationType = .none
    var spellCheckingType: UITextSpellCheckingType = .no
    var smartQuotesType: UITextSmartQuotesType = .no
    var smartDashesType: UITextSmartDashesType = .no
    var smartInsertDeleteType: UITextSmartInsertDeleteType = .no
    var inlinePredictionType: UITextInlinePredictionType = .no
    var keyboardType: UIKeyboardType = .default
    var keyboardAppearance: UIKeyboardAppearance = .dark
    var returnKeyType: UIReturnKeyType = .default

    override var canBecomeFirstResponder: Bool { true }

    /// Always "has text" so the backspace key keeps working (and auto-repeats).
    var hasText: Bool { true }

    func insertText(_ text: String) { onText(text) }
    func deleteBackward() { onDelete() }

    @discardableResult
    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        if result { onResign?() }
        return result
    }
}

// MARK: - Shortcut bar (keys the iPhone keyboard doesn't have)

struct ShortcutBar: View {
    @Binding var activeModifiers: KeyModifiers
    let onKey: (String) -> Void

    var body: some View {
        HStack(spacing: 5) {
            BarKey(label: "esc") { onKey("esc") }
            BarKey(label: "⇥") { onKey("⇥") }
            modifier("⌘", .command)
            modifier("⌥", .option)
            modifier("⌃", .control)
            modifier("⇧", .shift)
            BarKey(label: "←", repeats: true) { onKey("←") }
            BarKey(label: "↑", repeats: true) { onKey("↑") }
            BarKey(label: "↓", repeats: true) { onKey("↓") }
            BarKey(label: "→", repeats: true) { onKey("→") }
        }
        .padding(.horizontal, 8)
    }

    private func modifier(_ label: String, _ flag: KeyModifiers) -> some View {
        BarKey(label: label, isActive: activeModifiers.contains(flag)) {
            if activeModifiers.contains(flag) { activeModifiers.remove(flag) }
            else { activeModifiers.insert(flag) }
        }
    }
}

/// A large, forgiving key: fires on touch-down, optional auto-repeat while held.
struct BarKey: View {
    let label: String
    var isActive = false
    var repeats = false
    let action: () -> Void

    @State private var isPressed = false
    @State private var repeatTimer: Timer?

    var body: some View {
        Text(label)
            .font(.system(size: label.count > 1 ? 13 : 17, weight: .medium, design: .rounded))
            .foregroundColor(isActive ? .black : .white)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isActive ? Color.white
                                   : Color.white.opacity(isPressed ? 0.30 : 0.13))
            )
            .scaleEffect(isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.15, dampingFraction: 0.6), value: isPressed)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isPressed else { return }
                        isPressed = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        action()
                        if repeats { startRepeat() }
                    }
                    .onEnded { _ in
                        isPressed = false
                        repeatTimer?.invalidate()
                        repeatTimer = nil
                    }
            )
    }

    private func startRepeat() {
        repeatTimer?.invalidate()
        repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { _ in
            repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { _ in
                action()
            }
        }
    }
}
#endif

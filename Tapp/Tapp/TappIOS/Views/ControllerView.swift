#if os(iOS)
import SwiftUI

enum ControllerMode: String {
    case spacebar, keyboard
}

struct ControllerView: View {
    @EnvironmentObject var connectionManager: ConnectionManager
    @StateObject private var inputSender = InputSender()

    @AppStorage("tapp.controllerMode") private var modeRaw = ControllerMode.spacebar.rawValue
    @State private var activeModifiers: KeyModifiers = []
    @State private var keyboardVisible = false
    @State private var showSettings = false

    private var mode: ControllerMode { ControllerMode(rawValue: modeRaw) ?? .spacebar }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    headerBar
                        .padding(.horizontal, 16)
                        .padding(.top, 4)

                    if mode == .spacebar {
                        spacebarLayout(height: geo.size.height)
                    } else {
                        keyboardLayout
                    }
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet()
                .environmentObject(connectionManager)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            inputSender.connectionManager = connectionManager
            UIApplication.shared.isIdleTimerDisabled = true
            if mode == .keyboard { keyboardVisible = true }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onChange(of: modeRaw) { newValue in
            withAnimation(.spring(response: 0.38, dampingFraction: 0.85)) {
                keyboardVisible = (newValue == ControllerMode.keyboard.rawValue)
            }
            activeModifiers = []
        }
    }

    // MARK: - Layouts

    /// Spacebar mode — unchanged: ghost keyboard + giant space bar + trackpad.
    private func spacebarLayout(height: CGFloat) -> some View {
        VStack(spacing: 0) {
            SpacebarModeView(onSpace: { sendKey(label: "space") })
                .transition(.opacity)

            grabber

            TrackpadView(inputSender: inputSender)
                .frame(maxWidth: .infinity)
                .frame(height: height * 0.38)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
        }
    }

    /// Keyboard mode — native iPhone keyboard + shortcut keys + trackpad.
    private var keyboardLayout: some View {
        VStack(spacing: 8) {
            TrackpadView(inputSender: inputSender)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 12)
                .padding(.top, 4)

            ShortcutBar(activeModifiers: $activeModifiers, onKey: { sendKey(label: $0) })

            if !keyboardVisible {
                Button {
                    keyboardVisible = true
                } label: {
                    Label("Show Keyboard", systemImage: "keyboard")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white))
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }

            // Invisible view that owns the system keyboard
            SystemKeyboardCapture(
                isActive: $keyboardVisible,
                onText: handleTyped,
                onDelete: { sendKey(label: "⌫") }
            )
            .frame(width: 1, height: 1)
            .opacity(0.01)
        }
        .padding(.bottom, keyboardVisible ? 4 : 0)
    }

    private var grabber: some View {
        Capsule()
            .fill(Color.white.opacity(0.08))
            .frame(width: 40, height: 4)
            .padding(.vertical, 6)
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Circle().fill(Color.green).frame(width: 7, height: 7)
                    .shadow(color: .green.opacity(0.8), radius: 3)
                Text(connectionManager.connectedPeerName ?? "Connected")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            ModePicker(modeRaw: $modeRaw)

            if mode == .keyboard {
                headerButton(keyboardVisible ? "keyboard.chevron.compact.down" : "keyboard") {
                    keyboardVisible.toggle()
                }
            }

            headerButton("gearshape.fill") { showSettings = true }
        }
        .padding(.vertical, 10)
    }

    private func headerButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.white.opacity(0.1)))
        }
    }

    // MARK: - Sending

    /// Text from the iPhone keyboard. Plain text is sent as Unicode (works with
    /// accents, emoji and any Mac keyboard layout); with a modifier active it
    /// becomes a shortcut such as ⌘C.
    private func handleTyped(_ text: String) {
        inputSender.connectionManager = connectionManager
        guard !activeModifiers.isEmpty else {
            inputSender.send(.text(text))
            return
        }
        for ch in text {
            let s = String(ch)
            switch s {
            case "\n": sendKey(label: "return")
            case " ":  sendKey(label: "space")
            default:
                if let code = KeyMapping.keyCode(for: s) {
                    var mods = activeModifiers
                    if ch.isUppercase { mods.insert(.shift) }
                    tap(code: code, modifiers: mods, character: s)
                } else {
                    inputSender.send(.text(s))
                }
            }
        }
        activeModifiers = []
    }

    private func sendKey(label: String) {
        inputSender.connectionManager = connectionManager
        guard let code = KeyMapping.keyCode(for: label) else { return }
        tap(code: code, modifiers: activeModifiers, character: label)
        activeModifiers = []
    }

    private func tap(code: UInt16, modifiers: KeyModifiers, character: String) {
        inputSender.send(.keyDown(keyCode: code, modifiers: modifiers, character: character))
        inputSender.send(.keyUp(keyCode: code, modifiers: modifiers, character: character))
    }
}

// MARK: - Mode picker

private struct ModePicker: View {
    @Binding var modeRaw: String

    var body: some View {
        HStack(spacing: 2) {
            segment("Spacebar", icon: "space", mode: .spacebar)
            segment("Keyboard", icon: "keyboard", mode: .keyboard)
        }
        .padding(3)
        .background(Capsule().fill(Color.white.opacity(0.1)))
    }

    private func segment(_ title: String, icon: String, mode: ControllerMode) -> some View {
        let selected = modeRaw == mode.rawValue
        return Button {
            guard !selected else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            modeRaw = mode.rawValue
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(selected ? .black : .white.opacity(0.6))
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(Capsule().fill(selected ? Color.white : Color.clear))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Settings

private struct SettingsSheet: View {
    @EnvironmentObject var connectionManager: ConnectionManager
    @Environment(\.dismiss) private var dismiss

    @AppStorage(TrackpadSettings.pointerSpeedKey)  private var pointerSpeed = TrackpadSettings.defaultPointerSpeed
    @AppStorage(TrackpadSettings.scrollSpeedKey)   private var scrollSpeed  = TrackpadSettings.defaultScrollSpeed
    @AppStorage(TrackpadSettings.naturalScrollKey) private var naturalScroll = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Trackpad") {
                    VStack(alignment: .leading) {
                        Text("Pointer speed")
                        Slider(value: $pointerSpeed, in: 0.6...3.5)
                    }
                    VStack(alignment: .leading) {
                        Text("Scroll speed")
                        Slider(value: $scrollSpeed, in: 0.5...4)
                    }
                    Toggle("Natural scrolling", isOn: $naturalScroll)
                    Button("Restore Defaults") {
                        pointerSpeed = TrackpadSettings.defaultPointerSpeed
                        scrollSpeed = TrackpadSettings.defaultScrollSpeed
                        naturalScroll = true
                    }
                }

                Section("Gestures") {
                    gestureRow("hand.point.up.left", "1 finger", "Move the pointer")
                    gestureRow("hand.tap", "Tap", "Left click (tap twice to double-click)")
                    gestureRow("hand.tap.fill", "Two-finger tap", "Right click")
                    gestureRow("arrow.up.and.down.and.arrow.left.and.right", "Two fingers", "Scroll")
                    gestureRow("hand.draw", "Press, hold and move", "Drag / select")
                }

                Section {
                    Button("Disconnect", role: .destructive) {
                        dismiss()
                        connectionManager.disconnect()
                    }
                } footer: {
                    Text("Connected to \(connectionManager.connectedPeerName ?? "Mac")")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func gestureRow(_ icon: String, _ title: String, _ subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .frame(width: 28)
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .medium))
                Text(subtitle).font(.system(size: 13)).foregroundColor(.secondary)
            }
        }
    }
}
#endif

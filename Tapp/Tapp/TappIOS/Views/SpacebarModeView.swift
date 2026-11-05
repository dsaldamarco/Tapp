#if os(iOS)
import SwiftUI

/// Spacebar Mode keyboard — ghost rows (non-interactive) + huge Space button
struct SpacebarModeView: View {
    let onSpace: () -> Void
    @State private var spacePressed = false

    private let ghostRows: [[String]] = [
        ["esc","1","2","3","4","5","6","7","8","9","0","⌫"],
        ["⇥","q","w","e","r","t","y","u","i","o","p"],
        ["⇪","a","s","d","f","g","h","j","k","l","⏎"],
        ["⇧","z","x","c","v","b","n","m",",",".","⇧"],
    ]

    var body: some View {
        VStack(spacing: 6) {
            // Ghost (visual-only) keyboard rows
            VStack(spacing: 4) {
                ForEach(ghostRows, id: \.self) { row in
                    HStack(spacing: 3) {
                        ForEach(row, id: \.self) { key in
                            Text(key)
                                .font(.system(size: 10, weight: .regular, design: .monospaced))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 26)
                                .background(Color.white.opacity(0.07))
                                .cornerRadius(5)
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .opacity(0.28)
            .allowsHitTesting(false)

            // ─── Huge Space Bar ───
            spaceBar
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
    }

    private var spaceBar: some View {
        ZStack {
            // Outer glow
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(spacePressed ? 0.18 : 0.0))
                .blur(radius: 12)
                .scaleEffect(spacePressed ? 1.04 : 1.0)

            // Main body
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(
                    colors: spacePressed
                        ? [Color.white.opacity(0.22), Color.white.opacity(0.14)]
                        : [Color.white.opacity(0.14), Color.white.opacity(0.09)],
                    startPoint: .top, endPoint: .bottom
                ))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(Color.white.opacity(spacePressed ? 0.35 : 0.12), lineWidth: 1)
                )
                .frame(height: 80)
                .overlay(
                    VStack(spacing: 4) {
                        Text("SPACE")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(spacePressed ? 1.0 : 0.75))
                            .tracking(4)
                        Text("tap to press")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundColor(.white.opacity(0.3))
                    }
                )
        }
        .scaleEffect(spacePressed ? 0.96 : 1.0)
        .animation(.spring(response: 0.15, dampingFraction: 0.6), value: spacePressed)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !spacePressed {
                        spacePressed = true
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                        onSpace()
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                        spacePressed = false
                    }
                }
        )
    }
}
#endif

import SwiftUI

enum Theme {
    static let background = Color(red: 0.039, green: 0.043, blue: 0.047)
    static let text = Color(red: 0.80, green: 0.83, blue: 0.80)
    static let dim = Color(red: 0.43, green: 0.47, blue: 0.45)
    static let faint = Color.white.opacity(0.10)

    /// One accent per state: keyboard live, keyboard locked, something needs attention.
    static let live = Color(red: 0.45, green: 0.90, blue: 0.62)
    static let locked = Color(red: 1.00, green: 0.72, blue: 0.30)
    static let alert = Color(red: 1.00, green: 0.42, blue: 0.37)

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

/// A full-width outlined block, the one control in the window.
struct TerminalButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        Surface(configuration: configuration, tint: tint)
    }

    private struct Surface: View {
        let configuration: Configuration
        let tint: Color
        @Environment(\.isEnabled) private var isEnabled
        @ViewState private var isHovered = false

        var body: some View {
            configuration.label
                .font(Theme.mono(13, weight: .medium))
                .foregroundStyle(tint)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(tint.opacity(fillOpacity), in: shape)
                .overlay(shape.strokeBorder(tint.opacity(0.65), lineWidth: 1))
                .contentShape(shape)
                .opacity(isEnabled ? 1 : 0.35)
                .onHover { isHovered = $0 }
                .animation(.easeOut(duration: 0.12), value: isHovered)
        }

        private var shape: RoundedRectangle {
            RoundedRectangle(cornerRadius: 4)
        }

        private var fillOpacity: Double {
            if configuration.isPressed { return 0.26 }
            return isHovered && isEnabled ? 0.15 : 0.07
        }
    }
}

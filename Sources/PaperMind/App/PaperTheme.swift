import SwiftUI
import AppKit

enum PaperTheme {
    static let accent = Color(red: 0.55, green: 0.29, blue: 0.18)

    static func canvas(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.105, green: 0.098, blue: 0.086)
            : Color(red: 0.91, green: 0.88, blue: 0.81)
    }

    static func sheet(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.145, green: 0.132, blue: 0.112)
            : Color(red: 0.975, green: 0.956, blue: 0.905)
    }

    static func raisedSheet(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.18, green: 0.16, blue: 0.135)
            : Color(red: 0.995, green: 0.982, blue: 0.945)
    }

    static func ink(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.90, green: 0.86, blue: 0.76)
            : Color(red: 0.19, green: 0.16, blue: 0.12)
    }

    static func rule(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.33, green: 0.29, blue: 0.23)
            : Color(red: 0.72, green: 0.66, blue: 0.54)
    }

    static func selection(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.34, green: 0.23, blue: 0.16)
            : Color(red: 0.91, green: 0.82, blue: 0.65)
    }

    static func nsCanvas(for appearance: NSAppearance?) -> NSColor {
        let isDark = appearance?.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark
            ? NSColor(red: 0.105, green: 0.098, blue: 0.086, alpha: 1)
            : NSColor(red: 0.91, green: 0.88, blue: 0.81, alpha: 1)
    }
}

struct PaperGrain: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Canvas { context, size in
            let color = colorScheme == .dark
                ? Color.white.opacity(0.035)
                : Color(red: 0.35, green: 0.27, blue: 0.16).opacity(0.035)

            for x in stride(from: 7.0, through: size.width, by: 23.0) {
                for y in stride(from: 11.0, through: size.height, by: 29.0) {
                    let offset = (Int(x + y) % 17)
                    let rect = CGRect(
                        x: x + CGFloat(offset) * 0.23,
                        y: y + CGFloat(offset) * 0.17,
                        width: 0.7,
                        height: 0.7
                    )
                    context.fill(Path(ellipseIn: rect), with: .color(color))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct PaperSurface: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let raised: Bool

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    raised
                        ? PaperTheme.raisedSheet(for: colorScheme)
                        : PaperTheme.sheet(for: colorScheme)
                    PaperGrain()
                }
            )
    }
}

extension View {
    func paperSurface(raised: Bool = false) -> some View {
        modifier(PaperSurface(raised: raised))
    }
}

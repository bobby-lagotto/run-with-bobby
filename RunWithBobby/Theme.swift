import SwiftUI

// MARK: - Color Palette
extension Color {
    // Brand Primary - Headband Red
    static let bobbyRed = Color(hex: "D94545")
    static let bobbyRedDark = Color(hex: "E06060")

    // Brand Secondary - Poodle Caramel
    static let bobbyCaramel = Color(hex: "C4884D")
    static let bobbyCaramelLight = Color(hex: "D9A96A")

    // Text Colors
    static let bobbyCharcoal = Color(hex: "2C1810")
    static let bobbyDarkBrown = Color(hex: "3D2518")
    static let bobbyWarmGray = Color(hex: "8C7B73")

    // Backgrounds - Light
    static let bobbyBackground = Color(hex: "FBF9F7")
    static let bobbyCardBackground = Color.white
    static let bobbyGroupedBackground = Color(hex: "F5F0EB")

    // Backgrounds - Dark
    static let bobbyBackgroundDark = Color(hex: "1C1412")
    static let bobbyCardBackgroundDark = Color(hex: "2A1F1A")
    static let bobbyGroupedBackgroundDark = Color(hex: "231A15")

    // Message Bubbles
    static let bobbyUserBubble = Color(hex: "D94545")
    static let bobbyAIBubble = Color(hex: "F5F0EB")
    static let bobbyAIBubbleDark = Color(hex: "2A1F1A")

    // Workout Type Colors (refined)
    static let workoutRest = Color(hex: "8C7B73")
    static let workoutEasy = Color(hex: "5BA65B")
    static let workoutTempo = Color(hex: "D9973B")
    static let workoutIntervals = Color(hex: "D94545")
    static let workoutLong = Color(hex: "9B6DB5")
    static let workoutRecovery = Color(hex: "5B9EC4")

    // Hex initializer
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255
        )
    }
}

// MARK: - Theme Constants
struct BobbyTheme {
    // Corner Radius
    static let cornerRadiusLarge: CGFloat = 22
    static let cornerRadiusCard: CGFloat = 16
    static let cornerRadiusSmall: CGFloat = 12
    static let cornerRadiusPill: CGFloat = 20

    // Adaptive Colors
    static func background(for scheme: ColorScheme) -> Color {
        scheme == .dark ? .bobbyBackgroundDark : .bobbyBackground
    }

    static func cardBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark ? .bobbyCardBackgroundDark : .bobbyCardBackground
    }

    static func groupedBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark ? .bobbyGroupedBackgroundDark : .bobbyGroupedBackground
    }

    static func primaryText(for scheme: ColorScheme) -> Color {
        scheme == .dark ? .white : .bobbyCharcoal
    }

    static func secondaryText(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.6) : .bobbyWarmGray
    }

    static func aiBubble(for scheme: ColorScheme) -> Color {
        scheme == .dark ? .bobbyAIBubbleDark : .bobbyAIBubble
    }

    static func accentColor(for scheme: ColorScheme) -> Color {
        scheme == .dark ? .bobbyRedDark : .bobbyRed
    }
}

// MARK: - Card Modifier
struct BobbyCardModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(BobbyTheme.cardBackground(for: colorScheme))
            .cornerRadius(BobbyTheme.cornerRadiusCard)
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.06), radius: 8, x: 0, y: 2)
    }
}

extension View {
    func bobbyCard() -> some View {
        modifier(BobbyCardModifier())
    }
}

// MARK: - Bubble Shape
struct BubbleShape: Shape {
    let isFromUser: Bool

    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 18
        let smallRadius: CGFloat = 4

        let tl = radius
        let tr = isFromUser ? radius : radius
        let bl = isFromUser ? radius : smallRadius
        let br = isFromUser ? smallRadius : radius

        var path = Path()
        path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.maxX - tr, y: rect.minY + tr), radius: tr, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        path.addArc(center: CGPoint(x: rect.maxX - br, y: rect.maxY - br), radius: br, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + bl, y: rect.maxY - bl), radius: bl, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        path.addArc(center: CGPoint(x: rect.minX + tl, y: rect.minY + tl), radius: tl, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.closeSubpath()

        return path
    }
}

// MARK: - Helper Views
struct StatPill: View {
    let icon: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(value)
        }
        .font(.caption2)
        .foregroundColor(.bobbyWarmGray)
    }
}

struct SectionHeader: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.bobbyWarmGray)
                .textCase(.uppercase)
                .tracking(0.5)
            Spacer()
        }
    }
}

import SwiftUI
import UIKit

extension Color {
    init(hex: String) {
        var v: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&v)
        self.init(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }
    static let bg = Color(hex: "06070B")
    static let ink = Color(hex: "F5F5F7")
    static let muted = Color(hex: "8E8E99")
    static let accent2 = Color(hex: "5E5CE6")
    // Duolingo-style feedback colors
    static let good = Color(hex: "58CC02")
    static let bad = Color(hex: "FF4B4B")
    static let gram = Color(hex: "CE82FF")
    static let pron = Color(hex: "FF9600")
    static let info = Color(hex: "1CB0F6")
    static let hair = Color.white.opacity(0.11)
}

let brandGradient = LinearGradient(colors: [.accent2, .accent], startPoint: .topLeading, endPoint: .bottomTrailing)

struct AuroraBackground: View {
    var body: some View {
        ZStack {
            Color.bg
            RadialGradient(colors: [Color.accent2.opacity(0.32), .clear], center: .init(x: 0.12, y: 0.05), startRadius: 0, endRadius: 380)
            RadialGradient(colors: [Color.info.opacity(0.18), .clear], center: .init(x: 0.95, y: 0.3), startRadius: 0, endRadius: 320)
            RadialGradient(colors: [Color.accent.opacity(0.14), .clear], center: .init(x: 0.5, y: 1.05), startRadius: 0, endRadius: 420)
        }
        .ignoresSafeArea()
    }
}

struct Glass: ViewModifier {
    var radius: CGFloat = 24
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Color.hair))
    }
}
extension View { func glass(_ r: CGFloat = 24) -> some View { modifier(Glass(radius: r)) } }

struct PrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(brandGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .accent.opacity(0.35), radius: 12, y: 6)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct GlassButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).foregroundStyle(Color.ink)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Color.white.opacity(configuration.isPressed ? 0.16 : 0.09), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.hair))
    }
}

/// Chunky Duolingo-style button with a darker "ledge" underneath.
struct DuoButton: ButtonStyle {
    var color: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline.weight(.heavy)).foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(color.mix(with: .black, by: 0.35)).offset(y: configuration.isPressed ? 0 : 4)
                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(color)
                }
            )
            .offset(y: configuration.isPressed ? 4 : 0)
    }
}

extension Color {
    func mix(with other: Color, by t: Double) -> Color {
        let a = UIColor(self), b = UIColor(other)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0, r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        guard a.getRed(&r1, green: &g1, blue: &b1, alpha: &a1), b.getRed(&r2, green: &g2, blue: &b2, alpha: &a2) else { return self }
        return Color(red: r1 + (r2 - r1) * t, green: g1 + (g2 - g1) * t, blue: b1 + (b2 - b1) * t)
    }
}

struct Chip: View {
    var text: String
    var color: Color = .info
    var body: some View {
        Text(text).font(.caption.weight(.bold)).foregroundStyle(color)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(color.opacity(0.16), in: Capsule())
    }
}

enum TipKind { case pron, gram, info
    var color: Color { switch self { case .pron: return .pron; case .gram: return .gram; case .info: return .info } }
}

struct TipBox: View {
    var kind: TipKind
    var title: String
    var bodyText: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased()).font(.caption.weight(.bold)).kerning(0.6).foregroundStyle(kind.color)
            Text(bodyText).font(.subheadline).foregroundStyle(Color.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(kind.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(kind.color.opacity(0.35)))
    }
}

struct Eyebrow: View {
    var text: String
    var body: some View { Text(text.uppercased()).font(.caption.weight(.semibold)).kerning(0.8).foregroundStyle(Color.muted) }
}

/// Korean text with Duolingo-style highlights: purple grammar, orange sound changes with [pronunciation].
struct RichKorean: View {
    var text: String
    var size: CGFloat = 22
    var blankGrammar = false

    var body: some View {
        Text(attributed).font(.system(size: size, weight: .semibold)).lineSpacing(6).foregroundStyle(Color.ink)
    }

    var attributed: AttributedString {
        var out = AttributedString()
        for t in Markup.tokens(text) {
            switch t {
            case .text(let s):
                out += AttributedString(s)
            case .gram(let g):
                var a = AttributedString(blankGrammar ? " ＿＿＿ " : g)
                a.foregroundColor = .gram
                a.backgroundColor = Color.gram.opacity(0.18)
                a.font = .system(size: size, weight: .heavy)
                out += a
            case .pron(let w, let p):
                var a = AttributedString(w)
                a.foregroundColor = .pron
                a.underlineStyle = .single
                a.font = .system(size: size, weight: .heavy)
                var b = AttributedString(" [\(p)]")
                b.foregroundColor = .pron
                b.font = .system(size: size * 0.6, weight: .bold)
                out += a; out += b
            }
        }
        return out
    }
}

/// Target text with each syllable green (heard) or red (missed).
struct SyllableDiff: View {
    var target: String
    var said: String
    var size: CGFloat = 24
    var body: some View {
        Text(attributed).font(.system(size: size, weight: .bold)).lineSpacing(4)
    }
    var attributed: AttributedString {
        var out = AttributedString()
        for (ch, hit) in Grader.diff(target: target, said: said) {
            var a = AttributedString(String(ch))
            if let hit {
                a.foregroundColor = hit ? .good : .bad
                if !hit { a.underlineStyle = Text.LineStyle(pattern: .dot, color: .bad) }
            } else { a.foregroundColor = .ink }
            out += a
        }
        return out
    }
}

struct Ring: View {
    var value: Double   // 0...1
    var label: String
    var size: CGFloat = 92
    var body: some View {
        ZStack {
            Circle().stroke(Color.hair, lineWidth: 10)
            Circle().trim(from: 0, to: value)
                .stroke(AngularGradient(colors: [.good, .info, .good], center: .center), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(label).font(.system(size: size * 0.2, weight: .bold, design: .monospaced))
        }
        .frame(width: size, height: size)
    }
}

struct PlayButtons: View {
    var text: String
    var body: some View {
        HStack(spacing: 8) {
            IconButton(system: "speaker.wave.2.fill") { Speaker.shared.say(text) }
            IconButton(system: "tortoise.fill") { Speaker.shared.say(text, slow: true) }
        }
    }
}

struct IconButton: View {
    var system: String
    var size: CGFloat = 46
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: system).font(.system(size: size * 0.38, weight: .semibold)).foregroundStyle(Color.ink)
                .frame(width: size, height: size)
                .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: size * 0.3, style: .continuous).strokeBorder(Color.hair))
        }
        .buttonStyle(.plain)
    }
}

/// Leaves any session or page and goes straight back to the Home tab.
struct HomeButton: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        Button { Store.shared.goHome(); dismiss() } label: {
            Image(systemName: "house.fill").font(.system(size: 17, weight: .semibold)).foregroundStyle(Color.ink)
                .frame(width: 40, height: 40)
                .background(Color.white.opacity(0.09), in: Circle())
                .overlay(Circle().strokeBorder(Color.hair))
        }
        .accessibilityLabel(L.s("Home", "Главная"))
    }
}

func scoreColor(_ v: Int) -> Color { v >= 85 ? .good : v >= 60 ? .pron : .bad }

import SwiftUI

enum SolarDeco {
    static let enamel = Color(red: 8 / 255, green: 8 / 255, blue: 9 / 255)
    static let gold = Color(red: 212 / 255, green: 168 / 255, blue: 79 / 255)
    static let bright = Color(red: 1, green: 0.88, blue: 0.59)
    static let ivory = Color(red: 0.98, green: 0.91, blue: 0.76)
    static let brass = Color(red: 0.50, green: 0.36, blue: 0.17)
    static let muted = Color(red: 0.73, green: 0.65, blue: 0.51)
    static let bronze = Color(red: 0.20, green: 0.14, blue: 0.08)
    static let panel = Color(red: 0.083, green: 0.070, blue: 0.053)
    static let socket = LinearGradient(
        colors: [Color(white: 0.018), Color(red: 0.087, green: 0.075, blue: 0.061), Color(white: 0.032)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let metal = LinearGradient(
        stops: [
            .init(color: bright, location: 0),
            .init(color: gold, location: 0.27),
            .init(color: brass, location: 0.55),
            .init(color: bronze, location: 0.72),
            .init(color: gold, location: 1)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let button = LinearGradient(
        colors: [bright, gold, Color(red: 0.77, green: 0.53, blue: 0.22)],
        startPoint: .top,
        endPoint: .bottom
    )

    static func solarTitle(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .serif)
    }
}

struct SolarCabinetGlyph: View {
    let name: String

    var body: some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .accessibilityHidden(true)
    }
}

struct SolarCutCorner: Shape {
    var cut: CGFloat = 12

    func path(in rect: CGRect) -> Path {
        let offset = min(cut, rect.width / 2, rect.height / 2)
        return Path { path in
            path.move(to: CGPoint(x: rect.minX + offset, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - offset, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + offset))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - offset))
            path.addLine(to: CGPoint(x: rect.maxX - offset, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX + offset, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - offset))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + offset))
            path.closeSubpath()
        }
    }
}

struct SolarBrassFrame: View {
    var cut: CGFloat = 16

    var body: some View {
        SolarCutCorner(cut: cut)
            .solarStrokeBorderStyle()
            .overlay {
                SolarCutCorner(cut: cut - 2)
                    .solarStrokeBorderStyle()
                    .opacity(0.46)
                    .padding(4)
            }
            .allowsHitTesting(false)
    }
}

extension SolarCutCorner {
    fileprivate func solarStrokeBorderStyle() -> some View {
        stroke(SolarDeco.metal, lineWidth: 1)
    }
}

struct SolarCabinetBackground: View {
    var body: some View {
        SolarDeco.enamel
            .overlay(alignment: .top) {
                RadialGradient(
                    colors: [SolarDeco.bronze.opacity(0.60), SolarDeco.enamel.opacity(0)],
                    center: .top,
                    startRadius: 10,
                    endRadius: 495
                )
            }
            .ignoresSafeArea()
    }
}

struct SolarGoldButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled

    var prominent = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(prominent && enabled ? SolarDeco.enamel : SolarDeco.ivory)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background {
                if prominent && enabled {
                    SolarCutCorner().fill(SolarDeco.button)
                } else {
                    SolarCutCorner().fill(SolarDeco.panel)
                }
            }
            .overlay {
                SolarCutCorner().stroke(SolarDeco.metal, lineWidth: 1)
                SolarCutCorner(cut: 9)
                    .stroke(prominent && enabled ? SolarDeco.bronze.opacity(0.44) : SolarDeco.brass.opacity(0.32))
                    .padding(3)
            }
            .contentShape(SolarCutCorner())
            .opacity(enabled ? (configuration.isPressed ? 0.78 : 1) : 0.50)
    }
}

struct SolarCabinetIconStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(SolarDeco.ivory)
            .frame(width: 44, height: 44)
            .background { SolarCutCorner(cut: 8).fill(SolarDeco.panel) }
            .overlay { SolarCutCorner(cut: 8).stroke(SolarDeco.brass.opacity(0.85)) }
            .contentShape(.rect)
            .opacity(enabled ? (configuration.isPressed ? 0.68 : 1) : 0.38)
    }
}

/// A clipped pass of light for an available tap target.
struct SolarGlint<Outline: Shape>: View {
    let outline: Outline
    let tint: Color
    var period: Double = 4.6
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var phase

    var body: some View {
        Group {
            if reduceMotion || phase != .active {
                outline.stroke(tint.opacity(0.75), lineWidth: 2)
            } else {
                TimelineView(.animation(minimumInterval: 1 / 24)) { context in
                    GeometryReader { bounds in
                        let elapsed = context.date.timeIntervalSinceReferenceDate
                            .truncatingRemainder(dividingBy: period)
                        if elapsed < 0.85 {
                            let progress = elapsed / 0.85
                            Rectangle()
                                .fill(LinearGradient(colors: [.clear, tint.opacity(0.23), tint, .clear],
                                                     startPoint: .leading, endPoint: .trailing))
                                .frame(width: bounds.size.width * 0.34, height: bounds.size.height * 1.6)
                                .rotationEffect(.degrees(22))
                                .position(x: bounds.size.width * (1.55 * progress - 0.275), y: bounds.size.height / 2)
                                .mask { outline.stroke(tint, lineWidth: 2.5) }
                        }
                    }
                }
            }
        }
        .padding(2)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

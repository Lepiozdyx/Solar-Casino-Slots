import SwiftUI

struct AurumGameRules: View {
    @Environment(\.locale) private var locale
    let room: AurumRoom

    var body: some View {
        SolarGameRulesLayout(title: room.title) {
            switch room {
            case .blackjack: blackjack
            case .roulette: roulette
            default: slots
            }
        }
    }

    private var slots: some View {
        Group {
            SolarRuleCopy(LocalizedStringKey("rules.slot." + room.rawValue))
            if room == .prism {
                clusters
            } else {
                lineAwards
            }
            Text(room.featureName).font(SolarDeco.solarTitle(21))
            HStack(spacing: 12) {
                AurumArt("aurum-mark-scatter").frame(width: 42, height: 54)
                SolarRuleCopy(room == .prism ? "rules.scatters.prism" : "rules.scatters.lines")
            }
            SolarRuleCopy(LocalizedStringKey("rules.feature." + room.rawValue))
            SolarRuleCopy("rules.featureEntry \(room.featurePrice)")
        }
    }

    private var clusters: some View {
        Group {
            Text("rules.clusters").font(SolarDeco.solarTitle(21))
            VStack(spacing: 6) {
                ForEach([5, 6, 7, 8, 10, 12], id: \.self) { count in
                    SolarRuleRow(value: factor(AurumReelArithmetic.solarClusterFactor(count)) + "×") {
                        switch count {
                        case 8, 10: Text("\(count)–\(count + 1)")
                        case 12: Text("\(count)+")
                        default: Text(count, format: .number)
                        }
                    }
                }
            }
            SolarRuleCopy("rules.clusterPayment").font(.footnote)
        }
    }

    private var lineAwards: some View {
        Group {
            Text("rules.lines").font(SolarDeco.solarTitle(21))
            HStack {
                Text("rules.symbol").font(.caption.weight(.bold))
                Spacer()
                Text(room == .redline ? "3" : "3 / 4 / 5").font(.caption.monospacedDigit())
            }
            .foregroundStyle(SolarDeco.muted)
            .padding(.horizontal, 12)
            VStack(spacing: 7) {
                ForEach(room.ordinary, id: \.rawValue) { mark in
                    SolarRuleRow(value: lineFactor(mark)) {
                        HStack(spacing: 10) {
                            AurumArt(mark.art).frame(width: 34, height: 37)
                            Text(LocalizedStringKey("rules.mark." + String(describing: mark)))
                        }
                    }
                }
            }
            SolarRuleCopy("rules.linePayment").font(.footnote)
            Text("rules.fixedLines").font(SolarDeco.solarTitle(21))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 7) {
                ForEach(Array(paths.enumerated()), id: \.offset) { index, path in
                    AurumLineDiagram(path: path, number: index + 1)
                }
            }
        }
    }

    private var blackjack: some View {
        Group {
            SolarRuleCopy("rules.blackjack.goal")
            Text("rules.blackjack.actions").font(SolarDeco.solarTitle(21))
            SolarRuleCopy("rules.blackjack.hit")
            SolarRuleCopy("rules.blackjack.double")
            SolarRuleCopy("rules.blackjack.dealer")
            Text("rules.totalReturn").font(SolarDeco.solarTitle(21))
            VStack(spacing: 7) {
                SolarRuleRow(value: "2×") { Text("rules.blackjack.win") }
                SolarRuleRow(value: factor(2.5) + "×") { Text("rules.blackjack.natural") }
                SolarRuleRow(value: "1×") { Text("rules.blackjack.push") }
            }
            SolarRuleCopy("rules.blackjack.settlement").font(.footnote)
        }
    }

    private var roulette: some View {
        Group {
            SolarRuleCopy("rules.roulette.start")
            SolarRuleCopy("rules.roulette.limits")
            Text("rules.totalReturn").font(SolarDeco.solarTitle(21))
            VStack(spacing: 7) {
                SolarRuleRow(value: "\(AurumRouletteArea.number.returnFactor)×") { Text("rules.roulette.single") }
                SolarRuleRow(value: "\(AurumRouletteArea.dozen1.returnFactor)×") { Text("rules.roulette.groups") }
                SolarRuleRow(value: "\(AurumRouletteArea.red.returnFactor)×") { Text("rules.roulette.outside") }
            }
            SolarRuleCopy("rules.roulette.zero").font(.footnote)
        }
    }

    private var paths: [[Int]] {
        room == .redline ? AurumReelArithmetic.classicPaths : AurumReelArithmetic.orbitalPaths
    }

    private func lineFactor(_ mark: AurumMark) -> String {
        let base = AurumReelArithmetic.solarLineBase(mark, room: room)
        if room == .redline { return factor(base) + "×" }
        return [1.0, 3.0, 8.0].map { factor(base * $0) + "×" }.joined(separator: " / ")
    }

    private func factor(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)).locale(locale))
    }
}

private struct AurumLineDiagram: View {
    let path: [Int]
    let number: Int

    var body: some View {
        VStack(spacing: 5) {
            Canvas { context, size in
                let width = size.width / CGFloat(path.count)
                let height = size.height / 3
                for row in 0..<3 {
                    for column in path.indices {
                        let dot = CGRect(x: (CGFloat(column) + 0.3) * width, y: (CGFloat(row) + 0.3) * height,
                                         width: width * 0.4, height: height * 0.4)
                        context.fill(Path(ellipseIn: dot), with: .color(SolarDeco.muted.opacity(0.22)))
                    }
                }
                var line = Path()
                for (column, row) in path.enumerated() {
                    let point = CGPoint(x: (CGFloat(column) + 0.5) * width, y: (CGFloat(row) + 0.5) * height)
                    if column == 0 { line.move(to: point) } else { line.addLine(to: point) }
                }
                context.stroke(line, with: .color(SolarDeco.gold),
                               style: .init(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
            .frame(height: 39)
            Text(number, format: .number)
                .font(.caption2).foregroundStyle(SolarDeco.muted)
        }
        .padding(7)
        .background { SolarCutCorner(cut: 7).fill(SolarDeco.panel) }
    }
}

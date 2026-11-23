import SwiftUI
import UIKit

private extension SolarProperty {
    var name: LocalizedStringKey { LocalizedStringKey("estate.property." + rawValue + ".name") }
    var story: LocalizedStringKey { LocalizedStringKey("estate.property." + rawValue + ".story") }
}

private struct SolarLotSelection: Identifiable {
    let id: Int
    let price: Int?
    let showsFirstReveal: Bool
}

struct SolarEmpireScreen: View {
    @ObservedObject var bank: SolarCasinoBank
    let back: () -> Void
    let gameHall: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selected: SolarLotSelection?
    @State private var revealed: Int?
    @State private var payout: SolarIncomeReceipt?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 7), count: 4)

    var body: some View {
        ZStack {
            VStack(spacing: 12) {
                SolarScreenHeading(title: "estate.title", balance: bank.balance, back: back)

                ScrollView {
                    VStack(spacing: 14) {
                        SolarGameHallEntrance(action: gameHall)
                        if bank.onboarding == .visitGameHall {
                            SolarEmpireTip(text: "empire.guide.hall", symbol: "suit.club.fill")
                        }

                        TimelineView(.periodic(from: .now, by: 1)) { time in
                            VStack(spacing: 12) {
                                grid(now: time.date)
                                controls(now: time.date)
                            }
                        }
                    }
                    .padding(.bottom, 12)
                }
                .scrollIndicators(.hidden)
            }
            .disabled(!bank.canPlay)

            if !bank.canPlay, selected == nil {
                SolarCasinoStorageNotice(bank: bank, close: back)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .frame(maxWidth: 464)
        .overlay(alignment: .top) {
            if let payout { SolarIncomeToast(receipt: payout).id(payout.id).padding(.top, 48) }
        }
        .sheet(item: $selected) { selection in
            SolarEstateDetail(bank: bank, selection: selection)
                .presentationDragIndicator(.visible)
        }
        .onChange(of: bank.estate) { previous, current in
            let changes = SolarEstateChanges(previous: previous, current: current)
            if let opened = changes.opened {
                withAnimation(reduceMotion ? .easeOut(duration: 0.18) : .spring(duration: 0.48, bounce: 0.29)) {
                    revealed = opened
                }
            }
            if changes.income > 0, selected == nil {
                payout = SolarIncomeReceipt(amount: changes.income)
                solarEstateFeedback(bank)
            }
        }
        .task(id: revealed) {
            guard revealed != nil else { return }
            do { try await Task.sleep(for: .milliseconds(950)) } catch { return }
            withAnimation(.easeOut(duration: 0.25)) { revealed = nil }
        }
        .task(id: payout?.id) {
            guard payout != nil else { return }
            do { try await Task.sleep(for: .seconds(1.3)) } catch { return }
            withAnimation(.easeOut(duration: 0.16)) { payout = nil }
        }
    }

    private func grid(now: Date) -> some View {
        LazyVGrid(columns: columns, spacing: 7) {
            ForEach(bank.estate.lots.indices, id: \.self) { index in
                let lot = bank.estate.lots[index]
                Button {
                    let firstBox = !lot.isOpen &&
                        (bank.onboarding == .collectStarterIncome || bank.onboarding == .openFirstBox)
                    selected = SolarLotSelection(id: index, price: lot.isOpen ? nil : bank.estate.nextPrice,
                                                 showsFirstReveal: firstBox)
                } label: {
                    tile(lot, ready: lot.isReady(at: now), highlighted: revealed == index)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(lot.isOpen ? lot.property.name : "estate.locked"))
                .accessibilityIdentifier("estate_lot_\(index)")
            }
        }
        .padding(8)
        .background { SolarCutCorner(cut: 16).fill(SolarDeco.socket) }
        .overlay { SolarBrassFrame(cut: 16) }
    }

    private func tile(_ lot: SolarEstate.Lot, ready: Bool, highlighted: Bool) -> some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if lot.isOpen {
                    GeometryReader { bounds in
                        VStack(spacing: 0) {
                            SolarPropertyArt(property: lot.property)
                                .frame(width: bounds.size.width * 0.82, height: bounds.size.height * 0.72)
                            Text(lot.property.name)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(SolarDeco.ivory)
                                .lineLimit(1)
                                .minimumScaleFactor(0.68)
                                .padding(.horizontal, 3)
                        }
                        .frame(width: bounds.size.width, height: bounds.size.height)
                    }
                } else {
                    SolarCabinetGlyph(name: "LockGlyph")
                        .frame(width: 23, height: 23)
                        .opacity(0.68)
                }
            }
            .background {
                SolarCutCorner(cut: 8)
                    .fill(lot.isOpen ? SolarDeco.bronze : SolarDeco.panel)
            }
            .overlay { SolarBrassFrame(cut: 8).opacity(lot.isOpen ? 1 : 0.52) }
            .overlay(alignment: .topTrailing) {
                if ready {
                    Circle().fill(SolarDeco.bright).frame(width: 6, height: 6)
                        .shadow(color: SolarDeco.gold, radius: 4).padding(5)
                }
            }
            .overlay {
                if highlighted {
                    SolarGlint(outline: SolarCutCorner(cut: 8), tint: SolarDeco.bright, period: 2.1)
                    SolarCutCorner(cut: 8).stroke(SolarDeco.gold.opacity(0.75))
                        .allowsHitTesting(false)
                }
            }
            .contentShape(SolarCutCorner(cut: 8))
    }

    private func controls(now: Date) -> some View {
        let income = bank.estate.readyIncome(at: now)
        return VStack(spacing: 8) {
            if bank.onboarding == .collectStarterIncome, income > 0 {
                SolarEmpireTip(text: "empire.guide.collect.body", symbol: "clock.fill")
            } else if bank.onboarding == .openFirstBox,
                      let price = bank.estate.nextPrice, bank.balance >= price {
                SolarEmpireTip(text: "empire.guide.box.body", symbol: "shippingbox.fill")
            }

            if let price = bank.estate.nextPrice {
                HStack(spacing: 8) {
                    SolarChipAmount(value: price)
                    if bank.balance < price, income == 0 {
                        Text("empire.missing \((price - bank.balance).formatted())")
                            .foregroundStyle(SolarDeco.muted)
                    }
                }
            } else {
                Text("empire.collectionComplete").foregroundStyle(SolarDeco.muted)
            }

            Button { bank.solarCollectIncome() } label: {
                VStack(spacing: 3) {
                    Text("estate.collectAll")
                    if income > 0 {
                        SolarChipAmount(value: income)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(SolarDeco.bright)
                    }
                }
            }
            .buttonStyle(SolarGoldButtonStyle(prominent: false))
            .disabled(income == 0)
            .accessibilityIdentifier("estate_collect_all")
            if bank.balance < 20 {
                Button("casino.refill") { bank.solarRefill() }
                    .buttonStyle(SolarGoldButtonStyle(prominent: false))
            }
        }
        .font(.footnote.weight(.semibold))
    }
}

private struct SolarEstateDetail: View {
    @ObservedObject var bank: SolarCasinoBank
    let selection: SolarLotSelection
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var flash = false
    @State private var revealing = false
    @State private var payout: SolarIncomeReceipt?

    private var lot: SolarEstate.Lot { bank.estate.lots[selection.id] }

    var body: some View {
        ZStack {
            SolarCabinetBackground()
            VStack(spacing: 10) {
                HStack {
                    SolarCabinetKey(title: "action.back", glyph: "BackGlyph") { dismiss() }
                    Spacer()
                    SolarChipAmount(value: bank.balance).font(.subheadline.weight(.semibold))
                }
                ScrollView {
                    Group {
                        if lot.isOpen {
                            TimelineView(.periodic(from: .now, by: 1)) { time in
                                openDetail(now: time.date)
                            }
                        } else {
                            lockedDetail
                        }
                    }
                    .padding(.bottom, 20)
                }
                .scrollIndicators(.hidden)
            }
            .padding(.horizontal, 22)
            .padding(.top, 20)
            .frame(maxWidth: 445)
            .disabled(!bank.canPlay)

            if !bank.canPlay {
                SolarCasinoStorageNotice(bank: bank) { dismiss() }
            }
        }
        .overlay(alignment: .top) {
            if let payout { SolarIncomeToast(receipt: payout).id(payout.id).padding(.top, 67) }
        }
        .onChange(of: bank.estate) { previous, current in
            let changes = SolarEstateChanges(previous: previous, current: current)
            if changes.opened == selection.id {
                flash = true
                revealing = true
                solarEstateFeedback(bank)
            }
            if changes.income > 0 {
                payout = SolarIncomeReceipt(amount: changes.income)
                solarEstateFeedback(bank)
            }
        }
        .task(id: revealing) {
            guard revealing else { return }
            do {
                try await Task.sleep(for: .milliseconds(70))
                withAnimation(.easeOut(duration: reduceMotion ? 0.24 : 0.85)) { flash = false }
                try await Task.sleep(for: .milliseconds(480))
                revealing = false
            } catch { return }
        }
        .task(id: payout?.id) {
            guard payout != nil else { return }
            do { try await Task.sleep(for: .seconds(1.3)) } catch { return }
            withAnimation(.easeOut(duration: 0.16)) { payout = nil }
        }
        .foregroundStyle(SolarDeco.ivory)
        .preferredColorScheme(.dark)
    }

    private var lockedDetail: some View {
        let price = selection.price ?? 0
        let affordable = bank.balance >= price
        return VStack(spacing: 16) {
            SolarCabinetGlyph(name: "LockGlyph").frame(width: 69, height: 69).padding(.top, 25)
            Text("estate.locked").font(SolarDeco.solarTitle(31))
            Text("estate.locked.body")
                .font(.subheadline).foregroundStyle(SolarDeco.muted)
            SolarChipAmount(value: price).font(.title2.weight(.semibold))
            if !affordable {
                Text("estate.missing \(price - bank.balance)")
                    .font(.footnote.weight(.semibold)).foregroundStyle(SolarDeco.bright)
            }
            Button("estate.buy") { bank.solarBuyLot(selection.id, quotedPrice: price) }
                .buttonStyle(SolarGoldButtonStyle(prominent: false))
                .disabled(!affordable || price <= 0)
                .accessibilityIdentifier("estate_buy")
        }
        .multilineTextAlignment(.center)
        .padding(.bottom, 8)
    }

    private func openDetail(now: Date) -> some View {
        let property = lot.property
        let ready = lot.isReady(at: now)
        return VStack(alignment: .leading, spacing: 14) {
            ZStack {
                SolarCutCorner(cut: 16).fill(SolarDeco.socket)
                if property == .casino, let hero = SolarImageArchive.shared.solarImage("solar-estate-hero") {
                    GeometryReader { bounds in
                        Image(uiImage: hero).resizable().scaledToFill()
                            .frame(width: bounds.size.width, height: bounds.size.height).clipped()
                    }
                } else {
                    SolarPropertyArt(property: property).padding(10)
                }
            }
            .frame(height: property == .casino ? 202 : 140)
            .clipShape(SolarCutCorner(cut: 16))
            .overlay { SolarBrassFrame(cut: 16) }
            .overlay {
                SolarCutCorner(cut: 16).fill(SolarDeco.bright)
                    .opacity(flash ? 0.63 : 0).allowsHitTesting(false)
            }

            Text(property.name).font(SolarDeco.solarTitle(32))
            if !selection.showsFirstReveal { story }

            Divider().overlay(SolarDeco.brass.opacity(0.45))
            HStack {
                Text("estate.dailyIncome").font(.subheadline)
                Spacer()
                SolarChipAmount(value: property.income).font(.headline)
            }
            if selection.showsFirstReveal {
                HStack {
                    Text("empire.reveal.totalIncome").font(.subheadline.weight(.semibold))
                    Spacer()
                    SolarChipAmount(value: bank.estate.dailyIncome).font(.headline)
                }
                .foregroundStyle(SolarDeco.bright)
                .accessibilityIdentifier("empire_reveal_income")
            }
            HStack {
                Text(ready ? "estate.incomeReady" : "estate.nextPayout").font(.footnote)
                Spacer()
                if !ready, let due = lot.nextPayout {
                    SolarPayoutCountdown(due: due, now: now)
                        .font(.footnote)
                        .accessibilityIdentifier("estate_countdown")
                }
            }
            .foregroundStyle(ready ? SolarDeco.bright : SolarDeco.muted)

            if selection.showsFirstReveal {
                Button("empire.return") { dismiss() }
                    .buttonStyle(SolarGoldButtonStyle())
                    .disabled(revealing)
                    .accessibilityIdentifier("empire_reveal_return")
                story
            }

            if !selection.showsFirstReveal || ready {
                Button("estate.collect") { bank.solarCollectIncome(selection.id) }
                    .buttonStyle(SolarGoldButtonStyle(prominent: false))
                    .disabled(!ready)
                    .accessibilityIdentifier("estate_collect")
            }
        }
    }

    private var story: some View {
        Text(lot.property.story)
            .font(.subheadline)
            .foregroundStyle(SolarDeco.muted)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct SolarEstateChanges {
    let opened: Int?
    let income: Int

    init(previous: SolarEstate, current: SolarEstate) {
        opened = current.lots.indices.first { !previous.lots[$0].isOpen && current.lots[$0].isOpen }
        income = current.lots.indices.reduce(0) { sum, index in
            let before = previous.lots[index]
            let after = current.lots[index]
            return sum + (before.isOpen && before.nextPayout != after.nextPayout ? after.property.income : 0)
        }
    }
}

private struct SolarPropertyArt: View {
    let property: SolarProperty

    var body: some View {
        if let image = SolarImageArchive.shared.solarImage("solar-property-\(property.rawValue)") {
            Image(uiImage: image).resizable().scaledToFit()
        } else {
            Image(systemName: property.symbol).resizable().scaledToFit()
                .foregroundStyle(SolarDeco.metal)
                .padding(10)
        }
    }
}

private struct SolarIncomeReceipt: Identifiable {
    let id = UUID()
    let amount: Int
}

private struct SolarIncomeToast: View {
    let receipt: SolarIncomeReceipt
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    var body: some View {
        HStack(spacing: 5) {
            Text("+").fontWeight(.bold)
            SolarChipAmount(value: receipt.amount)
            Image(systemName: "sparkles").font(.caption)
        }
        .font(.subheadline.weight(.bold))
        .foregroundStyle(SolarDeco.bright)
        .padding(.horizontal, 14).padding(.vertical, 9)
        .background { SolarCutCorner(cut: 7).fill(SolarDeco.panel) }
        .overlay { SolarBrassFrame(cut: 7) }
        .shadow(color: SolarDeco.gold.opacity(0.30), radius: 13)
        .background {
            if !reduceMotion {
                ZStack {
                    ForEach(0..<4) { index in
                        let side = CGFloat(index) - 1.5
                        SolarCabinetGlyph(name: "ChipGlyph")
                            .frame(width: 12, height: 12)
                            .offset(x: shown ? side * 40 : side * 12,
                                    y: shown ? (index.isMultiple(of: 2) ? -21 : 21) : 0)
                            .opacity(shown ? 0.75 : 0)
                    }
                }
            }
        }
        .opacity(shown ? 1 : 0)
        .offset(y: shown || reduceMotion ? 0 : 18)
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeOut(duration: reduceMotion ? 0.15 : 0.38)) { shown = true }
        }
    }
}

private func solarEstateFeedback(_ bank: SolarCasinoBank) {
    if bank.archive.thunder.vibration { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
}

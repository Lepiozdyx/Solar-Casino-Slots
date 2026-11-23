import SwiftUI
import UIKit

struct SolarGameHall: View {
    @ObservedObject var library: SolarCasinoLibrary
    @ObservedObject private var bank: SolarCasinoBank
    let back: () -> Void
    let play: (SolarCasinoGame) -> Void

    @State private var showIntro: Bool
    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible())]

    init(library: SolarCasinoLibrary, back: @escaping () -> Void, play: @escaping (SolarCasinoGame) -> Void) {
        self.library = library
        self.bank = library.bank
        self.back = back
        self.play = play
        _showIntro = State(initialValue: !library.bank.sawGameHall)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 12) {
                SolarScreenHeading(title: "empire.gameHall", balance: bank.balance, back: back)

                ScrollView {
                    VStack(spacing: 12) {
                        if showIntro {
                            SolarEmpireTip(text: "empire.gameHall.intro", symbol: "circle.hexagongrid.fill")
                        }
                        if let unfinished = library.unfinishedGame {
                            Button("casino.resume \(unfinished.title)") { select(unfinished) }
                                .buttonStyle(SolarGoldButtonStyle())
                                .accessibilityIdentifier("casino_resume")
                        }
                        if bank.balance < 20 {
                            Button("casino.refill") { bank.solarRefill() }
                                .buttonStyle(SolarGoldButtonStyle(prominent: false))
                                .accessibilityIdentifier("casino_hall_refill")
                        }
                        games
                    }
                    .padding(.bottom, 12)
                }
                .scrollIndicators(.hidden)
            }
            .disabled(!bank.canPlay)

            if !bank.canPlay { SolarCasinoStorageNotice(bank: bank, close: back) }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .frame(maxWidth: 464)
        .onAppear { bank.solarVisitGameHall() }
    }

    private var games: some View {
        let unfinished = library.unfinishedGame
        return LazyVGrid(columns: columns, spacing: 14) {
            ForEach(SolarCasinoGame.allCases) { game in
                let available = unfinished == nil || unfinished == game
                Button { select(game) } label: {
                    SolarGameHallCard(game: game)
                }
                .buttonStyle(.plain)
                .opacity(available ? 1 : 0.45)
                .disabled(!available)
                .accessibilityIdentifier("casino_" + game.rawValue)
            }
        }
    }

    private func select(_ game: SolarCasinoGame) {
        guard bank.canPlay, library.unfinishedGame == nil || library.unfinishedGame == game else { return }
        showIntro = false
        play(game)
    }
}

struct SolarGameHallEntrance: View {
    let action: () -> Void

    private let covers: [SolarCasinoGame] = [.forge, .redline, .orbit]

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                HStack(spacing: 1) {
                    ForEach(covers) { game in
                        SolarGameCover(game: game)
                    }
                }
                .background(SolarDeco.gold)
                .frame(height: 84)

                HStack(spacing: 12) {
                    Text("empire.gameHall").font(SolarDeco.solarTitle(24))
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.forward").font(.subheadline.weight(.bold))
                }
                .foregroundStyle(SolarDeco.enamel)
                .padding(.horizontal, 16)
                .frame(minHeight: 48)
                .background(SolarDeco.button)
            }
            .clipShape(SolarCutCorner(cut: 14))
            .overlay { SolarBrassFrame(cut: 14) }
            .contentShape(SolarCutCorner(cut: 14))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("empire_game_hall")
    }
}

private struct SolarGameHallCard: View {
    let game: SolarCasinoGame

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SolarGameCover(game: game)
                .aspectRatio(0.96, contentMode: .fit)

            Text(game.title).font(SolarDeco.solarTitle(17))
                .lineLimit(1).minimumScaleFactor(0.72)
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
        }
        .background(SolarDeco.panel)
        .clipShape(SolarCutCorner(cut: 12))
        .overlay { SolarBrassFrame(cut: 12) }
        .contentShape(SolarCutCorner(cut: 12))
    }
}

private struct SolarGameCover: View {
    let game: SolarCasinoGame

    var body: some View {
        SolarDeco.socket.overlay {
            GeometryReader { bounds in
                if let artwork = SolarImageArchive.shared.solarImage(game.artwork) {
                    Image(uiImage: artwork).resizable().scaledToFill()
                        .frame(width: bounds.size.width, height: bounds.size.height)
                        .clipped()
                }
            }
        }
    }
}

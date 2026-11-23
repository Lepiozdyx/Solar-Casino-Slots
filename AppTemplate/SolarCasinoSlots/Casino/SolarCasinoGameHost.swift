import SwiftUI

struct SolarCasinoGameHost: View {
    @ObservedObject var library: SolarCasinoLibrary
    let game: SolarCasinoGame
    @Environment(\.scenePhase) private var phase
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ZStack {
            Group {
                if let cabinet = game.cabinet {
                    SolarCabinetScreen(game: cabinet, ledger: library.thunder)
                } else if let room = game.room {
                    switch room {
                    case .blackjack: AurumBlackjackRoom()
                    case .roulette: AurumRouletteRoom()
                    default: AurumSlotRoom(room: room, club: library.slottop)
                    }
                }
            }
            .environmentObject(library.slottop)
            .disabled(!library.bank.canPlay)
            if !library.bank.canPlay { SolarCasinoStorageNotice(bank: library.bank) { dismiss() } }
        }
        .onAppear { solarConfigureAudio() }
        .onChange(of: phase) { _, _ in solarConfigureAudio() }
        .onDisappear {
            SolarSoundStage.shared.solarQuiet()
            AurumSoundstage.shared.solarQuiet()
        }
    }
    private func solarConfigureAudio() {
        guard game.room != nil else { return }
        AurumSoundstage.shared.solarConfigure(library.slottop.state, room: game.rawValue, active: phase == .active)
    }
}

struct SolarCasinoStorageNotice: View {
    @ObservedObject var bank: SolarCasinoBank
    var close: (() -> Void)? = nil
    var body: some View {
        ZStack {
            if close != nil { SolarDeco.enamel.opacity(0.97).ignoresSafeArea() }
            VStack(spacing: 20) {
                Text(bank.loadFailed ? "casino.loadError" : "casino.saveError")
                    .font(SolarDeco.solarTitle(25)).multilineTextAlignment(.center)
                Text(bank.loadFailed ? "casino.loadMessage" : "casino.saveMessage")
                    .foregroundStyle(SolarDeco.muted).multilineTextAlignment(.center)
                if bank.loadFailed {
                    if let close {
                        Button("action.back", action: close).buttonStyle(SolarGoldButtonStyle(prominent: false))
                    }
                } else {
                    Button("casino.retry") { bank.solarRetry() }.buttonStyle(SolarGoldButtonStyle(prominent: false))
                }
            }.padding(30).frame(maxWidth: 420)
        }.foregroundStyle(SolarDeco.ivory)
    }
}

/// A small shared-bank refill replaces the source apps' reward and club screens.
struct AurumCoinPurse: View {
    var usesCabinetStyle = false
    @EnvironmentObject var club: AurumClubAccount
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ZStack {
            SolarCabinetBackground()
            VStack(spacing: 22) {
                Text("casino.bank").font(SolarDeco.solarTitle(30))
                AurumBalance(amount: club.balance, size: 30)
                Text("casino.virtual").foregroundStyle(SolarDeco.muted).multilineTextAlignment(.center)
                if club.balance < 20 {
                    Button("casino.refill") { club.bank.solarRefill(); dismiss() }.buttonStyle(SolarGoldButtonStyle(prominent: !usesCabinetStyle))
                } else {
                    Text("casino.lowerStake").foregroundStyle(SolarDeco.muted).multilineTextAlignment(.center)
                }
                Button("action.cancel") { dismiss() }.buttonStyle(SolarGoldButtonStyle(prominent: false))
            }.padding(25)
        }.foregroundStyle(SolarDeco.ivory).preferredColorScheme(.dark)
    }
}

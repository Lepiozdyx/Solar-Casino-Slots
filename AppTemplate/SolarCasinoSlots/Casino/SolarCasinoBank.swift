import Foundation
import Combine

enum SolarEmpireOnboarding: String, Codable {
    case collectStarterIncome, openFirstBox, visitGameHall
}

struct SolarCasinoArchive: Codable {
    var version = 2
    var balance = 25_000
    var thunder = SolarMemberArchive()
    var slottop = AurumAccount()
    var estate = SolarEstate()
    var onboarding: SolarEmpireOnboarding?
    var sawGameHall: Bool?
}

private struct SolarLegacyBank: Decodable {
    let version: Int
    let balance: Int
    let thunder: SolarMemberArchive
    let slottop: AurumAccount
}

private struct SolarLegacyPreferences: Decodable {
    let version: Int
    let sound: Bool
    let haptics: Bool
}

/// Game contracts, estate changes and their balance share one atomic snapshot.
@MainActor final class SolarCasinoBank: ObservableObject {
    @Published var balance: Int
    @Published private(set) var estate: SolarEstate
    @Published private(set) var onboarding: SolarEmpireOnboarding?
    @Published private(set) var saveFailed = false
    @Published private(set) var loadFailed = false
    private(set) var archive: SolarCasinoArchive
    private var pendingWrite: SolarCasinoArchive?
    private let file: URL
    var canPlay: Bool { !loadFailed && !saveFailed }
    var sawGameHall: Bool { archive.sawGameHall == true }

    init(file: URL? = nil, legacyBank: URL? = nil, legacyPreferences: URL? = nil) {
        let support = URL.applicationSupportDirectory
        self.file = file ?? support.appending(path: "SolarCasinoCollection/bank-v2.json")
        let oldBank = legacyBank ?? support.appending(path: "SolarCasinoCollection/bank-v1.json")
        let oldPreferences = legacyPreferences ?? support.appending(path: "SolarCasinoSlots/save.json")
        var loaded = SolarCasinoArchive()
        do {
            let decoder = JSONDecoder()
            if let data = try Self.read(self.file) {
                let saved = try decoder.decode(SolarCasinoArchive.self, from: data)
                guard saved.version == 2, saved.balance >= 0, saved.estate.isValid else {
                    throw CocoaError(.coderReadCorrupt)
                }
                loaded = saved
            } else {
                let legacyBankData = try Self.read(oldBank)
                let legacyPreferencesData = try? Self.read(oldPreferences)
                if let data = legacyBankData {
                    let old = try decoder.decode(SolarLegacyBank.self, from: data)
                    guard old.version == 1, old.balance >= 0 else { throw CocoaError(.coderReadCorrupt) }
                    loaded.balance = old.balance
                    loaded.thunder = old.thunder
                    loaded.slottop = old.slottop
                }
                if let data = legacyPreferencesData,
                   let preferences = try? decoder.decode(SolarLegacyPreferences.self, from: data),
                   (1...2).contains(preferences.version) {
                    loaded.thunder.soundtrack = preferences.sound
                    loaded.thunder.effects = preferences.sound
                    loaded.thunder.vibration = preferences.haptics
                    loaded.slottop.music = preferences.sound
                    loaded.slottop.sounds = preferences.sound
                    loaded.slottop.haptics = preferences.haptics
                }
                if legacyBankData == nil, legacyPreferencesData == nil {
                    loaded.estate = SolarEstate(starterIncomeReady: true)
                    loaded.onboarding = .collectStarterIncome
                }
            }
        } catch {
            loadFailed = true
        }
        archive = loaded
        balance = loaded.balance
        estate = loaded.estate
        onboarding = loaded.onboarding
    }

    private static func read(_ file: URL) throws -> Data? {
        do { return try Data(contentsOf: file) }
        catch CocoaError.fileReadNoSuchFile { return nil }
    }

    func solarCommit(thunder: SolarMemberArchive? = nil, slottop: AurumAccount? = nil) {
        guard !loadFailed, pendingWrite == nil else { return }
        archive.balance = balance
        if let thunder { archive.thunder = thunder }
        if let slottop { archive.slottop = slottop }
        guard !saveFailed else { return }
        _ = solarWrite(archive)
    }

    func solarRetry() {
        guard !loadFailed else { return }
        if let pendingWrite {
            solarFinishWrite(pendingWrite)
        } else if solarWrite(archive) {
            saveFailed = false
        }
    }

    private func solarWrite(_ candidate: SolarCasinoArchive) -> Bool {
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(candidate).write(to: file, options: .atomic)
            return true
        } catch {
            saveFailed = true
            return false
        }
    }

    private func solarFinishWrite(_ candidate: SolarCasinoArchive) {
        guard solarWrite(candidate) else {
            pendingWrite = candidate
            return
        }
        pendingWrite = nil
        archive = candidate
        if candidate.balance != balance { balance = candidate.balance }
        if candidate.estate != estate { estate = candidate.estate }
        if candidate.onboarding != onboarding { onboarding = candidate.onboarding }
        saveFailed = false
    }

    func solarVisitGameHall() {
        guard canPlay, !sawGameHall || onboarding == .visitGameHall else { return }
        var candidate = archive
        candidate.sawGameHall = true
        if onboarding == .visitGameHall { candidate.onboarding = nil }
        solarFinishWrite(candidate)
    }

    func solarBuyLot(_ index: Int, quotedPrice: Int, now: Date = .now) {
        guard canPlay, estate.lots.indices.contains(index), !estate.lots[index].isOpen,
              let price = estate.nextPrice, price == quotedPrice, balance >= price else { return }
        var candidate = archive
        candidate.balance -= price
        candidate.estate.open(index, at: now)
        if onboarding == .collectStarterIncome || onboarding == .openFirstBox {
            candidate.onboarding = .visitGameHall
        }
        solarFinishWrite(candidate)
    }

    func solarCollectIncome(_ index: Int? = nil, now: Date = .now) {
        guard canPlay else { return }
        var candidate = archive
        let income = candidate.estate.collect(index, at: now)
        guard income > 0 else { return }
        let (total, overflow) = candidate.balance.addingReportingOverflow(income)
        candidate.balance = overflow ? Int.max : total
        if onboarding == .collectStarterIncome,
           index == nil || index == SolarEstate.casinoIndex {
            candidate.onboarding = .openFirstBox
        }
        solarFinishWrite(candidate)
    }

    func solarRefill() {
        guard canPlay, balance < 20 else { return }
        var candidate = archive
        candidate.balance += 5_000
        solarFinishWrite(candidate)
    }
}

enum SolarCasinoGame: String, Identifiable, CaseIterable {
    case forge, nougat, temple, carnival, redline, prism, orbit, blackjack, roulette
    var id: String { rawValue }
    var cabinet: SolarCabinet? { SolarCabinet(rawValue: rawValue) }
    var room: AurumRoom? { AurumRoom(rawValue: rawValue) }
    var title: String { cabinet?.title ?? room?.title ?? "" }
    var artwork: String { cabinet?.solarCoverName ?? room?.scene ?? "" }
}

@MainActor final class SolarCasinoLibrary: ObservableObject {
    let bank: SolarCasinoBank
    let thunder: SolarClubLedger
    let slottop: AurumClubAccount
    private var observations: Set<AnyCancellable> = []
    init() {
        let bank = SolarCasinoBank()
        self.bank = bank
        thunder = SolarClubLedger(bank: bank)
        slottop = AurumClubAccount(bank: bank)
        bank.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &observations)
        thunder.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &observations)
        slottop.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &observations)
    }
    var unfinishedGame: SolarCasinoGame? {
        if thunder.member.lock != nil { return .forge }
        if let bonus = thunder.member.bonus { return SolarCasinoGame(rawValue: bonus.cabinet.rawValue) }
        if let hand = slottop.state.hand, !hand.finished { return .blackjack }
        return SolarCasinoGame.allCases.first { slottop.state.features[$0.rawValue] != nil }
    }
    func solarConfigure(sound: Bool, haptics: Bool) {
        guard bank.canPlay else { return }
        thunder.solarPreferences(sound: sound, haptics: haptics)
        slottop.solarPreferences(sound: sound, haptics: haptics)
        bank.solarCommit(thunder: thunder.member, slottop: slottop.state)
    }
}

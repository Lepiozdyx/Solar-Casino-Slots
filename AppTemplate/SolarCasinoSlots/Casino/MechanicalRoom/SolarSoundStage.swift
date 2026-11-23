import AVFoundation
import UIKit

@MainActor final class SolarSoundStage {
    static let shared = SolarSoundStage()
    private var music: AVAudioPlayer?
    private var voices: [AVAudioPlayer] = []
    private var currentTrack = "lobby"
    private var permitted = false
    private var musicWanted = true
    private var effectsWanted = true
    private var tactileWanted = true
    private var sessionReady = false
    private init() {
        NotificationCenter.default.addObserver(forName:AVAudioSession.interruptionNotification,object:nil,queue:.main) { [weak self] event in
            guard let raw = event.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt else { return }
            Task { @MainActor [weak self] in
                if raw == AVAudioSession.InterruptionType.began.rawValue { self?.music?.pause(); self?.voices.forEach { $0.stop() } }
                else { self?.solarResumeIfAllowed() }
            }
        }
        NotificationCenter.default.addObserver(forName:AVAudioSession.routeChangeNotification,object:nil,queue:.main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.solarResumeIfAllowed() }
        }
    }
    func solarApply(_ member: SolarMemberArchive, active: Bool, native: Bool, track: String = "lobby") {
        musicWanted = member.soundtrack; effectsWanted = member.effects; tactileWanted = member.vibration
        permitted = active && native
        if !permitted || !musicWanted { music?.pause() }
        if !permitted || !effectsWanted { voices.forEach { $0.stop() }; voices.removeAll() }
        if currentTrack != track { currentTrack = track; music?.stop(); music = nil }
        solarResumeIfAllowed()
    }
    func solarQuiet() { permitted = false; music?.pause(); voices.forEach { $0.stop() }; voices.removeAll() }
    private func solarReadySession() {
        guard !sessionReady else { return }
        do { try AVAudioSession.sharedInstance().setCategory(.ambient,mode:.default,options:[.mixWithOthers]); try AVAudioSession.sharedInstance().setActive(true); sessionReady = true } catch { sessionReady = false }
    }
    private func solarLoad(_ file: String) -> AVAudioPlayer? {
        guard let url = SolarAudioResources.solarMechanical(file) else { return nil }
        return try? AVAudioPlayer(contentsOf:url)
    }
    private func solarResumeIfAllowed() {
        guard permitted, musicWanted, UIApplication.shared.applicationState == .active else { return }
        solarReadySession()
        if music == nil { music = solarLoad(currentTrack); music?.numberOfLoops = -1; music?.volume = 0.3; music?.prepareToPlay() }
        if music?.isPlaying == false { music?.play() }
    }
    func solarPlay(_ cue: String, strong: Bool = false) {
        guard permitted else { return }
        if tactileWanted { UIImpactFeedbackGenerator(style:strong ? .medium : .light).impactOccurred() }
        guard effectsWanted else { return }
        solarReadySession(); voices.removeAll { !$0.isPlaying }
        if voices.count >= 7 { voices.removeFirst().stop() }
        if let player = solarLoad(cue) { player.volume = 0.75; voices.append(player); player.play() }
    }
}

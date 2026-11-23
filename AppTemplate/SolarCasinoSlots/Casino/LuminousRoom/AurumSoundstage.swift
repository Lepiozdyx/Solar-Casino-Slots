import AVFoundation
import UIKit

@MainActor final class AurumSoundstage: NSObject {
    static let shared = AurumSoundstage()
    private var loop: AVAudioPlayer?
    private var tones: [String:AVAudioPlayer] = [:]
    private var track = ""
    private var music = false,sounds = false,haptics = false,active = false,interrupted = false
    override private init() {
        super.init()
        NotificationCenter.default.addObserver(self,selector:#selector(solarInterruption(_:)),name:AVAudioSession.interruptionNotification,object:nil)
        NotificationCenter.default.addObserver(self,selector:#selector(solarRouteChanged),name:AVAudioSession.routeChangeNotification,object:nil)
    }
    func solarConfigure(_ account: AurumAccount,room: String = "lobby",active: Bool = true) {
        music = account.music;sounds = account.sounds;haptics = account.haptics;self.active = active
        if !sounds { tones.values.forEach{$0.stop()} }
        if track != room { loop?.stop();loop = nil;track = room }
        solarRefresh()
    }
    private func solarRefresh() {
        guard active,!interrupted else { loop?.pause();tones.values.forEach{$0.stop()};return }
        try? AVAudioSession.sharedInstance().setCategory(.ambient,mode:.default,options:[.mixWithOthers]);try? AVAudioSession.sharedInstance().setActive(true)
        guard music else { loop?.stop();loop = nil;return }
        if loop==nil,let url = SolarAudioResources.solarLuminous(track,music:true),let player = try? AVAudioPlayer(contentsOf:url) { loop = player;player.numberOfLoops = -1;player.volume = 0.2;player.prepareToPlay() }
        if loop?.isPlaying==false { loop?.play() }
    }
    func solarEffect(_ name: String) {
        guard active,!interrupted else { return }
        if haptics { UIImpactFeedbackGenerator(style:name=="win" || name=="bonus" ? .medium:.light).impactOccurred(intensity:name=="tap" ? 0.45:0.7) }
        guard sounds else { return }
        if tones[name]==nil,let url = SolarAudioResources.solarLuminous(name,music:false) { tones[name] = try? AVAudioPlayer(contentsOf:url);tones[name]?.volume = name=="reel" ? 0.22:0.5 }
        tones[name]?.currentTime = 0;tones[name]?.play()
    }
    func solarQuiet() { active = false;loop?.pause();tones.values.forEach{$0.stop()} }
    @objc private func solarInterruption(_ notice: Notification) {
        let kind = (notice.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt).flatMap(AVAudioSession.InterruptionType.init(rawValue:))
        interrupted = kind == .began;solarRefresh()
    }
    @objc private func solarRouteChanged() { solarRefresh() }
}

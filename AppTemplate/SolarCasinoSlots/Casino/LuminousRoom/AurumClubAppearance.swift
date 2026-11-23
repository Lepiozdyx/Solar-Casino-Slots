import SwiftUI
import UIKit

enum AurumInk {
    static let base = SolarDeco.enamel,panel = SolarDeco.panel,raised = SolarDeco.bronze
    static let white = SolarDeco.ivory,muted = SolarDeco.muted,coral = SolarDeco.gold,blue = SolarDeco.gold,green = Color(sx:0x73E2BB)
    static func solarFace(_ size: CGFloat) -> Font { .custom("AvenirNext-Bold",size:size) }
    static func solarDigits(_ size: CGFloat) -> Font { .system(size:size,weight:.bold,design:.rounded) }
}
extension Color { init(sx: UInt32) { self.init(.sRGB,red:Double((sx>>16)&255)/255,green:Double((sx>>8)&255)/255,blue:Double(sx&255)/255,opacity:1) } }
final class AurumArtwork {
    static let shared = AurumArtwork()
    func solarGet(_ name: String) -> UIImage? { SolarImageArchive.shared.solarImage(name) }
}
struct AurumArt: View {
    let name: String
    init(_ name: String) { self.name = name }
    var body: some View { Group { if let image = AurumArtwork.shared.solarGet(name) { Image(uiImage:image).resizable().interpolation(.high).scaledToFit() } else { Color.clear } }.accessibilityHidden(true) }
}
struct AurumScene: View {
    let name: String
    var body: some View { GeometryReader { p in if let image = AurumArtwork.shared.solarGet(name) { Image(uiImage:image).resizable().scaledToFill().frame(width:p.size.width,height:p.size.height).clipped() } }.accessibilityHidden(true) }
}
struct AurumBackground: View {
    var scene = "aurum-scene-redline"
    var body: some View { ZStack { AurumInk.base;AurumScene(name:scene).opacity(0.15);LinearGradient(colors:[AurumInk.base.opacity(0.5),AurumInk.base],startPoint:.top,endPoint:.bottom) }.ignoresSafeArea().accessibilityHidden(true) }
}
struct AurumBalance: View {
    @EnvironmentObject var club: AurumClubAccount
    let amount: Int
    var size: CGFloat = 19
    var body: some View { HStack(spacing:5) { AurumArt("aurum-mark-chip").frame(width:size*1.15,height:size*1.15);Text(club.solarNumber(amount)).font(AurumInk.solarDigits(size)).foregroundColor(AurumInk.white).lineLimit(1).minimumScaleFactor(0.6) } }
}
struct AurumStakeControl: View {
    @EnvironmentObject var club: AurumClubAccount
    var locked = false
    var display: Int? = nil
    var title: LocalizedStringKey = "slot.stake"

    private var stake: Int { club.state.stake }
    private var stakes: [Int] { AurumClubAccount.stakes }

    var body: some View {
        SolarSlotStake(amount: display ?? stake,
                       canLower: !locked && stake != stakes.first,
                       canRaise: !locked && stake != stakes.last,
                       title: title, change: solarAdjust)
    }

    private func solarAdjust(_ direction: Int) {
        guard !locked, let index = stakes.firstIndex(of: stake),
              stakes.indices.contains(index + direction) else { return }
        club.solarSetStake(stakes[index + direction])
        AurumSoundstage.shared.solarEffect("tap")
    }
}

import SwiftUI
import UIKit

enum SolarFoundry {
    static let night = SolarDeco.enamel
    static let panel = SolarDeco.panel
    static let gold = SolarDeco.gold
    static let copper = SolarDeco.gold
    static let ice = Color(red:0.2,green:0.88,blue:1)
    static let muted = SolarDeco.muted
    static let metal = LinearGradient(colors:[Color(red:1,green:0.9,blue:0.59),gold,Color(red:0.69,green:0.35,blue:0.08)],startPoint:.topLeading,endPoint:.bottomTrailing)
    static func solarTitle(_ size: CGFloat) -> Font { .custom("AvenirNext-Heavy",size:size) }
    static func solarNumber(_ size: CGFloat) -> Font { .system(size:size,weight:.heavy,design:.rounded).monospacedDigit() }
    static func solarTint(_ game: SolarCabinet) -> Color {
        switch game { case .forge: return ice; case .nougat: return .pink; case .temple: return .green; case .carnival: return .orange }
    }
}
extension Int {
    var coins: String { let f = NumberFormatter(); f.numberStyle = .decimal; f.locale = Locale(identifier:"en_US"); return f.string(from:NSNumber(value:self)) ?? "\(self)" }
    var compact: String { self >= 1_000_000 ? String(format:"%.1fM",Double(self)/1_000_000) : self >= 10000 ? String(format:"%.0fK",Double(self)/1000) : self >= 1000 ? String(format:"%.1fK",Double(self)/1000) : "\(self)" }
}

final class SolarArtworkDepot {
    static let shared = SolarArtworkDepot()
    func solarPicture(_ name: String) -> UIImage { SolarImageArchive.shared.solarImage(name) ?? UIImage() }
}
struct SolarArt: View {
    let name: String
    init(_ name: String) { self.name = name }
    var body: some View { Image(uiImage:SolarArtworkDepot.shared.solarPicture(name)).resizable().interpolation(.high).scaledToFit().accessibilityHidden(true) }
}
struct SolarCoinAmount: View {
    var value: Int
    var size: CGFloat = 20
    var body: some View { HStack(spacing:5) { SolarArt("aurum-wallet-token").frame(width:size+5,height:size+5); Text(value.coins).font(SolarFoundry.solarNumber(size)).foregroundColor(SolarFoundry.gold).lineLimit(1).minimumScaleFactor(0.65) } }
}
struct SolarMetalButton: View {
    var title: String
    var enabled = true
    var action: () -> Void

    var body: some View {
        Button(action: action) { Text(title) }
            .buttonStyle(SolarGoldButtonStyle(prominent: false))
            .disabled(!enabled)
    }
}
struct SolarFoundryBackdrop: View {
    var tint = SolarFoundry.ice
    var body: some View {
        ZStack {
            SolarFoundry.night
            RadialGradient(colors:[tint.opacity(0.17),.clear],center:.topTrailing,startRadius:0,endRadius:550)
            RadialGradient(colors:[SolarFoundry.copper.opacity(0.09),.clear],center:.bottomLeading,startRadius:0,endRadius:400)
        }.ignoresSafeArea()
    }
}

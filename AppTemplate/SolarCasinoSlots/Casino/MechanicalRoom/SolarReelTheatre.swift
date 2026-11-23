import SwiftUI

struct SolarSymbolPortrait: View {
    let game: SolarCabinet
    let token: SolarReelToken
    var body: some View {
        ZStack {
            SolarArt("\(game.solarArtPrefix)_\(token.face)").padding(3)
            if token.face == 8, token.factor > 0 {
                Text("×\(token.factor)").font(SolarFoundry.solarNumber(20)).foregroundColor(.white)
                    .shadow(color:.black,radius:3).offset(y:5)
            }
        }.accessibilityLabel(game.symbols[min(8,max(0,token.face))])
    }
}

struct SolarReelTheatre: View {
    @ObservedObject var session: SolarCabinetSession
    var width: CGFloat
    private var height: CGFloat { (width-20)/CGFloat(session.game.width)*CGFloat(session.game.height)+20 }
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius:18).fill(SolarDeco.enamel)
            SolarReelSurface(game:session.game,board:session.board,journey:session.journey,motion:session.motion,highlights:session.highlights,rockets:session.rockets,onLanding:session.solarRendererLanded)
                .padding(10)
            RoundedRectangle(cornerRadius:18).stroke(SolarFoundry.metal,lineWidth:2).allowsHitTesting(false)
            RoundedRectangle(cornerRadius:16).stroke(SolarFoundry.ice.opacity(0.2),lineWidth:1).padding(4).allowsHitTesting(false)
        }.frame(width:width,height:height)
            .shadow(color:SolarFoundry.solarTint(session.game).opacity(0.16),radius:20)
            .accessibilityIdentifier("reel_theatre")
    }
}

struct SolarFrontCoinShower: View {
    var seed = 0
    var body: some View {
        TimelineView(.animation(minimumInterval:1/30)) { context in
            GeometryReader { geometry in
                let now = context.date.timeIntervalSinceReferenceDate
                ZStack {
                    ForEach(0..<25,id:\.self) { i in
                        let period = 2.5 + Double(i%6)*0.17
                        let fraction = (now+Double(i)*0.217).truncatingRemainder(dividingBy:period)/period
                        let x = CGFloat((i*83+31)%997)/997 * geometry.size.width
                        SolarArt("aurum-wallet-token").frame(width:CGFloat(17+i%4*6),height:CGFloat(17+i%4*6))
                            .rotation3DEffect(.degrees(fraction*1000+Double(i)*33),axis:(x:0,y:1,z:0.25))
                            .rotationEffect(.degrees(fraction*230))
                            .position(x:x+CGFloat(sin(fraction*6+Double(i))*24),y:CGFloat(fraction)*(geometry.size.height+140)-70)
                            .opacity(fraction > 0.94 ? (1-fraction)/0.06 : 1)
                    }
                }
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}

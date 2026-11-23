import SwiftUI
import UIKit

struct SolarReelSurface: UIViewRepresentable {
    let game: SolarCabinet
    let board: SolarReelField
    let journey: SolarReelJourney?
    let motion: SolarCabinetSession.SolarMotion
    let highlights: Set<Int>
    let rockets: [SolarRocketWild]
    let onLanding: (UUID)->Void
    func makeUIView(context: Context) -> SolarReelSurfaceView { SolarReelSurfaceView(game:game) }
    func updateUIView(_ view: SolarReelSurfaceView,context: Context) {
        view.onLanding = onLanding
        view.solarApply(board:board,journey:journey,motion:motion,highlights:highlights,rockets:rockets)
    }
    static func dismantleUIView(_ view: SolarReelSurfaceView,coordinator: ()) { view.onLanding = nil; view.solarCancel() }
}

final class SolarReelGlyphView: UIView {
    private let picture = UIImageView()
    private let number = UILabel()
    private(set) var token: SolarReelToken
    private var effect = ""
    init(game: SolarCabinet,token: SolarReelToken) {
        self.token = token; super.init(frame:.zero)
        picture.image = SolarArtworkDepot.shared.solarPicture("\(game.solarArtPrefix)_\(token.face)"); picture.contentMode = .scaleAspectFit
        number.text = token.face == 8 && token.factor > 0 ? "×\(token.factor)" : nil
        number.textColor = .white; number.font = .systemFont(ofSize:20,weight:.heavy); number.textAlignment = .center
        number.layer.shadowColor = UIColor.black.cgColor; number.layer.shadowRadius = 3; number.layer.shadowOpacity = 1
        addSubview(picture); addSubview(number)
        isAccessibilityElement = true; accessibilityLabel = game.symbols[min(8,max(0,token.face))]
        accessibilityValue = "\(token.face):\(token.factor)"
        layer.cornerRadius = 8
    }
    required init?(coder: NSCoder) { fatalError("Use init(game:token:)") }
    override func layoutSubviews() {
        super.layoutSubviews(); picture.frame = bounds.insetBy(dx:3,dy:3)
        number.frame = CGRect(x:0,y:bounds.midY-8,width:bounds.width,height:28)
    }
    func solarPrepareForTravel() { effect = ""; layer.removeAnimation(forKey:"winnerShake"); transform = .identity; alpha = 1; backgroundColor = .clear; isAccessibilityElement = false }
    func solarStyle(winning: Bool,motion: SolarCabinetSession.SolarMotion,covered: Bool) {
        let key = "\(winning)-\(motion)-\(covered)"
        guard effect != key else { return }; effect = key
        layer.removeAnimation(forKey:"winnerShake")
        let bursting = winning && motion == .bursting
        isAccessibilityElement = !covered && !bursting
        backgroundColor = winning ? UIColor.cyan.withAlphaComponent(0.08) : .clear
        if winning && motion == .shaking {
            let shake = CAKeyframeAnimation(keyPath:"transform.rotation.z")
            shake.values = [-0.065,0.065,-0.065]; shake.duration = 0.15; shake.repeatCount = .infinity
            layer.add(shake,forKey:"winnerShake")
        }
        if bursting { UIView.animate(withDuration:0.22) { self.transform = CGAffineTransform(scaleX:1.4,y:1.4); self.alpha = 0 } }
        else { transform = .identity; alpha = covered ? 0 : 1 }
    }
}

/// The exact target views that arrive on the strip become the resting reel views.
/// No SwiftUI tree swap, second symbol draw, or delayed offset-reset is involved.
private final class SolarReelColumnView: UIView {
    private(set) var glyphs: [SolarReelGlyphView] = []
    private var track: UIView?
    private var animator: UIViewPropertyAnimator?
    private var generation: UUID?
    private var targetViews: [SolarReelGlyphView] = []
    private(set) var arrivalFrames: [CGRect] = []
    private var cell: CGFloat = 0
    private let game: SolarCabinet
    init(game: SolarCabinet) { self.game = game; super.init(frame:.zero); clipsToBounds = true }
    required init?(coder: NSCoder) { fatalError("Use init(game:)") }
    var moving: Bool { track != nil }
    func solarResize(cell: CGFloat) {
        self.cell = cell
        if !moving { for (row,glyph) in glyphs.enumerated() { glyph.frame = CGRect(x:0,y:CGFloat(row)*cell,width:cell,height:cell) } }
    }
    func solarDisplay(_ tokens: [SolarReelToken],animated: Bool) {
        guard glyphs.map(\.token) != tokens || moving || glyphs.contains(where: { $0.superview !== self }) else { return }
        solarStop()
        glyphs.forEach { if $0.superview !== self { addSubview($0) } }
        let retained = Dictionary(uniqueKeysWithValues:glyphs.map { ($0.token.id,$0) })
        let wanted = Set(tokens.map(\.id))
        glyphs.filter { !wanted.contains($0.token.id) }.forEach { $0.removeFromSuperview() }
        let replacements = tokens.filter { retained[$0.id] == nil }.count
        glyphs = tokens.enumerated().map { row,token in
            if let existing = retained[token.id], existing.token == token { return existing }
            retained[token.id]?.removeFromSuperview()
            let fresh = SolarReelGlyphView(game:game,token:token)
            fresh.frame = CGRect(x:0,y:CGFloat(row-(animated ? replacements : 0))*cell,width:cell,height:cell)
            addSubview(fresh); return fresh
        }
        let place = { for (row,glyph) in self.glyphs.enumerated() { glyph.transform = .identity; glyph.alpha = 1; glyph.frame = CGRect(x:0,y:CGFloat(row)*self.cell,width:self.cell,height:self.cell) } }
        if animated { UIView.animate(withDuration:0.32,delay:0,options:[.curveEaseOut,.beginFromCurrentState],animations:place) }
        else { UIView.performWithoutAnimation(place) }
    }
    func solarTravel(_ ribbon: SolarReelRibbon,id: UUID,duration: Double,completion: @escaping ()->Void) {
        solarStop(); generation = id
        let strip = UIView(frame:CGRect(x:0,y:0,width:cell,height:CGFloat(ribbon.cells.count)*cell))
        var arrival: [SolarReelGlyphView] = []
        for entry in ribbon.cells {
            let glyph = entry.id < glyphs.count ? glyphs[entry.id] : SolarReelGlyphView(game:game,token:entry.token)
            glyph.solarPrepareForTravel(); strip.addSubview(glyph)
            glyph.frame = CGRect(x:0,y:CGFloat(entry.id)*cell,width:cell,height:cell)
            if entry.id >= ribbon.landingOffset { arrival.append(glyph) }
        }
        track = strip; targetViews = arrival; addSubview(strip)
        let animator = UIViewPropertyAnimator(duration:duration,controlPoint1:CGPoint(x:0.12,y:0.6),controlPoint2:CGPoint(x:0.18,y:1))
        self.animator = animator
        let distance = CGFloat(ribbon.landingOffset)*cell
        animator.addAnimations { strip.transform = CGAffineTransform(translationX:0,y:-distance) }
        animator.addCompletion { [weak self] position in
            guard let self = self, self.generation == id, position == .end else { return }
            self.arrivalFrames = self.targetViews.map { $0.convert($0.bounds,to:self) }
            self.solarAdoptArrival(); completion()
        }
        animator.startAnimation()
    }
    private func solarAdoptArrival() {
        UIView.performWithoutAnimation {
            // Reparent the arriving UIImageViews, preserving both token and view identity.
            for (row,glyph) in targetViews.enumerated() {
                addSubview(glyph); glyph.frame = CGRect(x:0,y:CGFloat(row)*cell,width:cell,height:cell)
                glyph.isAccessibilityElement = true
            }
            glyphs = targetViews; targetViews = []; track?.removeFromSuperview(); track = nil; animator = nil; generation = nil
        }
    }
    func solarStop() {
        generation = nil; animator?.stopAnimation(true); animator = nil
        track?.removeFromSuperview(); track = nil; targetViews = []
        // A cancelled track is reconciled with the committed model by display().
    }
}

final class SolarReelSurfaceView: UIView {
    let game: SolarCabinet
    var onLanding: ((UUID)->Void)?
    var timingScale: Double = 1 // Production uses 1; renderer tests can shorten real animations.
    private var columns: [SolarReelColumnView] = []
    private var active: SolarReelJourney?
    private var pending: SolarReelJourney?
    private var finishedID: UUID?
    private var unfinished = Set<Int>()
    private var field: SolarReelField?
    private var phase = SolarCabinetSession.SolarMotion.quiet
    private var winning = Set<Int>()
    private var wilds: [SolarRocketWild] = []
    private var badges: [UUID:UIView] = [:]
    private var lastSize = CGSize.zero
    init(game: SolarCabinet) {
        self.game = game; super.init(frame:.zero); clipsToBounds = true
        for c in 0..<game.width {
            let well = SolarReelColumnView(game:game); well.backgroundColor = UIColor.white.withAlphaComponent(c%2 == 0 ? 0.035 : 0.012)
            columns.append(well); addSubview(well)
        }
    }
    required init?(coder: NSCoder) { fatalError("Use init(game:)") }
    var settledTokens: [SolarReelToken] { (0..<game.height).flatMap { row in columns.compactMap { $0.glyphs.indices.contains(row) ? $0.glyphs[row].token : nil } } }
    var settledViewIDs: [ObjectIdentifier] { (0..<game.height).flatMap { row in columns.compactMap { $0.glyphs.indices.contains(row) ? ObjectIdentifier($0.glyphs[row]) : nil } } }
    var movingColumns: Int { columns.filter(\.moving).count }
    var arrivalCellFrames: [CGRect] { columns.flatMap(\.arrivalFrames) }
    var restingCellFrames: [CGRect] { columns.flatMap { column in column.glyphs.map { $0.convert($0.bounds,to:column) } } }
    var rocketViews: [UUID:UIView] { badges }
    func solarApply(board: SolarReelField,journey: SolarReelJourney?,motion: SolarCabinetSession.SolarMotion,highlights: Set<Int>,rockets: [SolarRocketWild]) {
        phase = motion; winning = highlights; wilds = rockets
        if motion == .rolling, let journey = journey {
            if active?.id == journey.id { solarPlaceWilds(); return }
            if finishedID == journey.id { solarDecorate(); return }
            pending = journey
            if bounds.width > 0 { solarBegin(journey) }
            else { setNeedsLayout() }
            return
        }
        if active != nil || pending != nil { solarCancel() }
        solarShow(board,animated:motion == .falling); solarDecorate()
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        let changed = lastSize != bounds.size; lastSize = bounds.size
        let cell = bounds.width/CGFloat(game.width)
        for (c,column) in columns.enumerated() { column.frame = CGRect(x:CGFloat(c)*cell,y:0,width:cell,height:CGFloat(game.height)*cell); column.solarResize(cell:cell) }
        if changed, let live = active {
            solarCancel(); solarShow(live.destination,animated:false); finishedID = live.id; onLanding?(live.id)
        } else if active == nil, let pending = pending, bounds.width > 0 { solarBegin(pending) }
        if active == nil { solarDecorate() } else { solarPlaceWilds() }
    }
    private func solarShow(_ board: SolarReelField,animated: Bool) {
        for c in 0..<game.width { columns[c].solarDisplay(board.solarColumn(c),animated:animated) }
        field = board
    }
    private func solarBegin(_ trip: SolarReelJourney) {
        solarCancel(); solarShow(trip.source,animated:false); active = trip; unfinished = Set(0..<game.width)
        solarPlaceWilds()
        for c in 0..<game.width {
            columns[c].solarTravel(trip.ribbons[c],id:trip.id,duration:trip.solarDuration(column:c)*timingScale) { [weak self] in
                guard let self = self, self.active?.id == trip.id else { return }
                self.unfinished.remove(c)
                self.solarStyleColumn(c)
                if self.unfinished.isEmpty {
                    self.active = nil; self.field = trip.destination; self.finishedID = trip.id
                    self.solarDecorate()
                    self.onLanding?(trip.id)
                }
            }
        }
    }
    private func solarDecorate() {
        guard let field = field else { return }
        for c in 0..<game.width { solarStyleColumn(c) }
        solarPlaceWilds()
        accessibilityValue = field.tokens.map { "\($0.face):\($0.factor)" }.joined(separator:",")
    }
    private func solarStyleColumn(_ column: Int) {
        let occupied = Set(wilds.map { $0.row*game.width+$0.column })
        for (row,glyph) in columns[column].glyphs.enumerated() {
            let position = row*game.width+column
            glyph.accessibilityIdentifier = "reel_token_\(column)_\(row)"
            glyph.solarStyle(winning:winning.contains(position),motion:phase,covered:occupied.contains(position))
        }
    }
    private func solarPlaceWilds() {
        let cell = bounds.width/CGFloat(game.width)
        guard cell > 0 else { return }
        let wanted = Set(wilds.map(\.id))
        for id in Array(badges.keys) where !wanted.contains(id) { badges.removeValue(forKey:id)?.removeFromSuperview() }
        for wild in wilds {
            let badge: UIView
            if let old = badges[wild.id] { badge = old }
            else {
                let root = UIView(); root.layer.zPosition = 20
                let image = UIImageView(image:SolarArtworkDepot.shared.solarPicture("aurum-festival_6")); image.contentMode = .scaleAspectFit; image.autoresizingMask = [.flexibleWidth,.flexibleHeight]; root.addSubview(image)
                let hover = CAKeyframeAnimation(keyPath:"transform.translation.y"); hover.values = [-3,3,-3]; hover.duration = 1.6; hover.repeatCount = .infinity; image.layer.add(hover,forKey:"rocketHover")
                root.layer.shadowColor = UIColor.cyan.cgColor; root.layer.shadowOpacity = 0.45; root.layer.shadowRadius = 6; root.layer.shadowOffset = .zero
                let number = UILabel(); number.text = "×\(wild.boost)"; number.textColor = .white; number.font = .systemFont(ofSize:20,weight:.heavy); number.textAlignment = .center; number.tag = 91; root.addSubview(number)
                root.accessibilityLabel = "Rocket wild ×\(wild.boost)"; root.isAccessibilityElement = true
                root.accessibilityIdentifier = "rocket_wild_\(wild.id.uuidString)"
                badges[wild.id] = root; addSubview(root); badge = root
            }
            badge.isHidden = false
            let target = CGRect(x:CGFloat(wild.column)*cell,y:CGFloat(wild.row)*cell,width:cell,height:cell)
            if badge.frame == .zero { badge.frame = target }
            else if badge.frame != target { UIView.animate(withDuration:phase == .rolling ? (active?.fast == true ? 0.34 : 0.82) : 0.42,delay:0,options:[.curveEaseInOut,.beginFromCurrentState]) { badge.frame = target } }
            badge.subviews.first?.frame = badge.bounds.insetBy(dx:2,dy:2)
            badge.viewWithTag(91)?.frame = CGRect(x:0,y:cell*0.52,width:cell,height:28)
        }
    }
    func solarCancel() { active = nil; pending = nil; unfinished = []; columns.forEach { $0.solarStop() } }
}

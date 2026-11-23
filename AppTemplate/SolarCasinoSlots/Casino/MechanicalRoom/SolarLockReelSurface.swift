import SwiftUI
import UIKit

struct SolarLockReelSurface: UIViewRepresentable {
    let contract: SolarLockContract
    let journey: SolarLockJourney?
    let onLanding: (UUID)->Void
    func makeUIView(context: Context) -> SolarLockReelSurfaceView { SolarLockReelSurfaceView() }
    func updateUIView(_ view: SolarLockReelSurfaceView,context: Context) {
        view.onLanding = onLanding; view.solarApply(contract:contract,journey:journey)
    }
    static func dismantleUIView(_ view: SolarLockReelSurfaceView,coordinator: ()) { view.onLanding = nil; view.solarCancel() }
}

private final class SolarLockCoinView: UIView {
    let medal: SolarLockedMedal?
    private let picture = UIImageView()
    private let plate = UIView()
    private let value = UILabel()
    private let tier = UILabel()
    init(_ medal: SolarLockedMedal?) {
        self.medal = medal; super.init(frame:.zero)
        picture.contentMode = .scaleAspectFit
        if let medal = medal {
            picture.image = SolarArtworkDepot.shared.solarPicture("aurum-dynamo_0")
            value.text = medal.value.compact; value.textColor = .white; value.textAlignment = .center
            if let kind = medal.tier {
                tier.text = ["MINI","MINOR","MAJOR"][kind]
                tier.textColor = [UIColor.systemPurple,.cyan,.systemGreen][kind]
            }
            tier.textAlignment = .center; plate.backgroundColor = UIColor.black.withAlphaComponent(0.62)
            addSubview(picture); addSubview(plate); plate.addSubview(value); plate.addSubview(tier)
            layer.shadowColor = UIColor.orange.cgColor; layer.shadowOpacity = 0.45; layer.shadowRadius = 8; layer.shadowOffset = .zero
            accessibilityLabel = "Locked coin"; accessibilityValue = "\(medal.value)"+(tier.text.map { " \($0)" } ?? "")
        } else {
            picture.image = UIImage(systemName:"bolt.fill"); picture.tintColor = UIColor.cyan.withAlphaComponent(0.13)
            addSubview(picture); accessibilityLabel = "Empty position"
        }
        isAccessibilityElement = true
    }
    required init?(coder: NSCoder) { fatalError("Use init(medal:)") }
    override func layoutSubviews() {
        super.layoutSubviews()
        if medal == nil { picture.frame = CGRect(x:bounds.midX-10,y:bounds.midY-12,width:20,height:24); return }
        picture.frame = bounds.insetBy(dx:4,dy:4)
        let hasTier = tier.text != nil
        let height = bounds.width*(hasTier ? 0.43 : 0.29)
        plate.frame = CGRect(x:bounds.width*0.12,y:bounds.midY-height*0.35,width:bounds.width*0.76,height:height)
        plate.layer.cornerRadius = height*0.3
        tier.font = .systemFont(ofSize:max(9,bounds.width*0.12),weight:.heavy)
        value.font = .systemFont(ofSize:bounds.width*0.23,weight:.heavy); value.adjustsFontSizeToFitWidth = true; value.minimumScaleFactor = 0.5
        tier.frame = CGRect(x:2,y:1,width:plate.bounds.width-4,height:hasTier ? height*0.36 : 0)
        value.frame = CGRect(x:3,y:hasTier ? height*0.32 : 0,width:plate.bounds.width-6,height:hasTier ? height*0.68 : height)
    }
    func solarIlluminate() {
        guard medal != nil else { return }
        let flash = CAKeyframeAnimation(keyPath:"shadowOpacity"); flash.values = [0.4,1,0.45]; flash.duration = 0.42
        layer.add(flash,forKey:"newLock")
    }
}

private final class SolarLockPositionView: UIView {
    private(set) var resting: SolarLockCoinView?
    private var strip: UIView?
    private var animator: UIViewPropertyAnimator?
    private var generation: UUID?
    private let ring = CAShapeLayer()
    var moving: Bool { strip != nil }
    var presentationOffset: CGFloat? { strip?.layer.presentation()?.affineTransform().ty }
    override init(frame: CGRect) {
        super.init(frame:frame); clipsToBounds = true
        ring.fillColor = UIColor.clear.cgColor; ring.strokeColor = UIColor.orange.withAlphaComponent(0.15).cgColor; ring.lineWidth = 1; layer.addSublayer(ring)
    }
    required init?(coder: NSCoder) { fatalError("Use init(frame:)") }
    override func layoutSubviews() {
        super.layoutSubviews(); ring.path = UIBezierPath(ovalIn:bounds.insetBy(dx:8,dy:8)).cgPath
        if !moving { resting?.frame = bounds }
    }
    func solarDisplay(_ medal: SolarLockedMedal?) {
        guard moving || resting == nil || resting?.medal != medal || resting?.superview !== self else { return }
        solarStop(); resting?.removeFromSuperview()
        let glyph = SolarLockCoinView(medal); glyph.frame = bounds; addSubview(glyph); resting = glyph
    }
    func solarTravel(_ entries: [SolarLockedMedal?],id: UUID,duration: TimeInterval,done: @escaping ()->Void) {
        solarStop(); generation = id
        let track = UIView(frame:CGRect(x:0,y:0,width:bounds.width,height:bounds.height*CGFloat(entries.count)))
        var destination: SolarLockCoinView!
        for (offset,medal) in entries.enumerated() {
            let glyph = offset == 0 ? (resting ?? SolarLockCoinView(nil)) : SolarLockCoinView(medal)
            glyph.isAccessibilityElement = false; track.addSubview(glyph)
            glyph.frame = CGRect(x:0,y:CGFloat(offset)*bounds.height,width:bounds.width,height:bounds.height)
            if offset == entries.count-1 { destination = glyph }
        }
        strip = track; addSubview(track)
        let travel = UIViewPropertyAnimator(duration:duration,controlPoint1:CGPoint(x:0.12,y:0.6),controlPoint2:CGPoint(x:0.18,y:1))
        animator = travel
        travel.addAnimations { track.transform = CGAffineTransform(translationX:0,y:-CGFloat(entries.count-1)*self.bounds.height) }
        travel.addCompletion { [weak self] position in
            guard let self = self, self.generation == id, position == .end, let glyph = destination else { return }
            UIView.performWithoutAnimation {
                self.addSubview(glyph); glyph.frame = self.bounds; glyph.isAccessibilityElement = true; self.resting = glyph
                self.strip?.removeFromSuperview(); self.strip = nil; self.animator = nil; self.generation = nil
            }
            glyph.solarIlluminate(); done()
        }
        travel.startAnimation()
    }
    func solarStop() { generation = nil; animator?.stopAnimation(true); animator = nil; strip?.removeFromSuperview(); strip = nil }
}

final class SolarLockReelSurfaceView: UIView {
    var onLanding: ((UUID)->Void)?
    private let positions = (0..<9).map { _ in SolarLockPositionView(frame:.zero) }
    private var active: SolarLockJourney?
    private var pending: SolarLockJourney?
    private var finished: UUID?
    private var unfinished = Set<Int>()
    private var lastSize = CGSize.zero
    var movingIndices: Set<Int> { Set(positions.indices.filter { positions[$0].moving }) }
    var visibleMedals: [SolarLockedMedal] { positions.compactMap { $0.resting?.medal } }
    var restingViewIDs: [ObjectIdentifier?] { positions.map { $0.resting.map(ObjectIdentifier.init) } }
    var travelOffsets: [CGFloat] { positions.compactMap(\.presentationOffset) }
    override init(frame: CGRect) { super.init(frame:frame); positions.forEach(addSubview) }
    convenience init() { self.init(frame:.zero) }
    required init?(coder: NSCoder) { fatalError("Use init(frame:)") }
    func solarApply(contract: SolarLockContract,journey: SolarLockJourney?) {
        if let trip = journey {
            guard active?.id != trip.id, finished != trip.id else { return }
            pending = trip
            if bounds.width > 0 { layoutIfNeeded(); solarBegin(trip) } else { setNeedsLayout() }
        } else { solarCancel(); solarShow(contract) }
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        let resized = lastSize != bounds.size; lastSize = bounds.size
        let size = bounds.width/3
        for (index,position) in positions.enumerated() {
            position.frame = CGRect(x:CGFloat(index%3)*size,y:CGFloat(index/3)*size,width:size,height:size)
            position.layoutIfNeeded()
        }
        if resized, let trip = active { solarCancel(); solarShow(trip.destination); finished = trip.id; onLanding?(trip.id) }
        else if active == nil, let pending = pending, bounds.width > 0 { solarBegin(pending) }
    }
    private func solarShow(_ contract: SolarLockContract) {
        for index in 0..<9 {
            positions[index].solarDisplay(contract.medals.first { $0.index == index })
            positions[index].resting?.accessibilityIdentifier = "lock_coin_\(index)"
        }
    }
    private func solarBegin(_ trip: SolarLockJourney) {
        // layoutIfNeeded may already have begun this pending journey.
        guard active?.id != trip.id, finished != trip.id else { return }
        solarCancel(); solarShow(trip.source); active = trip; unfinished = Set(trip.ribbons.keys)
        for index in trip.ribbons.keys.sorted() {
            positions[index].solarTravel(trip.ribbons[index]!,id:trip.id,duration:trip.solarDuration(index:index)) { [weak self] in
                guard let self = self, self.active?.id == trip.id else { return }
                self.positions[index].resting?.accessibilityIdentifier = "lock_coin_\(index)"
                self.unfinished.remove(index)
                if self.unfinished.isEmpty { self.active = nil; self.finished = trip.id; self.onLanding?(trip.id) }
            }
        }
    }
    func solarCancel() { active = nil; pending = nil; unfinished = []; positions.forEach { $0.solarStop() } }
}

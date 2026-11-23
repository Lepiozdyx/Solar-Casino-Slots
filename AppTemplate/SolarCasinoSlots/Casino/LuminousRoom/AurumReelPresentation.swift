import SwiftUI
import UIKit

struct AurumMotionCue {
    let id = UUID()
    let room: AurumRoom
    let from: [AurumTile]
    let to: [AurumTile]
    let removed: Set<Int>
    let duration: Double
    let seed: UInt64
    var rolling: Bool { removed.isEmpty }
}
struct AurumDrumPlan {
    let tokens: [AurumTile]
    let rows: Int
    var stopIndex: Int { tokens.count-rows }
    init(room: AurumRoom,from: [AurumTile],to: [AurumTile],column: Int,seed: UInt64) {
        rows = room.rows
        var dice = AurumDice(seed &+ UInt64(column+1)*391)
        let head = (0..<room.rows).map{from[$0*room.columns+column]}
        let end = (0..<room.rows).map{to[$0*room.columns+column]}
        let between = (0..<((5+column)*room.rows)).map{_ in AurumReelArithmetic.solarTile(room,&dice,special:false)}
        tokens = head+between+end
    }
    var arrival: [AurumTile] { Array(tokens.suffix(rows)) }
}
struct AurumReelSurface: UIViewRepresentable {
    let room: AurumRoom
    let board: [AurumTile]
    let cue: AurumMotionCue?
    var highlighted: Set<Int> = []
    func makeUIView(context: Context) -> AurumReelCabinet { let view = AurumReelCabinet();view.room = room;return view }
    func updateUIView(_ view: AurumReelCabinet,context: Context) { view.solarConfigure(room:room,board:board,cue:cue,highlighted:highlighted) }
    static func dismantleUIView(_ view: AurumReelCabinet,coordinator: ()) { view.solarStop() }
}
final class AurumReelCabinet: UIView {
    var room: AurumRoom = .redline
    private var visible: [AurumTile] = []
    private var images: [UUID:UIImageView] = [:]
    private var drums: [UIView] = []
    private var plans: [AurumDrumPlan] = []
    private var clock: CADisplayLink?
    private var started: CFTimeInterval = 0
    private var activeCue: AurumMotionCue?
    private var lastID: UUID?
    private var lastSize = CGSize.zero
    private var highlights: Set<Int> = []
    override init(frame: CGRect) { super.init(frame:frame);clipsToBounds = true;layer.cornerRadius = 13;backgroundColor = UIColor(red:0.03,green:0.07,blue:0.14,alpha:1);isAccessibilityElement = false }
    required init?(coder: NSCoder) { fatalError() }
    func solarConfigure(room: AurumRoom,board: [AurumTile],cue: AurumMotionCue?,highlighted: Set<Int>) {
        self.room = room;highlights = highlighted
        if cue==nil && activeCue != nil { solarStop();solarShow(board) }
        if let cue = cue,cue.id != lastID { lastID = cue.id;layoutIfNeeded();solarPlay(cue) }
        else if activeCue==nil && visible.map(\.id) != board.map(\.id) { solarShow(board) }
        if activeCue==nil { solarPaintHighlights() }
    }
    private var unit: CGSize { CGSize(width:bounds.width/CGFloat(room.columns),height:bounds.height/CGFloat(room.rows)) }
    private func solarSlot(_ index: Int) -> CGRect { CGRect(x:CGFloat(index%room.columns)*unit.width+3,y:CGFloat(index/room.columns)*unit.height+3,width:unit.width-6,height:unit.height-6) }
    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.size != lastSize,bounds.width>0 else { return };lastSize = bounds.size
        if let cue = activeCue { clock?.invalidate();clock = nil;activeCue = nil;solarShow(cue.to) } else { solarShow(visible) }
    }
    private func solarPicture(_ token: AurumTile) -> UIImageView {
        let view = UIImageView(image:AurumArtwork.shared.solarGet(token.mark.art));view.contentMode = .scaleAspectFit;view.layer.cornerRadius = 10;view.backgroundColor = UIColor.white.withAlphaComponent(0.025);view.layer.borderWidth = 1;view.layer.borderColor = UIColor.white.withAlphaComponent(0.06).cgColor;view.accessibilityLabel = String(describing:token.mark);return view
    }
    private func solarShow(_ board: [AurumTile]) {
        subviews.forEach{$0.removeFromSuperview()};images = [:];drums = [];visible = board
        guard board.count==room.columns*room.rows else { return }
        for (index,token) in board.enumerated() { let image = solarPicture(token);image.frame = solarSlot(index);addSubview(image);images[token.id] = image }
        solarPaintHighlights()
    }
    private func solarPaintHighlights() {
        for (index,token) in visible.enumerated() { images[token.id]?.layer.borderColor = highlights.contains(index) ? UIColor(red:1,green:0.42,blue:0.35,alpha:0.95).cgColor:UIColor.white.withAlphaComponent(0.06).cgColor;images[token.id]?.layer.borderWidth = highlights.contains(index) ? 2:1 }
    }
    private func solarPlay(_ cue: AurumMotionCue) {
        solarStop();activeCue = cue;visible = cue.from
        if cue.duration<0.5 {
            solarShow(cue.from);activeCue = cue
            UIView.transition(with:self,duration:cue.duration,options:[.transitionCrossDissolve,.allowAnimatedContent]) { self.solarShow(cue.to) } completion: { [weak self] _ in if self?.activeCue?.id==cue.id { self?.activeCue = nil } }
            return
        }
        if cue.rolling {
            subviews.forEach{$0.removeFromSuperview()};images = [:]
            plans = (0..<room.columns).map{AurumDrumPlan(room:room,from:cue.from,to:cue.to,column:$0,seed:cue.seed)}
            for col in 0..<room.columns {
                let wrapper = UIView(frame:CGRect(x:CGFloat(col)*unit.width,y:0,width:unit.width,height:bounds.height));wrapper.clipsToBounds = true;addSubview(wrapper)
                let drum = UIView(frame:CGRect(x:0,y:0,width:unit.width,height:CGFloat(plans[col].tokens.count)*unit.height));wrapper.addSubview(drum);drums.append(drum)
                for (row,token) in plans[col].tokens.enumerated() { let image = solarPicture(token);image.frame = CGRect(x:3,y:CGFloat(row)*unit.height+3,width:unit.width-6,height:unit.height-6);drum.addSubview(image) }
            }
            started = CACurrentMediaTime();clock = CADisplayLink(target:self,selector:#selector(solarTick));clock?.add(to:.main,forMode:.common)
        } else { solarCollapse(cue) }
    }
    @objc private func solarTick() {
        guard let cue = activeCue else { return }
        let elapsed = CACurrentMediaTime()-started
        for col in drums.indices {
            let duration = max(0.1,cue.duration-Double(room.columns-1-col)*0.11),t = min(1,elapsed/duration)
            let ease: Double
            if t<0.16 { ease = 0.5*t*t/0.16 } else { let u = (t-0.16)/0.84;ease = 0.08+0.92*(1-pow(1-u,2.5)) }
            drums[col].frame.origin.y = -CGFloat(ease)*CGFloat(plans[col].stopIndex)*unit.height
        }
        if elapsed>=cue.duration { clock?.invalidate();clock = nil;activeCue = nil;solarShow(cue.to) }
    }
    private func solarCollapse(_ cue: AurumMotionCue) {
        solarShow(cue.from);activeCue = cue
        let duration = cue.duration
        for index in cue.removed where cue.from.indices.contains(index) {
            guard let view = images[cue.from[index].id] else { continue }
            let shake = CAKeyframeAnimation(keyPath:"transform.rotation.z");shake.values = [0,-0.09,0.09,-0.08,0.08,0];shake.duration = duration*0.38;view.layer.add(shake,forKey:"shake")
        }
        DispatchQueue.main.asyncAfter(deadline:.now()+duration*0.4) { [weak self] in
            guard let self = self,self.activeCue?.id==cue.id else { return }
            UIView.animate(withDuration:duration*0.17) { for index in cue.removed { let image = self.images[cue.from[index].id];image?.alpha = 0;image?.transform = CGAffineTransform(scaleX:0.15,y:0.15) } }
            DispatchQueue.main.asyncAfter(deadline:.now()+duration*0.18) { [weak self] in
                guard let self = self,self.activeCue?.id==cue.id else { return }
                let old = self.images;var next: [UUID:UIImageView] = [:]
                for (index,token) in cue.to.enumerated() {
                    let image = old[token.id] ?? self.solarPicture(token)
                    if old[token.id]==nil { var rect = self.solarSlot(index);rect.origin.y -= self.bounds.height;image.frame = rect;self.addSubview(image) }
                    next[token.id] = image
                }
                for (id,image) in old where next[id]==nil { image.removeFromSuperview() }
                self.images = next
                UIView.animate(withDuration:duration*0.4,delay:0,options:[.curveEaseOut,.beginFromCurrentState]) { for (index,token) in cue.to.enumerated() { next[token.id]?.frame = self.solarSlot(index) } } completion: { _ in guard self.activeCue?.id==cue.id else { return };self.activeCue = nil;self.visible = cue.to;self.solarPaintHighlights() }
            }
        }
    }
    func solarStop() { clock?.invalidate();clock = nil;layer.removeAllAnimations();activeCue = nil;subviews.forEach{$0.layer.removeAllAnimations()};drums = [];plans = [] }
    deinit { clock?.invalidate() }
}

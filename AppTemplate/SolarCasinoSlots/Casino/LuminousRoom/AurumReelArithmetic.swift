import Foundation

enum AurumReelArithmetic {
    static let classicPaths = [[1,1,1],[0,0,0],[2,2,2],[0,1,2],[2,1,0]]
    static let orbitalPaths = [[1,1,1,1,1],[0,0,0,0,0],[2,2,2,2,2],[0,1,2,1,0],[2,1,0,1,2],[0,0,1,2,2],[2,2,1,0,0],[1,0,0,0,1],[1,2,2,2,1],[0,1,1,1,0],[2,1,1,1,2],[1,0,1,2,1],[1,2,1,0,1],[0,1,0,1,0],[2,1,2,1,2]]
    static let orbitPath = [0,1,2,3,4,9,14,13,12,11,10,5]
    static func solarTile(_ room: AurumRoom,_ dice: inout AurumDice,special: Bool = true) -> AurumTile {
        let pick = dice.solarNext(1000)
        if special && pick<21 { return .init(.scatter) }
        if room != .prism && special && pick<48 { return .init(.wild) }
        let weights = room == .prism ? [21,19,18,16,14,12]:[26,23,19,15,11,6]
        var target = dice.solarNext(100)
        for (i,weight) in weights.enumerated() { target -= weight;if target<0 { return .init(room.ordinary[i]) } }
        return .init(room.ordinary.last!)
    }
    static func solarBoard(_ room: AurumRoom,seed: UInt64) -> [AurumTile] { var dice = AurumDice(seed);return (0..<room.columns*room.rows).map{_ in solarTile(room,&dice,special:false)} }
    static func solarClusters(_ board: [AurumTile],columns: Int = 5) -> [[Int]] {
        guard board.count%columns==0 else { return [] }
        let rows = board.count/columns
        var visited: Set<Int> = [],groups: [[Int]] = []
        for start in board.indices where !visited.contains(start) && board[start].mark != .scatter {
            let mark = board[start].mark
            var group = [start],cursor = 0;visited.insert(start)
            while cursor<group.count {
                let cell = group[cursor],x = cell%columns,y = cell/columns
                let neighbours = [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]
                for (nx,ny) in neighbours where nx>=0 && nx<columns && ny>=0 && ny<rows {
                    let index = ny*columns+nx
                    if !visited.contains(index) && board[index].mark==mark { visited.insert(index);group.append(index) }
                };cursor += 1
            }
            if group.count>=5 { groups.append(group) }
        }
        return groups
    }
    static func solarClusterNumerator(_ count: Int) -> Int { count>=12 ? 4600:count>=10 ? 2900:count>=8 ? 1450:count>=7 ? 920:count>=6 ? 520:260 }
    static func solarClusterFactor(_ count: Int) -> Double { Double(solarClusterNumerator(count))/100 }
    static func solarDrop(_ board: [AurumTile],removed: Set<Int>,dice: inout AurumDice) -> [AurumTile] {
        var next = board
        for col in 0..<5 {
            let kept = (0..<4).map{$0*5+col}.filter{!removed.contains($0)}.map{board[$0]}
            let fresh = (0..<(4-kept.count)).map{_ in solarTile(.prism,&dice)}
            for (row,value) in (fresh+kept).enumerated() { next[row*5+col] = value }
        };return next
    }
    static func solarLineNumerator(_ mark: AurumMark,room: AurumRoom) -> Int {
        let rank = room.ordinary.firstIndex(of:mark) ?? 5
        return (room == .redline ? [230,260,360,460,650,1300]:[45,50,70,90,125,250])[rank]
    }
    static func solarLineBase(_ mark: AurumMark,room: AurumRoom) -> Double { Double(solarLineNumerator(mark,room:room))/100 }
    static func solarLineAwards(_ board: [AurumTile],room: AurumRoom,stake: Int,free: Bool) -> [AurumLineAward] {
        let paths = room == .redline ? classicPaths:orbitalPaths
        var awards: [AurumLineAward] = []
        for path in paths {
            let indices = path.enumerated().map{$0.element*room.columns+$0.offset}
            let marks = indices.map{board[$0].mark}
            guard let match = marks.first(where:{$0 != .wild}) ?? marks.first,match != .scatter else { continue }
            var length = 0
            for mark in marks { if mark==match || mark == .wild { length += 1 } else { break } }
            guard length>=3 else { continue }
            let numerator = solarLineNumerator(match,room:room)*(length==5 ? 8:length==4 ? 3:1)*(room == .redline && free ? 2:1)
            let amount = max(1,stake*numerator/100)
            awards.append(.init(indices:Array(indices.prefix(length)),amount:amount))
        };return awards
    }
    static func solarRoll(_ room: AurumRoom,stake: Int,feature: AurumFeature?,seed: UInt64) -> AurumReelResult {
        precondition(room.isSlot && stake>0)
        var dice = AurumDice(seed),opening = (0..<room.columns*room.rows).map{_ in solarTile(room,&dice)}
        let free = feature != nil
        let orbit: Int? = room == .orbit && free ? orbitPath[(feature!.orbit)%orbitPath.count]:nil
        if room == .redline && free { opening[4] = .init(.wild) }
        if let orbit = orbit { opening[orbit] = .init(.wild) }
        var current = opening,falls: [AurumFall] = [],lines: [AurumLineAward] = [],payout = 0
        if room == .prism {
            for depth in 0..<6 {
                let groups = solarClusters(current)
                if groups.isEmpty { break }
                let removed = Set(groups.flatMap{$0}),boost = (free ? 2:1)+depth
                let amount = groups.reduce(0){$0+max(1,stake*solarClusterNumerator($1.count)*boost/100)}
                let next = solarDrop(current,removed:removed,dice:&dice)
                falls.append(.init(before:current,after:next,removed:removed.sorted(),amount:amount,boost:boost));payout += amount;current = next
            }
        } else { lines = solarLineAwards(current,room:room,stake:stake,free:free);payout = lines.reduce(0){$0+$1.amount} }
        let scatters = opening.filter{$0.mark == .scatter}.count
        let awarded = scatters>=3 ? (free ? 3:room.freeTurns):0
        return .init(id:UUID(),room:room,stake:stake,free:free,seed:seed,entrance:opening,final:current,falls:falls,lines:lines,payout:payout,awarded:awarded,orbit:orbit)
    }
}

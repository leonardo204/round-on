import Foundation
import Observation

// MARK: - ScoreCardViewModel
// 4×18 스코어카드 그리드 파생 상태 (22-STATE_MANAGEMENT §3)
// ScoreCell.split9x2 변형 기준 (12-SCREENS D-1)

@Observable
@MainActor
public final class ScoreCardViewModel {

    // MARK: State (캐시)

    /// 플레이어별 홀별 카운트 캐시: [playerId: [holeNumber(1-based): count]]
    public private(set) var countsCache: [UUID: [Int: Int]] = [:]
    /// 플레이어별 총 타수
    public private(set) var totalByPlayer: [UUID: Int] = [:]
    /// 플레이어별 vs par 합계
    public private(set) var vsParByPlayer: [UUID: Int] = [:]
    /// 홀별 par 배열 [holeNumber(1-based): par]
    public private(set) var parByHole: [Int: Int] = [:]
    /// 플레이어 목록 (순서 보존)
    public private(set) var players: [Player] = []
    /// 전체 홀 수
    public private(set) var totalHoles: Int = 18

    // MARK: Init

    public init(round: Round) {
        refresh(from: round)
    }

    // MARK: Computed

    /// OUT(1-9) 구간 홀 번호 목록
    public var outHoles: [Int] { (1...min(9, totalHoles)).map { $0 } }

    /// IN(10-18) 구간 홀 번호 목록
    public var inHoles: [Int] {
        guard totalHoles > 9 else { return [] }
        return (10...min(18, totalHoles)).map { $0 }
    }

    /// 플레이어-구간 소계: OUT 합계
    public func outTotal(for playerId: UUID) -> Int {
        outHoles.reduce(0) { $0 + (countsCache[playerId]?[$1] ?? 0) }
    }

    /// 플레이어-구간 소계: IN 합계
    public func inTotal(for playerId: UUID) -> Int {
        inHoles.reduce(0) { $0 + (countsCache[playerId]?[$1] ?? 0) }
    }

    /// OUT 구간 par 합계
    public var outParTotal: Int {
        outHoles.reduce(0) { $0 + (parByHole[$1] ?? 4) }
    }

    /// IN 구간 par 합계
    public var inParTotal: Int {
        inHoles.reduce(0) { $0 + (parByHole[$1] ?? 4) }
    }

    /// 전체 par 합계
    public var totalPar: Int { outParTotal + inParTotal }

    // MARK: Score vs Par 표시 헬퍼

    /// "110 (+38)" / "72 (E)" / "70 (-2)" 형식 문자열 반환
    public static func formatScoreVsPar(score: Int, par: Int) -> (text: String, parity: Int) {
        guard score > 0 else { return ("-", 0) }
        let diff = score - par
        let diffStr: String
        if diff == 0 { diffStr = "E" }
        else if diff > 0 { diffStr = "+\(diff)" }
        else { diffStr = "\(diff)" }
        return ("\(score) (\(diffStr))", diff)
    }

    // MARK: Refresh (SwiftData → 캐시 갱신)

    /// Round 변경 시 캐시 재빌드
    public func refresh(from round: Round) {
        players = round.playerList.sorted { $0.order < $1.order }
        totalHoles = round.holeList.count

        var newPar: [Int: Int] = [:]
        for holeScore in round.holeList {
            newPar[holeScore.holeNumber] = holeScore.par
        }
        parByHole = newPar

        var newCounts: [UUID: [Int: Int]] = [:]
        var newTotals: [UUID: Int] = [:]
        var newVsPar: [UUID: Int] = [:]

        for player in players {
            var holeMap: [Int: Int] = [:]
            var total = 0
            var vsPar = 0

            for holeScore in round.holeList {
                let c = holeScore.count(for: player.id)
                holeMap[holeScore.holeNumber] = c
                total += c
                if c > 0 {
                    vsPar += c - (parByHole[holeScore.holeNumber] ?? 4)
                }
            }
            newCounts[player.id] = holeMap
            newTotals[player.id] = total
            newVsPar[player.id] = vsPar
        }

        countsCache = newCounts
        totalByPlayer = newTotals
        vsParByPlayer = newVsPar
    }

    // MARK: Helpers

    /// 특정 홀-플레이어 카운트
    public func count(holeNumber: Int, playerId: UUID) -> Int {
        countsCache[playerId]?[holeNumber] ?? 0
    }

    /// par 대비 차이
    public func vsParForHole(holeNumber: Int, playerId: UUID) -> Int? {
        let c = count(holeNumber: holeNumber, playerId: playerId)
        guard c > 0, let par = parByHole[holeNumber] else { return nil }
        return c - par
    }

    /// par 대비 색상 분류
    public func scoreCategory(holeNumber: Int, playerId: UUID) -> ScoreCategory {
        guard let diff = vsParForHole(holeNumber: holeNumber, playerId: playerId) else {
            return .empty
        }
        switch diff {
        case ...(-2): return .eagle
        case -1:      return .birdie
        case 0:       return .par
        case 1:       return .bogey
        default:      return .doublePlus
        }
    }
}

// MARK: - ScoreCategory
// par 대비 색상 분류 (11-COMPONENTS §6, 10-DESIGN_SYSTEM §2)

public enum ScoreCategory: String, Sendable {
    case empty       // 미입력
    case eagle       // ≤par-2: 진한 그린 원형
    case birdie      // par-1: 연한 그린 원형
    case par         // 기본
    case bogey       // par+1: 연한 적색
    case doublePlus  // ≥par+2: 진한 적색
}

// MARK: - ParDiff
// VoiceOver 용어 + 모양 이중 부호화 (14-ACCESSIBILITY §7)

public enum ParDiff: Sendable {
    case eagle          // ≤ par - 2
    case birdie         // par - 1
    case par            // == par
    case bogey          // par + 1
    case doublePlus     // ≥ par + 2
    case notEntered     // count == 0

    public static func from(count: Int, par: Int) -> ParDiff {
        guard count > 0 else { return .notEntered }
        let diff = count - par
        switch diff {
        case ...(-2):   return .eagle
        case -1:        return .birdie
        case 0:         return .par
        case 1:         return .bogey
        default:        return .doublePlus
        }
    }

    /// VoiceOver 발화 텍스트 (14-ACCESSIBILITY §2 par-diff 용어)
    public var voiceOverTerm: String {
        switch self {
        case .eagle:        return "이글"
        case .birdie:       return "버디"
        case .par:          return "파"
        case .bogey:        return "보기"
        case .doublePlus:   return "더블 보기 이상"
        case .notEntered:   return "미입력"
        }
    }

    /// par-diff 모양 부호화 (14-ACCESSIBILITY §7)
    /// 마커: 셀 높이 30% 이내(약 13pt), 숫자 우상단 배치
    public var shapeSymbol: String? {
        switch self {
        case .eagle:        return "◎"   // 이중원
        case .birdie:       return "●"   // 단원
        case .par:          return nil   // 없음
        case .bogey:        return "■"   // 단사각
        case .doublePlus:   return "▣"   // 이중사각
        case .notEntered:   return nil
        }
    }
}

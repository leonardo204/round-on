import Foundation
import SwiftData

/// ScoreEntry: [UUID: Int] 대신 배열 사용 (SwiftData 딕셔너리 영속화 제한 대응)
/// 21-DATA_MODEL §10 fallback 적용
public struct ScoreEntry: Codable, Sendable, Equatable {
    public var playerId: UUID
    public var value: Int

    public init(playerId: UUID, value: Int) {
        self.playerId = playerId
        self.value = value
    }
}

@Model
public final class HoleScore {
    // MARK: - CloudKit 호환 속성 (모두 default 값 제공)
    public var holeNumber: Int = 0
    public var par: Int = 4
    public var counts: [ScoreEntry] = []
    public var obCount: [ScoreEntry] = []
    public var hazardCount: [ScoreEntry] = []

    /// 홀 완료 후 실수 입력 방지 잠금. 다음 홀 이동 시 자동 true.
    /// SwiftData lightweight migration 안전 — default false, 기존 레코드 영향 없음.
    public var isLocked: Bool = false

    // MARK: - CloudKit 호환 inverse 관계
    public var round: Round?

    public init(holeNumber: Int = 0, par: Int = 4, counts: [ScoreEntry] = [], obCount: [ScoreEntry] = [], hazardCount: [ScoreEntry] = []) {
        self.holeNumber = holeNumber
        self.par = par
        self.counts = counts
        self.obCount = obCount
        self.hazardCount = hazardCount
        self.isLocked = false
    }

    /// playerId로 타수 조회
    public func count(for playerId: UUID) -> Int {
        counts.first(where: { $0.playerId == playerId })?.value ?? 0
    }

    /// playerId로 OB 횟수 조회
    public func ob(for playerId: UUID) -> Int {
        obCount.first(where: { $0.playerId == playerId })?.value ?? 0
    }

    /// playerId로 해저드 횟수 조회
    public func hazard(for playerId: UUID) -> Int {
        hazardCount.first(where: { $0.playerId == playerId })?.value ?? 0
    }
}

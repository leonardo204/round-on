import XCTest
import SwiftData
@testable import Shared

// MARK: - StatsSharePayloadTests
// StatsSharePayload wire types + Builder + RegionCentroidLUT + PII 가드 검증

final class StatsSharePayloadTests: XCTestCase {

    // MARK: - 헬퍼

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Round.self, Player.self, HoleScore.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    /// 완료 라운드 픽스처 생성
    @MainActor
    private func makeFinishedRound(
        ctx: ModelContext,
        courseId: String,
        courseName: String,
        holesCount: Int = 9,
        scorePerHole: Int = 5,
        par: Int = 4,
        finishedAt: Date = .now
    ) -> Round {
        let player = Player(name: "나", isOwner: true)
        ctx.insert(player)
        let round = Round(courseId: courseId, courseName: courseName)
        round.isFinished = true
        round.finishedAt = finishedAt
        ctx.insert(round)
        round.players = [player]
        var holeList: [HoleScore] = []
        for h in 1...holesCount {
            let hole = HoleScore(holeNumber: h, par: par)
            hole.counts.append(ScoreEntry(playerId: player.id, value: scorePerHole))
            ctx.insert(hole)
            holeList.append(hole)
        }
        round.holes = holeList
        return round
    }

    /// 기본 stats 픽스처 (3라운드, 핸디캡 산출 가능)
    @MainActor
    private func makeBasicStats(ctx: ModelContext) throws -> RoundStatisticsResult {
        let base = Date(timeIntervalSinceNow: -86400 * 30)
        var rounds: [Round] = []
        let scores = [82, 86, 88, 90, 92, 94, 96, 98]
        for (i, total) in scores.enumerated() {
            let player = Player(name: "나", isOwner: true)
            ctx.insert(player)
            let round = Round(courseId: "basic\(i)", courseName: "테스트장\(i)")
            round.isFinished = true
            round.finishedAt = base.addingTimeInterval(Double(i) * 86400)
            ctx.insert(round)
            round.players = [player]
            let base18 = total / 18
            let rem = total % 18
            var holeList: [HoleScore] = []
            for h in 1...18 {
                let s = h <= rem ? base18 + 1 : base18
                let hole = HoleScore(holeNumber: h, par: 4)
                hole.counts.append(ScoreEntry(playerId: player.id, value: s))
                ctx.insert(hole)
                holeList.append(hole)
            }
            round.holes = holeList
            rounds.append(round)
        }
        try ctx.save()
        return aggregateStatistics(rounds: rounds)
    }

    // MARK: - T1. PII 배제 검증

    /// JSON encode 후 결과 문자열에 PII 키워드 포함되지 않음 단언
    @MainActor
    func test_payloadBuilder_excludesPII() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let stats = try makeBasicStats(ctx: ctx)

        let regionStats = [RegionStats(regionKey: "경기", displayName: "경기도", roundCount: 3)]
        let payload = StatsSharePayloadBuilder.build(
            cardKind: .pr,
            stats: stats,
            regionStats: regionStats,
            rawDisplayName: "골퍼닉네임",
            nowISO: "2026-05-27T12:00:00Z"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(payload)
        let jsonString = String(data: data, encoding: .utf8) ?? ""

        // PII 키워드가 JSON 키(key)로 나타나면 안 됨
        let piiKeywords = ["courseId", "clubhouseLat", "clubhouseLng", "deviceId",
                           "roundId", "playerId", "companion", "ownerId"]
        for keyword in piiKeywords {
            XCTAssertFalse(
                jsonString.contains("\"\(keyword)\""),
                "JSON에 PII 키 '\(keyword)'가 포함되어선 안 돼요"
            )
        }
    }

    // MARK: - T2. 닉네임 마스킹 — 전화번호

    func test_displayName_phoneNumberMasked() {
        let result = StatsSharePayloadBuilder.maskedDisplayName("010-1234-5678")
        XCTAssertTrue(
            result.hasSuffix("***"),
            "전화번호 형태 닉네임은 마스킹되어야 해요. got: \(result)"
        )
        XCTAssertEqual(result.prefix(1), "0", "첫 글자는 보존되어야 해요")
    }

    // MARK: - T3. 닉네임 마스킹 — 이메일

    func test_displayName_email_masked() {
        let result = StatsSharePayloadBuilder.maskedDisplayName("user@example.com")
        XCTAssertTrue(
            result.hasSuffix("***"),
            "이메일 형태 닉네임은 마스킹되어야 해요. got: \(result)"
        )
        XCTAssertEqual(result.prefix(1), "u", "첫 글자는 보존되어야 해요")
    }

    // MARK: - T4. 닉네임 마스킹 — 빈 문자열

    func test_displayName_emptyDefault() {
        XCTAssertEqual(StatsSharePayloadBuilder.maskedDisplayName(""), "익명")
        XCTAssertEqual(StatsSharePayloadBuilder.maskedDisplayName("   "), "익명")
    }

    // MARK: - T5. RegionCentroidLUT 17개 전부 조회

    func test_regionCentroidLUT_allKeys() {
        let expectedKeys = ["경기", "강원", "충북", "충남", "전북", "전남",
                            "경북", "경남", "제주", "서울", "부산", "대구",
                            "인천", "광주", "대전", "울산", "세종"]

        XCTAssertEqual(RegionCentroidLUT.allKeys.count, 17, "17개 키가 있어야 해요")

        for key in expectedKeys {
            let centroid = RegionCentroidLUT.centroid(for: key)
            XCTAssertNotNil(centroid, "'\(key)' centroid가 nil이어선 안 돼요")
            if let c = centroid {
                XCTAssertTrue(c.lat > 33.0 && c.lat < 39.0, "'\(key)' lat 범위 이상: \(c.lat)")
                XCTAssertTrue(c.lng > 124.0 && c.lng < 130.0, "'\(key)' lng 범위 이상: \(c.lng)")
            }
        }

        // 미정의 키는 nil
        XCTAssertNil(RegionCentroidLUT.centroid(for: "외국"), "미정의 키는 nil이어야 해요")
        XCTAssertNil(RegionCentroidLUT.centroid(for: ""), "빈 키는 nil이어야 해요")
    }

    // MARK: - T6. PR 카드 headline + C안 필드 검증

    @MainActor
    func test_payloadBuilder_PRCard_headline() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let stats = try makeBasicStats(ctx: ctx)

        let payload = StatsSharePayloadBuilder.build(
            cardKind: .pr,
            stats: stats,
            regionStats: [],
            rawDisplayName: "테스트유저",
            bestRoundCourseName: "레이크사이드CC",
            bestRoundDate: Date(),
            bestRoundTotalScore: 82,
            bestRoundIsPR: true,
            nowISO: "2026-05-27T12:00:00Z"
        )

        XCTAssertTrue(
            payload.signature.headline.contains("인생 최저타"),
            "PR 카드 headline에 '인생 최저타'가 포함되어야 해요. got: \(payload.signature.headline)"
        )
        XCTAssertEqual(payload.signature.bigNumber, "82")
        XCTAssertEqual(payload.signature.bigUnit, "타")
        XCTAssertEqual(payload.cardKind, .pr)

        // C안 태그 + scoreBlockLabel
        XCTAssertEqual(payload.signature.tagText, "NEW PR",
                       "PR 카드 tagText는 'NEW PR'이어야 해요. got: \(payload.signature.tagText ?? "nil")")
        XCTAssertEqual(payload.signature.scoreBlockLabel, "Total Score",
                       "PR 카드 scoreBlockLabel은 'Total Score'이어야 해요. got: \(payload.signature.scoreBlockLabel ?? "nil")")

        // playerName — displayName 마스킹 후 일치
        XCTAssertEqual(payload.signature.playerName, payload.displayName,
                       "playerName은 displayName과 같아야 해요")

        // miniStats 개수 확인 (최소 2개)
        let miniCount = payload.signature.miniStats?.count ?? 0
        XCTAssertGreaterThanOrEqual(miniCount, 2,
                       "PR miniStats는 최소 2개 이상이어야 해요. got: \(miniCount)")
    }

    // MARK: - T6b. PR miniStats 라벨 검증 (C안 신규)

    @MainActor
    func test_signature_miniStatsContainExpectedLabels_PR() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let stats = try makeBasicStats(ctx: ctx)

        let payload = StatsSharePayloadBuilder.build(
            cardKind: .pr,
            stats: stats,
            regionStats: [],
            rawDisplayName: "테스트유저",
            bestRoundCourseName: "레이크사이드CC",
            bestRoundDate: Date(),
            bestRoundTotalScore: 82,
            bestRoundIsPR: true,
            nowISO: "2026-05-27T12:00:00Z"
        )

        let labels = payload.signature.miniStats?.map(\.label) ?? []
        XCTAssertTrue(
            labels.contains("Even 대비"),
            "PR miniStats에 'Even 대비' 라벨이 있어야 해요. got: \(labels)"
        )
        XCTAssertTrue(
            labels.contains("이전 PR"),
            "PR miniStats에 '이전 PR' 라벨이 있어야 해요. got: \(labels)"
        )
    }

    // MARK: - T7. HCP 카드 headline + bigUnit + C안 필드 검증

    @MainActor
    func test_payloadBuilder_HCPCard_headlineAndBigNumber() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let stats = try makeBasicStats(ctx: ctx)

        // handicapEstimate가 nil이 아닌 경우만 의미 있음 (8R 이상)
        let payload = StatsSharePayloadBuilder.build(
            cardKind: .hcp,
            stats: stats,
            regionStats: [],
            rawDisplayName: "골퍼",
            nowISO: "2026-05-27T12:00:00Z"
        )

        XCTAssertEqual(payload.cardKind, .hcp)
        XCTAssertEqual(payload.signature.bigUnit, "HDCP",
                       "HCP 카드 bigUnit은 'HDCP'여야 해요")
        XCTAssertTrue(
            payload.signature.headline.contains("핸디캡"),
            "HCP 카드 headline에 '핸디캡'이 포함되어야 해요. got: \(payload.signature.headline)"
        )
        XCTAssertTrue(
            payload.signature.footerLabel.contains("최근 8R"),
            "HCP footerLabel에 '최근 8R'이 포함되어야 해요. got: \(payload.signature.footerLabel)"
        )

        // C안 태그 + scoreBlockLabel
        XCTAssertEqual(payload.signature.tagText, "HDCP DOWN",
                       "HCP 카드 tagText는 'HDCP DOWN'이어야 해요. got: \(payload.signature.tagText ?? "nil")")
        XCTAssertEqual(payload.signature.scoreBlockLabel, "Handicap Index",
                       "HCP 카드 scoreBlockLabel은 'Handicap Index'이어야 해요. got: \(payload.signature.scoreBlockLabel ?? "nil")")

        // miniStats 개수 확인 (3개)
        let miniCount = payload.signature.miniStats?.count ?? 0
        XCTAssertGreaterThanOrEqual(miniCount, 2,
                       "HCP miniStats는 최소 2개 이상이어야 해요. got: \(miniCount)")
    }

    // MARK: - T8. TREND 카드 directionLabel 검증

    @MainActor
    func test_payloadBuilder_TRENDCard_improving() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        // 좋아지는 추세: 8R, 앞 4R 평균 94, 뒤 4R 평균 85 (delta < -2 → .improving)
        let base = Date(timeIntervalSinceReferenceDate: 9_000_000)
        let scores = [95, 94, 93, 92, 86, 85, 84, 83]
        var rounds: [Round] = []
        for (i, total) in scores.enumerated() {
            let player = Player(name: "나", isOwner: true)
            ctx.insert(player)
            let round = Round(courseId: "trend\(i)", courseName: "장\(i)")
            round.isFinished = true
            round.finishedAt = base.addingTimeInterval(Double(i) * 86400)
            ctx.insert(round)
            round.players = [player]
            let base9 = total / 9
            let rem = total % 9
            var holeList: [HoleScore] = []
            for h in 1...9 {
                let s = h <= rem ? base9 + 1 : base9
                let hole = HoleScore(holeNumber: h, par: 4)
                hole.counts.append(ScoreEntry(playerId: player.id, value: s))
                ctx.insert(hole)
                holeList.append(hole)
            }
            round.holes = holeList
            rounds.append(round)
        }
        try ctx.save()

        let stats = aggregateStatistics(rounds: rounds)
        let payload = StatsSharePayloadBuilder.build(
            cardKind: .trend,
            stats: stats,
            regionStats: [],
            rawDisplayName: "골퍼",
            nowISO: "2026-05-27T12:00:00Z"
        )

        XCTAssertEqual(payload.cardKind, .trend)
        XCTAssertNotNil(payload.trend, "trend 데이터가 있어야 해요")
        XCTAssertEqual(payload.trend?.direction, "improving",
                       "좋아지는 추세이면 direction='improving'")
        XCTAssertTrue(
            payload.trend?.directionLabel.contains("↘") ?? false,
            "improving directionLabel에 '↘'이 포함되어야 해요. got: \(payload.trend?.directionLabel ?? "")"
        )
        XCTAssertTrue(
            payload.signature.headline.contains("라운드"),
            "TREND 카드 headline에 '라운드'가 포함되어야 해요. got: \(payload.signature.headline)"
        )

        // C안 태그 + scoreBlockLabel
        XCTAssertEqual(payload.signature.tagText, "IMPROVING",
                       "TREND 카드 tagText는 'IMPROVING'이어야 해요. got: \(payload.signature.tagText ?? "nil")")
        XCTAssertEqual(payload.signature.scoreBlockLabel, "Recent 5R Avg",
                       "TREND 카드 scoreBlockLabel은 'Recent 5R Avg'이어야 해요. got: \(payload.signature.scoreBlockLabel ?? "nil")")

        // miniStats 개수 확인 (최소 2개)
        let miniCount = payload.signature.miniStats?.count ?? 0
        XCTAssertGreaterThanOrEqual(miniCount, 2,
                       "TREND miniStats는 최소 2개 이상이어야 해요. got: \(miniCount)")
    }

    // MARK: - T9. roundLocations 파라미터 → payload.roundLocations 매핑

    /// Builder가 roundLocations 파라미터를 받아 payload에 StatsRoundLocationShare 로 매핑하는지
    @MainActor
    func test_payload_includesRoundLocations() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let stats = try makeBasicStats(ctx: ctx)

        let locations: [RoundLocation] = [
            RoundLocation(courseId: "course1", courseName: "레이크사이드CC", lat: 37.4, lng: 127.1, roundCount: 3),
            RoundLocation(courseId: "course2", courseName: "남서울CC", lat: 37.3, lng: 126.9, roundCount: 1),
        ]

        let payload = StatsSharePayloadBuilder.build(
            cardKind: .pr,
            stats: stats,
            regionStats: [],
            rawDisplayName: "테스터",
            roundLocations: locations,
            nowISO: "2026-05-27T12:00:00Z"
        )

        XCTAssertNotNil(payload.roundLocations,
                        "roundLocations 파라미터가 전달되면 payload.roundLocations는 nil이 아니어야 해요")
        XCTAssertEqual(payload.roundLocations?.count, 2,
                       "2개 위치가 그대로 매핑되어야 해요. got: \(payload.roundLocations?.count ?? -1)")

        guard let first = payload.roundLocations?.first else {
            XCTFail("roundLocations의 첫 번째 요소가 없어요")
            return
        }
        XCTAssertEqual(first.courseName, "레이크사이드CC",
                       "첫 번째 courseName이 일치해야 해요. got: \(first.courseName)")
        XCTAssertEqual(first.lat, 37.4, accuracy: 0.0001,
                       "lat이 일치해야 해요. got: \(first.lat)")
        XCTAssertEqual(first.lng, 127.1, accuracy: 0.0001,
                       "lng이 일치해야 해요. got: \(first.lng)")
        XCTAssertEqual(first.roundCount, 3,
                       "roundCount가 일치해야 해요. got: \(first.roundCount)")
    }

    // MARK: - T10. 빈 roundLocations → payload.roundLocations는 nil

    /// 빈 배열 입력 시 payload.roundLocations는 nil (기존 region centroid 폴백 유지)
    @MainActor
    func test_payload_emptyRoundLocations_isNil() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let stats = try makeBasicStats(ctx: ctx)

        let payload = StatsSharePayloadBuilder.build(
            cardKind: .pr,
            stats: stats,
            regionStats: [],
            rawDisplayName: "테스터",
            roundLocations: [],  // 빈 배열
            nowISO: "2026-05-27T12:00:00Z"
        )

        XCTAssertNil(payload.roundLocations,
                     "빈 roundLocations 입력 시 payload.roundLocations는 nil이어야 해요 (region centroid 폴백)")
    }
}

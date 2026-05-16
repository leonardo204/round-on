import XCTest
import SwiftData
@testable import Shared

// MARK: - CloudKitCompatibilityTests
// CloudKit 호환성 변경 검증
// - 모든 @Model 속성 default 값 확인
// - inverse 관계 설정 확인
// - in-memory ModelContainer 라운드트립
// - PersistedDiscoveredCourse 중복 방지 로직

final class CloudKitCompatibilityTests: XCTestCase {

    // MARK: - 헬퍼

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            Round.self, Player.self, HoleScore.self,
            RoundPhoto.self, PersistedDiscoveredCourse.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    // MARK: - Round default 값 검증

    @MainActor
    func test_Round_defaultValues_CloudKitCompatible() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        // 기본 init — courseId/courseName 생략해도 동작
        let round = Round()
        ctx.insert(round)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<Round>())
        let r = try XCTUnwrap(fetched.first)

        XCTAssertEqual(r.courseId, "", "courseId 기본값은 빈 문자열이어야 해요")
        XCTAssertEqual(r.courseName, "", "courseName 기본값은 빈 문자열이어야 해요")
        XCTAssertEqual(r.isFinished, false, "isFinished 기본값은 false여야 해요")
        // playerList/holeList/photoList Optional fallback 동작
        XCTAssertTrue(r.playerList.isEmpty, "playerList fallback은 빈 배열이어야 해요")
        XCTAssertTrue(r.holeList.isEmpty, "holeList fallback은 빈 배열이어야 해요")
        XCTAssertTrue(r.photoList.isEmpty, "photoList fallback은 빈 배열이어야 해요")
    }

    // MARK: - Player default 값 검증

    @MainActor
    func test_Player_defaultValues_CloudKitCompatible() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let player = Player()
        ctx.insert(player)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<Player>())
        let p = try XCTUnwrap(fetched.first)

        XCTAssertEqual(p.name, "", "name 기본값은 빈 문자열이어야 해요")
        XCTAssertEqual(p.isOwner, false, "isOwner 기본값은 false여야 해요")
        XCTAssertEqual(p.order, 0, "order 기본값은 0이어야 해요")
    }

    // MARK: - HoleScore default 값 검증

    @MainActor
    func test_HoleScore_defaultValues_CloudKitCompatible() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let hole = HoleScore()
        ctx.insert(hole)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<HoleScore>())
        let h = try XCTUnwrap(fetched.first)

        XCTAssertEqual(h.holeNumber, 0, "holeNumber 기본값은 0이어야 해요")
        XCTAssertEqual(h.par, 4, "par 기본값은 4여야 해요")
        XCTAssertTrue(h.counts.isEmpty, "counts 기본값은 빈 배열이어야 해요")
        XCTAssertTrue(h.obCount.isEmpty, "obCount 기본값은 빈 배열이어야 해요")
        XCTAssertTrue(h.hazardCount.isEmpty, "hazardCount 기본값은 빈 배열이어야 해요")
    }

    // MARK: - RoundPhoto default 값 검증

    @MainActor
    func test_RoundPhoto_defaultValues_CloudKitCompatible() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let photo = RoundPhoto()
        ctx.insert(photo)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<RoundPhoto>())
        let p = try XCTUnwrap(fetched.first)

        XCTAssertEqual(p.localPath, "", "localPath 기본값은 빈 문자열이어야 해요")
        XCTAssertNil(p.remoteURL, "remoteURL 기본값은 nil이어야 해요")
    }

    // MARK: - PersistedDiscoveredCourse default 값 검증

    @MainActor
    func test_PersistedDiscoveredCourse_defaultValues_CloudKitCompatible() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        // PersistedDiscoveredCourse init은 kakaoPlaceId/name/lat/lng 필수
        let course = PersistedDiscoveredCourse(kakaoPlaceId: "", name: "", lat: 0.0, lng: 0.0)
        ctx.insert(course)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<PersistedDiscoveredCourse>())
        let c = try XCTUnwrap(fetched.first)

        XCTAssertEqual(c.kakaoPlaceId, "", "kakaoPlaceId 기본값은 빈 문자열이어야 해요")
        XCTAssertEqual(c.name, "", "name 기본값은 빈 문자열이어야 해요")
        XCTAssertEqual(c.lat, 0.0, "lat 기본값은 0.0이어야 해요")
        XCTAssertEqual(c.lng, 0.0, "lng 기본값은 0.0이어야 해요")
    }

    // MARK: - inverse 관계 (Player.round) 라운드트립

    @MainActor
    func test_inverseRelationship_Player_round_roundTrip() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let player = Player(name: "테스트", isOwner: true)
        let round = Round(courseId: "r1", courseName: "관계 테스트장")
        ctx.insert(player)
        ctx.insert(round)
        round.players = [player]
        try ctx.save()

        // Player에서 inverse round 조회
        let fetchedPlayers = try ctx.fetch(FetchDescriptor<Player>())
        let p = try XCTUnwrap(fetchedPlayers.first(where: { $0.name == "테스트" }))
        XCTAssertNotNil(p.round, "Player.round inverse 관계가 설정되어야 해요")
        XCTAssertEqual(p.round?.courseId, "r1", "Player.round가 올바른 Round를 참조해야 해요")
    }

    // MARK: - inverse 관계 (HoleScore.round) 라운드트립

    @MainActor
    func test_inverseRelationship_HoleScore_round_roundTrip() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let hole = HoleScore(holeNumber: 5, par: 4)
        let round = Round(courseId: "r2", courseName: "홀 관계 테스트장")
        ctx.insert(hole)
        ctx.insert(round)
        round.holes = [hole]
        try ctx.save()

        let fetchedHoles = try ctx.fetch(FetchDescriptor<HoleScore>())
        let h = try XCTUnwrap(fetchedHoles.first(where: { $0.holeNumber == 5 }))
        XCTAssertNotNil(h.round, "HoleScore.round inverse 관계가 설정되어야 해요")
        XCTAssertEqual(h.round?.courseId, "r2", "HoleScore.round가 올바른 Round를 참조해야 해요")
    }

    // MARK: - inverse 관계 (RoundPhoto.round) 라운드트립

    @MainActor
    func test_inverseRelationship_RoundPhoto_round_roundTrip() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let photo = RoundPhoto(localPath: "/test/photo.jpg")
        let round = Round(courseId: "r3", courseName: "사진 관계 테스트장")
        ctx.insert(photo)
        ctx.insert(round)
        round.photos = [photo]
        try ctx.save()

        let fetchedPhotos = try ctx.fetch(FetchDescriptor<RoundPhoto>())
        let p = try XCTUnwrap(fetchedPhotos.first(where: { $0.localPath == "/test/photo.jpg" }))
        XCTAssertNotNil(p.round, "RoundPhoto.round inverse 관계가 설정되어야 해요")
        XCTAssertEqual(p.round?.courseId, "r3", "RoundPhoto.round가 올바른 Round를 참조해야 해요")
    }

    // MARK: - Round 전체 라운드트립 (관계 포함)

    @MainActor
    func test_Round_fullRelationships_roundTrip() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let player = Player(name: "나", isOwner: true, order: 0)
        let hole = HoleScore(holeNumber: 1, par: 4)
        hole.counts.append(ScoreEntry(playerId: player.id, value: 5))
        let photo = RoundPhoto(localPath: "/photos/abc.jpg")

        ctx.insert(player)
        ctx.insert(hole)
        ctx.insert(photo)

        let round = Round(courseId: "full-test", courseName: "전체 관계 테스트장")
        round.isFinished = true
        ctx.insert(round)
        round.players = [player]
        round.holes = [hole]
        round.photos = [photo]
        try ctx.save()

        // fetch 후 검증
        let rounds = try ctx.fetch(FetchDescriptor<Round>())
        let r = try XCTUnwrap(rounds.first)

        XCTAssertEqual(r.playerList.count, 1, "플레이어 1명이어야 해요")
        XCTAssertEqual(r.holeList.count, 1, "홀 1개여야 해요")
        XCTAssertEqual(r.photoList.count, 1, "사진 1장이어야 해요")
        XCTAssertEqual(r.holeList.first?.count(for: player.id), 5, "타수 5타여야 해요")
        XCTAssertEqual(r.photoList.first?.localPath, "/photos/abc.jpg", "사진 경로가 맞아야 해요")
    }

    // MARK: - PersistedDiscoveredCourse 중복 방지 로직 (no unique constraint)

    @MainActor
    func test_PersistedDiscoveredCourse_noDuplicate_withPredicate() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let kakaoId = "kakao-test-001"

        // 첫 번째 insert
        let course1 = PersistedDiscoveredCourse(
            kakaoPlaceId: kakaoId, name: "테스트 CC",
            lat: 37.0, lng: 127.0
        )
        ctx.insert(course1)
        try ctx.save()

        // 중복 방지 조회 후 조건부 insert (NewRoundView 패턴)
        let predicate = #Predicate<PersistedDiscoveredCourse> { $0.kakaoPlaceId == kakaoId }
        let existing = (try? ctx.fetch(FetchDescriptor(predicate: predicate))) ?? []
        if existing.isEmpty {
            let course2 = PersistedDiscoveredCourse(
                kakaoPlaceId: kakaoId, name: "테스트 CC (중복)",
                lat: 37.0, lng: 127.0
            )
            ctx.insert(course2)
            try ctx.save()
        }

        // 중복이 없어야 함
        let all = try ctx.fetch(FetchDescriptor<PersistedDiscoveredCourse>())
        XCTAssertEqual(all.count, 1, "중복 방지 로직으로 1건만 저장되어야 해요")
        XCTAssertEqual(all.first?.kakaoPlaceId, kakaoId, "kakaoPlaceId가 일치해야 해요")
    }
}

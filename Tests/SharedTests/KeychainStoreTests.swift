import XCTest
@testable import Shared

// MARK: - KeychainStoreTests
// C5: set → get → delete 라운드트립 검증
// 테스트 환경에서는 InMemoryKeychainStore를 사용 (Keychain entitlement 불필요)
// 실기기/앱 환경에서는 KeychainStore(Keychain Services)가 동일 인터페이스를 제공

final class KeychainStoreTests: XCTestCase {

    // InMemoryKeychainStore로 KeychainStoring 프로토콜 테스트
    private var store: InMemoryKeychainStore!
    private var shortId: String!

    override func setUp() {
        super.setUp()
        store = InMemoryKeychainStore()
        shortId = UUID().uuidString
    }

    override func tearDown() {
        store = nil
        super.tearDown()
    }

    // MARK: set → get 라운드트립

    func test_set_then_get_returnsToken() throws {
        let token = "test-token-\(UUID().uuidString)"
        try store.setEditToken(token, for: shortId)
        let retrieved = store.editToken(for: shortId)
        XCTAssertEqual(retrieved, token, "저장한 토큰과 조회한 토큰이 일치해야 한다")
    }

    // MARK: 없는 키 조회 시 nil 반환

    func test_get_nonexistent_returnsNil() {
        let result = store.editToken(for: "nonexistent-id-\(UUID().uuidString)")
        XCTAssertNil(result, "존재하지 않는 shortId 조회 시 nil이어야 한다")
    }

    // MARK: 같은 shortId 재set 시 덮어쓰기

    func test_set_twice_overwritesToken() throws {
        let token1 = "first-token"
        let token2 = "second-token"

        try store.setEditToken(token1, for: shortId)
        try store.setEditToken(token2, for: shortId)

        let retrieved = store.editToken(for: shortId)
        XCTAssertEqual(retrieved, token2, "재설정 시 최신 토큰으로 덮어써야 한다")
    }

    // MARK: delete 후 nil 반환

    func test_delete_thenGetReturnsNil() throws {
        try store.setEditToken("token-to-delete", for: shortId)
        try store.deleteEditToken(for: shortId)
        let result = store.editToken(for: shortId)
        XCTAssertNil(result, "삭제 후 조회 시 nil이어야 한다")
    }

    // MARK: 존재하지 않는 키 삭제는 에러 없이 통과

    func test_deleteNonexistent_noThrow() {
        XCTAssertNoThrow(
            try store.deleteEditToken(for: "nonexistent-\(UUID().uuidString)"),
            "존재하지 않는 항목 삭제는 에러 없이 통과해야 한다"
        )
    }

    // MARK: migrateIfNeeded — 평문 → 인메모리 이관

    @MainActor
    func test_migrateIfNeeded_movesPlainTextToStorage() throws {
        let round = Round(courseId: "test", courseName: "테스트 골프장")
        round.sharedShortId = shortId
        round.sharedEditToken = "plain-token-123"

        XCTAssertNil(store.editToken(for: shortId), "마이그레이션 전 스토리지가 비어 있어야 한다")

        store.migrateIfNeeded(round: round)

        XCTAssertEqual(store.editToken(for: shortId), "plain-token-123", "마이그레이션 후 스토리지에 토큰이 있어야 한다")
        XCTAssertNil(round.sharedEditToken, "마이그레이션 후 평문 필드는 nil이어야 한다")
    }

    // MARK: migrateIfNeeded — 이미 있으면 skip

    @MainActor
    func test_migrateIfNeeded_skipsIfAlreadyExists() throws {
        let existingToken = "existing-token"
        try store.setEditToken(existingToken, for: shortId)

        let round = Round(courseId: "test", courseName: "테스트 골프장")
        round.sharedShortId = shortId
        round.sharedEditToken = "plain-should-not-overwrite"

        store.migrateIfNeeded(round: round)

        XCTAssertEqual(store.editToken(for: shortId), existingToken, "이미 있으면 덮어쓰지 않아야 한다")
    }

    // MARK: migrateIfNeeded — shortId nil이면 아무것도 안 함

    @MainActor
    func test_migrateIfNeeded_noOpWhenShortIdNil() {
        let round = Round(courseId: "test", courseName: "테스트 골프장")
        round.sharedShortId = nil
        round.sharedEditToken = "some-token"

        // 크래시 없이 통과해야 함
        XCTAssertNoThrow(store.migrateIfNeeded(round: round))
    }

    // MARK: 다수 shortId 독립 저장

    func test_multipleShortIds_independent() throws {
        let id1 = UUID().uuidString
        let id2 = UUID().uuidString
        let id3 = UUID().uuidString

        try store.setEditToken("token-1", for: id1)
        try store.setEditToken("token-2", for: id2)
        try store.setEditToken("token-3", for: id3)

        XCTAssertEqual(store.editToken(for: id1), "token-1")
        XCTAssertEqual(store.editToken(for: id2), "token-2")
        XCTAssertEqual(store.editToken(for: id3), "token-3")

        try store.deleteEditToken(for: id2)

        XCTAssertEqual(store.editToken(for: id1), "token-1", "id1은 영향받지 않아야 한다")
        XCTAssertNil(store.editToken(for: id2), "id2는 삭제되어야 한다")
        XCTAssertEqual(store.editToken(for: id3), "token-3", "id3은 영향받지 않아야 한다")
    }
}

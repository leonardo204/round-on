import XCTest
import SwiftData
@testable import Shared

// MARK: - ShareViewModelTests
// B4: ShareViewModel 상태 관리 검증
// - 초기화 시 round.sharedOptions 반영
// - isUpdateMode 분기
// - canShare 검증 (PIN 유효성)
// - checkExpiration 동작
// - 사진 업로드 진행 상태 프로퍼티

final class ShareViewModelTests: XCTestCase {

    // MARK: 헬퍼

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Round.self, Player.self, HoleScore.self, RoundPhoto.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    // MARK: 초기화 — round.sharedOptions 반영

    @MainActor
    func test_init_withSharedOptions_reflectsOptions() throws {
        let round = Round(courseId: "test", courseName: "테스트 코스")
        round.sharedOptions = ShareOptions(nameVisibility: .anonymous, accessControl: .pin("1234"))

        let vm = ShareViewModel(round: round)

        XCTAssertEqual(vm.nameVisibility, .anonymous, "round.sharedOptions의 nameVisibility가 반영되어야 한다")
        if case .pin(let p) = vm.accessControl {
            XCTAssertEqual(p, "1234", "round.sharedOptions의 PIN이 반영되어야 한다")
        } else {
            XCTFail("accessControl이 pin이어야 한다")
        }
    }

    // MARK: isUpdateMode — sharedShortId 존재 시 true

    @MainActor
    func test_isUpdateMode_trueWhenShortIdExists() {
        let round = Round(courseId: "test", courseName: "테스트 코스")
        round.sharedShortId = "abc123"

        let vm = ShareViewModel(round: round)
        XCTAssertTrue(vm.isUpdateMode, "sharedShortId가 있으면 isUpdateMode가 true여야 한다")
    }

    @MainActor
    func test_isUpdateMode_falseWhenNoShortId() {
        let round = Round(courseId: "test", courseName: "테스트 코스")
        let vm = ShareViewModel(round: round)
        XCTAssertFalse(vm.isUpdateMode, "sharedShortId가 없으면 isUpdateMode가 false여야 한다")
    }

    // MARK: canShare — 로딩 중엔 false

    @MainActor
    func test_canShare_falseWhenLoading() {
        let vm = ShareViewModel()
        vm.isLoading = true
        XCTAssertFalse(vm.canShare, "isLoading 중엔 canShare가 false여야 한다")
    }

    // MARK: canShare — 사진 업로드 중엔 false

    @MainActor
    func test_canShare_falseWhenUploadingPhotos() {
        let vm = ShareViewModel()
        vm.isUploadingPhotos = true
        XCTAssertFalse(vm.canShare, "isUploadingPhotos 중엔 canShare가 false여야 한다")
    }

    // MARK: canShare — PIN 4자리 아니면 false

    @MainActor
    func test_canShare_falseWhenPinInvalid() {
        let vm = ShareViewModel()
        vm.accessControl = .pin("123")  // 3자리 (유효하지 않음)
        vm.pinInput = "123"
        XCTAssertFalse(vm.canShare, "4자리 미만 PIN이면 canShare가 false여야 한다")
    }

    @MainActor
    func test_canShare_trueWhenPinValid() {
        let vm = ShareViewModel()
        vm.accessControl = .pin("1234")
        vm.pinInput = "1234"
        XCTAssertTrue(vm.canShare, "4자리 숫자 PIN이면 canShare가 true여야 한다")
    }

    // MARK: checkExpiration — 만료된 Round 필드 nil 처리

    @MainActor
    func test_checkExpiration_clearsFieldsOnExpired() {
        let round = Round(courseId: "test", courseName: "테스트 코스")
        round.sharedShortId = "expired-id"
        round.sharedURL = "https://golf.zerolive.co.kr/r/expired-id"
        round.sharedExpiresAt = Date.distantPast  // 이미 만료

        let vm = ShareViewModel(round: round)
        vm.checkExpiration()

        XCTAssertNil(round.sharedShortId, "만료 시 sharedShortId가 nil이어야 한다")
        XCTAssertNil(round.sharedURL, "만료 시 sharedURL이 nil이어야 한다")
        XCTAssertNil(round.sharedExpiresAt, "만료 시 sharedExpiresAt이 nil이어야 한다")
    }

    @MainActor
    func test_checkExpiration_doesNotClearWhenNotExpired() {
        let round = Round(courseId: "test", courseName: "테스트 코스")
        round.sharedShortId = "valid-id"
        round.sharedURL = "https://golf.zerolive.co.kr/r/valid-id"
        round.sharedExpiresAt = Date.distantFuture  // 아직 유효

        let vm = ShareViewModel(round: round)
        vm.checkExpiration()

        XCTAssertNotNil(round.sharedShortId, "만료되지 않았으면 sharedShortId가 유지되어야 한다")
    }

    // MARK: 사진 업로드 진행 상태 리셋

    @MainActor
    func test_resetPhotoUploadProgress_clearsState() {
        let vm = ShareViewModel()
        vm.photoUploadCurrent = 3
        vm.photoUploadTotal = 5
        vm.isUploadingPhotos = true

        vm.resetPhotoUploadProgress()

        XCTAssertEqual(vm.photoUploadCurrent, 0)
        XCTAssertEqual(vm.photoUploadTotal, 0)
        XCTAssertFalse(vm.isUploadingPhotos)
    }

    // MARK: currentOptions — PIN 적용 검증

    @MainActor
    func test_currentOptions_withPin_returnsCorrectOptions() {
        let vm = ShareViewModel()
        vm.nameVisibility = .anonymous
        vm.accessControl = .pin("5678")
        vm.pinInput = "5678"

        let options = vm.currentOptions()

        XCTAssertEqual(options.nameVisibility, .anonymous)
        if case .pin(let p) = options.accessControl {
            XCTAssertEqual(p, "5678")
        } else {
            XCTFail("accessControl이 pin이어야 한다")
        }
    }
}

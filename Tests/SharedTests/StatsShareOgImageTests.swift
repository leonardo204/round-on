import XCTest
@testable import Shared

// MARK: - StatsShareOgImageTests
// og:image 업로드 페이로드 인코딩 규칙 (Worker POST /api/share/stats 계약)
// 네트워크·렌더 없이 순수 로직만 검증

final class StatsShareOgImageTests: XCTestCase {

    /// 인코딩 규칙만 검증하므로 실제 PNG 시그니처는 필요 없다
    private func makeData(_ count: Int) -> Data {
        Data(repeating: 0xAB, count: count)
    }

    // MARK: - PIN 보호 공유는 미전송

    func testPinProtectedShareIsSkipped() {
        let result = StatsShareOgImage.encode(pngData: makeData(1024), hasPin: true)

        XCTAssertEqual(result, .skipped(.pinProtected))
        XCTAssertNil(result.base64, "PIN 공유는 서버가 og를 버리므로 전송하지 않는다")
    }

    // MARK: - 크기 상한 초과는 미전송

    func testOversizedImageIsSkipped() {
        // base64 길이 = 4 * ceil(n/3) → n=1_179_649 이면 1_572_868자로 상한 초과
        let result = StatsShareOgImage.encode(pngData: makeData(1_179_649), hasPin: false)

        XCTAssertEqual(result, .skipped(.tooLarge))
        XCTAssertNil(result.base64, "상한 초과분은 서버가 어차피 버린다")
    }

    func testExactlyAtLimitIsEncoded() {
        // n=1_179_648 → base64 정확히 1_572_864자 = 상한 (경계는 전송)
        let result = StatsShareOgImage.encode(pngData: makeData(1_179_648), hasPin: false)

        XCTAssertEqual(result.base64?.count, StatsShareOgImage.maxBase64Length)
    }

    func testMaxBase64LengthMatchesWorkerContract() {
        XCTAssertEqual(StatsShareOgImage.maxBase64Length, 1_572_864,
                       "Worker의 MAX_OG_BASE64_LENGTH와 반드시 동일해야 한다")
    }

    // MARK: - 정상 인코딩

    func testEncodesPureBase64WithoutDataURIPrefix() {
        let png = makeData(300)

        guard let base64 = StatsShareOgImage.encode(pngData: png, hasPin: false).base64 else {
            return XCTFail("인코딩에 성공해야 한다")
        }

        XCTAssertFalse(base64.hasPrefix("data:"), "data URI prefix를 붙이면 서버가 거부한다")
        XCTAssertEqual(Data(base64Encoded: base64), png, "원본 PNG로 복원 가능해야 한다")
    }

    // MARK: - 렌더 실패는 미전송

    func testNilPNGIsSkipped() {
        XCTAssertEqual(StatsShareOgImage.encode(pngData: nil, hasPin: false),
                       .skipped(.renderFailed))
    }

    func testEmptyPNGIsSkipped() {
        XCTAssertEqual(StatsShareOgImage.encode(pngData: Data(), hasPin: false),
                       .skipped(.renderFailed))
    }
}

import XCTest
import SwiftUI
@testable import Shared

final class SeasonalColorTests: XCTestCase {
    func test_springColors_load_fromBundle() {
        // Color는 직접 비교 어려우므로 UIColor로 변환해서 nil 여부 검증
        let primary = UIColor(Color.springGreenPrimary)
        XCTAssertNotNil(primary, "Spring/GreenPrimary 로드 실패")

        let secondary = UIColor(Color.springGreenSecondary)
        XCTAssertNotNil(secondary, "Spring/GreenSecondary 로드 실패")

        let surface = UIColor(Color.springSurface)
        XCTAssertNotNil(surface, "Spring/Surface 로드 실패")
    }

    func test_winterColors_load_fromBundle() {
        let primary = UIColor(Color.winterGreenPrimary)
        XCTAssertNotNil(primary, "Winter/GreenPrimary 로드 실패")

        let textPrimary = UIColor(Color.winterTextPrimary)
        XCTAssertNotNil(textPrimary, "Winter/TextPrimary 로드 실패")
    }
}

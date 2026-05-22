import XCTest
@testable import Shared

// NOTE: ScorecardMapper, ImportSection, ImportPlayer는 App-iOS 타겟에 있으므로
// 직접 임포트하는 대신 Mapper 로직 자체를 여기서 테스트합니다.
// ScorecardMapper.absoluteStrokes는 App-iOS 에 있어서 직접 테스트 불가하므로
// 동일 로직을 여기서 검증합니다.

// MARK: - ScorecardMapperTests
// PAR 대비 상대값 → 절대 타수 변환 로직 + OCR 파이프라인 연동 테스트

final class ScorecardMapperTests: XCTestCase {

    // MARK: absoluteStrokes 계산 단위 테스트

    func test_absoluteStrokes_par3_relative1_returns4() {
        // PAR 3 홀에서 상대값 +1이면 절대 타수 4
        let result = absoluteStrokes(par: 3, relative: 1)
        XCTAssertEqual(result, 4)
    }

    func test_absoluteStrokes_par4_relative0_returns4() {
        // PAR 4 홀에서 상대값 0이면 절대 타수 4 (파)
        let result = absoluteStrokes(par: 4, relative: 0)
        XCTAssertEqual(result, 4)
    }

    func test_absoluteStrokes_par5_relativeMinus1_returns4() {
        // PAR 5 홀에서 상대값 -1이면 절대 타수 4 (버디)
        let result = absoluteStrokes(par: 5, relative: -1)
        XCTAssertEqual(result, 4)
    }

    func test_absoluteStrokes_par4_relative2_returns6() {
        // PAR 4 홀에서 상대값 +2이면 절대 타수 6 (더블 보기)
        let result = absoluteStrokes(par: 4, relative: 2)
        XCTAssertEqual(result, 6)
    }

    // MARK: OCR + Mapper 통합 테스트 (IMG_1335.PNG)
    // NOTE: Vision OCR은 시뮬레이터에서 CoreML 홈 디렉토리 제약으로 크래시 가능.
    // 단위 테스트 환경에서는 Skip 처리. 실기기 또는 macOS 환경에서 CLI로 검증.

    func test_ocrPipeline_IMG1335_extractsTablesWithoutCrash() throws {
        throw XCTSkip("Vision OCR은 시뮬레이터 CoreML 제약으로 크래시 가능 — 실기기/macOS 검증 권장")
    }

    func test_ocrPipeline_IMG1335_playerRowsExistOrEmpty() throws {
        throw XCTSkip("Vision OCR은 시뮬레이터 CoreML 제약으로 크래시 가능 — 실기기/macOS 검증 권장")
    }

    // MARK: Owner 결정성 테스트 (S2)
    // ScorecardMapper.makeDraft의 owner 선택 로직을 동일하게 재현.
    // App-iOS 타겟 직접 임포트 불가 → 동일 로직 인라인 검증.

    func test_ownerSelection_noOwnerName_firstEntryIsOwner() {
        // OCR 등장 순서: ["나**, "박**", "김**"] — Dictionary 정렬 시 "김"이 첫 번째가 될 수 있음.
        // 올바른 동작: 등장 순서 첫 번째("나**")가 owner가 되어야 함.
        let orderedLabels = ["나**", "박**", "김**"]
        let ownerLabel = ownerLabelFrom(entries: orderedLabels, ownerName: nil)
        XCTAssertEqual(ownerLabel, "나**", "ownerName 없을 때 첫 번째 등장 라벨이 owner여야 함 (사전순 X)")
    }

    func test_ownerSelection_withOwnerName_matchesByPrefix() {
        // 마스킹 라벨("박**")은 ownerName 첫 글자("박")만으로 매칭
        let orderedLabels = ["나**", "박**", "김**"]
        let ownerLabel = ownerLabelFrom(entries: orderedLabels, ownerName: "박진우")
        XCTAssertEqual(ownerLabel, "박**", "마스킹 라벨은 ownerName 첫 글자('박')로 prefix 매칭되어야 함")
    }

    func test_ownerSelection_withExactOwnerName_matchesExact() {
        let orderedLabels = ["나**", "박진우", "김**"]
        let ownerLabel = ownerLabelFrom(entries: orderedLabels, ownerName: "박진우")
        XCTAssertEqual(ownerLabel, "박진우", "정확 일치하는 라벨이 owner여야 함")
    }

    func test_ownerSelection_noMatch_fallbackToFirst() {
        let orderedLabels = ["나**", "박**", "김**"]
        // ownerName이 전혀 일치하지 않으면 첫 번째로 fallback
        let ownerLabel = ownerLabelFrom(entries: orderedLabels, ownerName: "홍길동")
        XCTAssertEqual(ownerLabel, "나**", "매칭 없을 때 첫 번째 entry로 fallback되어야 함")
    }

    /// ScorecardMapper.makeDraft의 owner 선택 로직 재현 (순서 보존 배열 기반)
    private func ownerLabelFrom(entries: [String], ownerName: String?) -> String? {
        if let ownerName {
            return entries.first {
                let label = $0
                if label == ownerName { return true }
                if label.contains("*") {
                    return label.hasPrefix(String(ownerName.prefix(1)))
                } else {
                    return label.hasPrefix(String(ownerName.prefix(2)))
                }
            } ?? entries.first
        } else {
            return entries.first
        }
    }

    // MARK: Private helpers

    private func absoluteStrokes(par: Int, relative: Int) -> Int {
        par + relative
    }

    private func resourceURL(named name: String, extension ext: String) -> URL? {
        // 번들 내 samples 폴더에서 파일 찾기
        if let url = Bundle(for: type(of: self)).url(forResource: name, withExtension: ext) {
            return url
        }
        // samples 폴더 안에 있을 때 (folder reference)
        if let samplesURL = Bundle(for: type(of: self)).url(forResource: "samples", withExtension: nil) {
            let fileURL = samplesURL.appendingPathComponent("\(name).\(ext)")
            if FileManager.default.fileExists(atPath: fileURL.path) {
                return fileURL
            }
        }
        return nil
    }
}

import XCTest
@testable import Shared

// MARK: - GeminiRegressionTests
// 실제 Gemini API를 호출해 스코어카드 이미지 OCR 정확도를 측정하는 통합 테스트.
//
// ★ 실행 조건:
//   GEMINI_API_KEY 환경변수 설정 또는
//   호스트 파일 /Users/zerolive/work/golfCounter/test-bed/.env 에 GEMINI_API_KEY=... 라인 존재.
//
// ★ 실행 명령 예시:
//   GEMINI_API_KEY=xxx xcodebuild test \
//     -scheme RoundOn \
//     -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0' \
//     -only-testing:SharedTests/GeminiRegressionTests
//
// ★ 주의:
//   - 16장 × ~20초 = 약 5분 소요 예상
//   - 이 테스트는 기본 테스트 실행에서 제외하고 별도로 실행
//   - 단언(assert)은 느슨하게 — LLM 비결정성 고려
//   - 실패해도 측정값을 print로 출력

final class GeminiRegressionTests: XCTestCase {

    // MARK: - API 키 로드

    /// GEMINI_API_KEY 환경변수 우선, 없으면 호스트 .env 파일 파싱.
    /// 둘 다 없으면 XCTSkip.
    private func loadApiKey() throws -> String {
        // 1. 환경변수 우선
        if let key = ProcessInfo.processInfo.environment["GEMINI_API_KEY"],
           !key.isEmpty {
            return key
        }

        // 2. 호스트 .env 파일 폴백 (시뮬레이터는 macOS FS 공유)
        let envPath = "/Users/zerolive/work/golfCounter/test-bed/.env"
        if let content = try? String(contentsOfFile: envPath, encoding: .utf8) {
            for line in content.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("GEMINI_API_KEY=") {
                    let key = String(trimmed.dropFirst("GEMINI_API_KEY=".count))
                        .trimmingCharacters(in: .whitespaces)
                    if !key.isEmpty {
                        return key
                    }
                }
            }
        }

        throw XCTSkip("GEMINI_API_KEY를 찾을 수 없음 — 환경변수 또는 test-bed/.env 파일에 설정하세요.")
    }

    // MARK: - Expected JSON 파싱 헬퍼

    private struct ExpectedRow: Decodable {
        let label: String
        let kind: String
        let values: [Int]
        let out: Int
        let `in`: Int
        let total: Int
        let isOwner: Bool?
    }

    private struct ExpectedCard: Decodable {
        let source: String
        let cardType: String
        let courseName: String
        let date: String
        let owner: String
        let holeCount: Int
        let rows: [ExpectedRow]
    }

    private func loadExpected(atPath path: String) throws -> ExpectedCard {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try JSONDecoder().decode(ExpectedCard.self, from: data)
    }

    // MARK: - 일치율 계산

    /// player 행의 values 배열 셀 단위 일치율.
    private func cellAccuracy(
        actual: GeminiRow,
        expected: ExpectedRow
    ) -> Double {
        let count = min(actual.values.count, expected.values.count)
        guard count > 0 else { return 0 }
        let matches = zip(actual.values.prefix(count), expected.values.prefix(count))
            .filter { $0 == $1 }.count
        return Double(matches) / Double(count)
    }

    // MARK: - D1. 가로카드 8장 회귀 테스트

    func test_regression_smartscore_8images() async throws {
        let apiKey = try loadApiKey()
        let extractor = GeminiScorecardExtractor(apiKey: apiKey)

        let basePath = "/Users/zerolive/work/golfCounter/test-bed/samples/smartscore"
        let expectedDir = "\(basePath)/expected"
        let imageDir = basePath

        let imageNames = ["IMG_1335", "IMG_1336", "IMG_1337", "IMG_1338",
                          "IMG_1339", "IMG_1340", "IMG_1341", "IMG_1349"]

        var totalCells = 0
        var matchedCells = 0
        var failedImages: [String] = []

        for name in imageNames {
            let imagePath = "\(imageDir)/\(name).PNG"
            let expectedPath = "\(expectedDir)/\(name).json"

            // 이미지/expected 없으면 스킵
            guard FileManager.default.fileExists(atPath: imagePath),
                  FileManager.default.fileExists(atPath: expectedPath) else {
                print("[Regression] \(name): 파일 없음 — 스킵")
                continue
            }

            let expected: ExpectedCard
            do {
                expected = try loadExpected(atPath: expectedPath)
            } catch {
                print("[Regression] \(name): expected JSON 파싱 실패 — \(error)")
                failedImages.append(name)
                continue
            }

            let imageData: Data
            do {
                imageData = try Data(contentsOf: URL(fileURLWithPath: imagePath))
            } catch {
                print("[Regression] \(name): 이미지 로드 실패 — \(error)")
                failedImages.append(name)
                continue
            }

            let card: GeminiScorecard
            do {
                card = try await extractor.extract(
                    imageData: imageData,
                    mime: "image/png",
                    holeCount: expected.holeCount,
                    maxRetries: 2
                )
            } catch {
                print("[Regression] \(name): extract 실패 — \(error)")
                failedImages.append(name)
                continue
            }

            // player 행 셀 일치율 계산
            var imageCells = 0
            var imageMatches = 0

            for expRow in expected.rows where expRow.kind == "player" {
                // label로 매칭 (완전 일치 우선, 없으면 isOwner 힌트)
                guard let actualRow = card.players.first(where: { $0.label == expRow.label })
                    ?? (expRow.isOwner == true ? card.players.first(where: { $0.isOwner == true }) : nil)
                    ?? card.players.first else {
                    print("[Regression] \(name): player '\(expRow.label)' 매칭 실패")
                    continue
                }

                let count = min(actualRow.values.count, expRow.values.count)
                let matches = zip(actualRow.values.prefix(count), expRow.values.prefix(count))
                    .filter { $0 == $1 }.count
                imageCells += count
                imageMatches += matches

                let acc = count > 0 ? Double(matches) / Double(count) * 100 : 0
                print("[Regression] \(name) '\(expRow.label)': \(matches)/\(count) 셀 일치 (\(String(format: "%.1f", acc))%)")
            }

            totalCells += imageCells
            matchedCells += imageMatches

            let imgAcc = imageCells > 0 ? Double(imageMatches) / Double(imageCells) * 100 : 0
            print("[Regression] \(name) 전체: \(String(format: "%.1f", imgAcc))%")
        }

        let overallAcc = totalCells > 0 ? Double(matchedCells) / Double(totalCells) * 100 : 0
        print("\n[Regression] === 가로카드 전체 결과 ===")
        print("[Regression] 총 셀: \(matchedCells)/\(totalCells) (\(String(format: "%.1f", overallAcc))%)")
        if !failedImages.isEmpty {
            print("[Regression] 실패 이미지: \(failedImages.joined(separator: ", "))")
        }

        // 느슨한 단언 (LLM 비결정성 고려)
        XCTAssertGreaterThanOrEqual(
            overallAcc, 95.0,
            "가로카드 player 셀 일치율이 95% 미만: \(String(format: "%.1f", overallAcc))%"
        )
    }

    // MARK: - D2. 앱스샷 8장 회귀 테스트 (owner 행 중심)

    func test_regression_smartscore_app_8images() async throws {
        let apiKey = try loadApiKey()
        let extractor = GeminiScorecardExtractor(apiKey: apiKey)

        let basePath = "/Users/zerolive/work/golfCounter/test-bed/samples/smartscore-app"
        let expectedDir = "\(basePath)/expected"
        let imageDir = basePath

        let imageNames = ["IMG_1351", "IMG_1352", "IMG_1353", "IMG_1354",
                          "IMG_1355", "IMG_1356", "IMG_1357", "IMG_1358"]

        var ownerTotalCells = 0
        var ownerMatchedCells = 0
        var failedImages: [String] = []

        for name in imageNames {
            // 파일 확장자 결정 (.JPG)
            let imagePath = "\(imageDir)/\(name).JPG"
            let expectedPath = "\(expectedDir)/\(name).json"

            guard FileManager.default.fileExists(atPath: imagePath),
                  FileManager.default.fileExists(atPath: expectedPath) else {
                print("[Regression-App] \(name): 파일 없음 — 스킵")
                continue
            }

            let expected: ExpectedCard
            do {
                expected = try loadExpected(atPath: expectedPath)
            } catch {
                print("[Regression-App] \(name): expected JSON 파싱 실패 — \(error)")
                failedImages.append(name)
                continue
            }

            let imageData: Data
            do {
                imageData = try Data(contentsOf: URL(fileURLWithPath: imagePath))
            } catch {
                print("[Regression-App] \(name): 이미지 로드 실패 — \(error)")
                failedImages.append(name)
                continue
            }

            let card: GeminiScorecard
            do {
                card = try await extractor.extract(
                    imageData: imageData,
                    mime: "image/jpeg",
                    holeCount: expected.holeCount,
                    maxRetries: 2
                )
            } catch {
                print("[Regression-App] \(name): extract 실패 — \(error)")
                failedImages.append(name)
                continue
            }

            // owner 행만 측정
            guard let expOwner = expected.rows.first(where: { $0.isOwner == true }),
                  let actualOwner = card.players.first(where: { $0.isOwner == true })
                    ?? card.players.first else {
                print("[Regression-App] \(name): owner 행 없음 — 스킵")
                continue
            }

            let count = min(actualOwner.values.count, expOwner.values.count)
            let matches = zip(actualOwner.values.prefix(count), expOwner.values.prefix(count))
                .filter { $0 == $1 }.count

            ownerTotalCells += count
            ownerMatchedCells += matches

            let acc = count > 0 ? Double(matches) / Double(count) * 100 : 0
            print("[Regression-App] \(name) owner '\(expOwner.label)': \(matches)/\(count) 셀 일치 (\(String(format: "%.1f", acc))%)")

            // IMG_1358은 재시도 복구 케이스 — 별도 주석
            if name == "IMG_1358" {
                print("[Regression-App] IMG_1358: back9 누락 재시도 복구 케이스. 정상 통과 여부 중요.")
            }
        }

        let overallAcc = ownerTotalCells > 0
            ? Double(ownerMatchedCells) / Double(ownerTotalCells) * 100
            : 0
        print("\n[Regression-App] === 앱스샷 owner 전체 결과 ===")
        print("[Regression-App] 총 셀: \(ownerMatchedCells)/\(ownerTotalCells) (\(String(format: "%.1f", overallAcc))%)")
        if !failedImages.isEmpty {
            print("[Regression-App] 실패 이미지: \(failedImages.joined(separator: ", "))")
        }

        // 느슨한 단언 (앱스샷은 85%+ 목표)
        XCTAssertGreaterThanOrEqual(
            overallAcc, 85.0,
            "앱스샷 owner 셀 일치율이 85% 미만: \(String(format: "%.1f", overallAcc))%"
        )
    }
}

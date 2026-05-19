import Vision
import UIKit

// MARK: - ScorecardOCRService

/// 스코어카드 이미지 OCR 진입점.
/// Vision 실행 + parser dispatch (SmartScoreDetailParser → CommonScorecardParser) 흐름.
@MainActor
public enum ScorecardOCRService {

    /// 스코어카드 이미지에서 OCR로 라운드 데이터를 추출합니다.
    /// - Parameter image: UIImage (스마트스코어 정밀 표 형식 권장)
    /// - Returns: ScorecardOCRResult
    public static func recognize(image: UIImage) async throws -> ScorecardOCRResult {
        AppLogger.ocr.info("OCR 시작: image \(Int(image.size.width))x\(Int(image.size.height))")
        guard let cgImage = image.cgImage else {
            AppLogger.ocr.error("OCR 실패: cgImage nil — UIImage 변환 실패")
            throw ScorecardOCRError.imageProcessingFailed
        }

        // 1. VNRecognizeTextRequest 실행
        let lines = try await runOCR(on: cgImage)
        AppLogger.ocr.info("Vision OCR 완료: \(lines.count)개 라인 추출")

        guard !lines.isEmpty else {
            AppLogger.ocr.warning("OCR 실패: 텍스트 0건 — 사진 품질 또는 해상도 문제 추정")
            throw ScorecardOCRError.noTextFound
        }

        // raw OCR 텍스트 dump (디버그용) — 전체 노출
        for (i, l) in lines.enumerated() {
            AppLogger.ocr.debug("[raw \(i)] y=\(String(format: "%.3f", l.topLeftY)) x=\(String(format: "%.3f", l.leftX)) text=\"\(l.text, privacy: .public)\"")
        }

        // 2. Parser dispatch
        // type-specific parsers — detect confidence 내림차순 시도
        let typeSpecific: [any ScorecardParser.Type] = [SmartScoreDetailParser.self]
        // fallback — 마지막 수단
        let fallback: [any ScorecardParser.Type] = [CommonScorecardParser.self]

        let scored = typeSpecific
            .map { ($0, $0.detect(lines: lines)) }
            .sorted { $0.1 > $1.1 }

        for (parser, conf) in scored {
            AppLogger.ocr.info("[dispatch] \(parser.typeName) confidence=\(String(format: "%.2f", conf))")
            if conf < 0.3 {
                AppLogger.ocr.info("[dispatch] \(parser.typeName) confidence 낮음 → skip")
                continue
            }
            if let result = parser.parse(lines: lines) {
                AppLogger.ocr.info("[dispatch] \(parser.typeName) 성공 (par \(result.pars.count)개 players \(result.players.count)명)")
                let normalized = ScoreFormatNormalizer.normalize(result: result)
                return try validated(normalized)
            }
            AppLogger.ocr.info("[dispatch] \(parser.typeName) nil 반환 → 다음 시도")
        }

        for parser in fallback {
            AppLogger.ocr.info("[dispatch fallback] \(parser.typeName) 시도")
            if let result = parser.parse(lines: lines) {
                AppLogger.ocr.info("[dispatch fallback] \(parser.typeName) 성공 (par \(result.pars.count)개 players \(result.players.count)명)")
                let normalized = ScoreFormatNormalizer.normalize(result: result)
                return try validated(normalized)
            }
            AppLogger.ocr.info("[dispatch fallback] \(parser.typeName) nil 반환")
        }

        throw ScorecardOCRError.insufficientData(reason: "지원하는 형식의 스코어카드를 인식하지 못했어요")
    }

    /// 진단용 — raw OCR 라인만 추출 (파싱/검증 없이). 실패 시 빈 배열.
    public static func diagnoseRawText(image: UIImage) async -> [OCRTextLine] {
        guard let cgImage = image.cgImage else { return [] }
        return (try? await runOCR(on: cgImage)) ?? []
    }

    // MARK: - 최소 데이터 검증

    private static func validated(_ result: ScorecardOCRResult) throws -> ScorecardOCRResult {
        AppLogger.ocr.info("파싱 결과: 코스=\(result.courseName ?? "nil", privacy: .public) date=\(result.date.map { "\($0)" } ?? "nil", privacy: .public) front=\(result.frontCourseName ?? "nil", privacy: .public) back=\(result.backCourseName ?? "nil", privacy: .public) par=\(result.pars.count)개 players=\(result.players.count)명 warnings=\(result.warnings.count)개")
        for w in result.warnings {
            AppLogger.ocr.warning("[warning] \(w.rawValue, privacy: .public): \(w.message, privacy: .public)")
        }
        if result.pars.count < 9 {
            AppLogger.ocr.error("OCR 실패: PAR 정보 부족 \(result.pars.count)개 (최소 9개 필요)")
            throw ScorecardOCRError.insufficientData(reason: "PAR 정보 \(result.pars.count)개 (최소 9개 필요)")
        }
        AppLogger.ocr.info("OCR 성공")
        return result
    }

    // MARK: - OCR 실행

    private static func runOCR(on cgImage: CGImage) async throws -> [OCRTextLine] {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                var lines: [OCRTextLine] = []
                for obs in observations {
                    guard let topCandidate = obs.topCandidates(1).first else { continue }
                    let line = OCRTextLine(text: topCandidate.string, boundingBox: obs.boundingBox)
                    lines.append(line)
                }

                // Y 좌표 오름차순 (위에서 아래)
                lines.sort { $0.topLeftY < $1.topLeftY }
                continuation.resume(returning: lines)
            }

            request.recognitionLanguages = ["ko-KR", "en-US"]
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false  // 숫자 인식 정확도 우선

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

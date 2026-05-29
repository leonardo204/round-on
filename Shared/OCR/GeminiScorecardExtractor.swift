import Foundation
import CoreGraphics
import ImageIO
import UIKit
import os.log

// MARK: - GeminiScorecardExtractor
// Gemini Vision API를 호출해 스코어카드 이미지를 구조화 JSON으로 추출한다.
//
// - API 키: Info.plist "GEMINI_API_KEY" (xcconfig 주입)
// - 모델: gemini-2.5-flash
// - 이미지: 긴 변 >1600px 시 리사이즈 후 base64 전송
// - 재시도: 1차 temp=0, 재시도 시 temp=0.2
// - 검증: ScorecardValidator.check 통과해야 반환
// - 타임아웃: 단일 호출 60초
// - 네트워크 패턴: CourseRepository와 동일한 URLSession async/await

private let geminiLogger = Logger(subsystem: "kr.zerolive.golf.roundon", category: "GeminiOCR")

public final class GeminiScorecardExtractor: Sendable {

    // MARK: - 상수

    private let model = "gemini-2.5-flash"
    private let endpoint = "https://generativelanguage.googleapis.com/v1beta/models"
    private let maxLongEdge: CGFloat = 1600
    // ★ URLRequest.timeoutInterval = 무활동(inactivity) 타임아웃.
    //   JPEG로 업로드가 빨라지면 이후 Gemini 추론(~50-90s) 동안 연결이 idle 상태가 되는데,
    //   이 idle 구간이 타임아웃을 넘기면 안 된다. 추론 시간 + 여유를 위해 120s.
    //   (이전 60s는 추론 대기 중 터져 3회 모두 timeout → Vision 폴백되던 원인)
    private let timeoutSeconds: TimeInterval = 120

    private let apiKey: String
    private let session: URLSession

    // MARK: - Init

    /// apiKey를 직접 전달하는 초기화 (테스트용)
    public init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    /// Info.plist에서 GEMINI_API_KEY를 읽어 초기화 (앱 사용)
    public static func fromInfoPlist(session: URLSession = .shared) throws -> GeminiScorecardExtractor {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "GEMINI_API_KEY") as? String,
              !key.isEmpty else {
            throw OCRError.apiKeyMissing
        }
        guard key != "$(GEMINI_API_KEY)" else {
            throw OCRError.apiKeyNotConfigured
        }
        return GeminiScorecardExtractor(apiKey: key, session: session)
    }

    // MARK: - 공개 API

    /// 이미지 데이터 → 검증 통과한 GeminiScorecard.
    /// 검증 실패 시 maxRetries회 재시도 (온도 0.2로 상승).
    /// - Parameters:
    ///   - imageData: 원본 이미지 Data (JPEG/PNG)
    ///   - mime: "image/jpeg" 또는 "image/png"
    ///   - holeCount: 예상 홀 수 (18 또는 9). Validator가 추론으로 보정.
    ///   - maxRetries: 최대 재시도 횟수 (기본 2)
    public func extract(
        imageData: Data,
        mime: String,
        holeCount: Int = 18,
        maxRetries: Int = 2
    ) async throws -> GeminiScorecard {
        // 이미지 다운스케일 (크기 로깅 포함)
        // 다운스케일 시: JPEG로 재인코딩 → mime도 image/jpeg로 교체
        // 다운스케일 없음: 원본 데이터 + 원본 mime 그대로 유지
        let scaledData = downscale(imageData: imageData, mime: mime)
        let (sendData, sendMime): (Data, String) = scaledData.map { ($0, "image/jpeg") } ?? (imageData, mime)
        let b64 = sendData.base64EncodedString()

        var lastError: Error = OCRError.exhausted
        for attempt in 0...maxRetries {
            // Task 취소 체크
            if Task.isCancelled { throw OCRError.cancelled }

            let temperature = attempt == 0 ? 0.0 : 0.2
            geminiLogger.info("[GeminiOCR] 시도 #\(attempt + 1) 시작 — temperature: \(temperature), mime: \(sendMime), payload: \(b64.count / 1024)KB (b64)")
            do {
                let card = try await callOnce(b64: b64, mime: sendMime, temperature: temperature, attempt: attempt + 1)
                // 검증
                try ScorecardValidator.check(card, holeCount: holeCount)
                // 실제 응답 키 확인용 디버그 로그 (1회)
                if attempt == 0 {
                    logResponseKeys(card)
                }
                geminiLogger.info("[GeminiOCR] 추출 성공 — attempt \(attempt + 1)")
                return card
            } catch let error as OCRError {
                lastError = error
                geminiLogger.warning("[GeminiOCR] 시도 #\(attempt + 1) 실패: \(error.localizedDescription)")
                // API 키 오류는 재시도 무의미
                switch error {
                case .apiKeyMissing, .apiKeyNotConfigured, .httpError, .cancelled:
                    throw error
                default:
                    break
                }
            } catch {
                lastError = error
                geminiLogger.warning("[GeminiOCR] 시도 #\(attempt + 1) 예외: \(error.localizedDescription)")
            }
        }
        geminiLogger.error("[GeminiOCR] 모든 시도 소진 — lastError: \(lastError.localizedDescription)")
        throw lastError
    }

    // MARK: - Private

    private func callOnce(b64: String, mime: String, temperature: Double, attempt: Int) async throws -> GeminiScorecard {
        // API 키는 헤더로 전달 (URL 쿼리에 포함 시 NSURLCache/프록시 평문 노출 위험)
        let urlString = "\(endpoint)/\(model):generateContent"
        guard let url = URL(string: urlString) else {
            throw OCRError.invalidResponse
        }

        let body = makeRequestBody(b64: b64, mime: mime, temperature: temperature)
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url, timeoutInterval: timeoutSeconds)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = bodyData

        // 네트워크 요청 타이밍 측정
        let requestStart = Date()
        geminiLogger.info("[GeminiOCR] 네트워크 요청 전송 (attempt \(attempt))")
        let (data, response) = try await session.data(for: request)
        let elapsedMs = Int(Date().timeIntervalSince(requestStart) * 1000)
        geminiLogger.info("[GeminiOCR] 요청 완료: \(elapsedMs)ms (attempt \(attempt))")

        guard let http = response as? HTTPURLResponse else {
            throw OCRError.invalidResponse
        }

        // 4xx / 5xx 오류 처리 — 응답 본문은 내부 로그용으로만 200자 truncate 후 보관
        guard (200...299).contains(http.statusCode) else {
            let rawBody = String(data: data, encoding: .utf8) ?? ""
            let truncated = rawBody.count > 200
                ? String(rawBody.prefix(200)) + "…(truncated)"
                : rawBody
            geminiLogger.error("[GeminiOCR] HTTP \(http.statusCode) 오류 (attempt \(attempt)): \(truncated)")
            #if DEBUG
            print("[GeminiOCR] HTTP \(http.statusCode) 응답 본문: \(truncated)")
            #endif
            throw OCRError.httpError(http.statusCode, truncated)
        }

        // candidates[0].content.parts[0].text → JSON 파싱
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let first = candidates.first,
              let content = first["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String,
              let textData = text.data(using: .utf8) else {
            throw OCRError.invalidResponse
        }

        let decoder = JSONDecoder()
        let card = try decoder.decode(GeminiScorecard.self, from: textData)
        return card
    }

    // MARK: - 요청 Body 구성

    private func makeRequestBody(b64: String, mime: String, temperature: Double) -> [String: Any] {
        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "courseName": ["type": "string"],
                "date": ["type": "string"],
                "rows": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "properties": [
                            "label":   ["type": "string"],
                            "kind":    ["type": "string", "enum": ["par", "player"]],
                            "isOwner": ["type": "boolean"],
                            "values":  ["type": "array", "items": ["type": "integer"]],
                            "out":     ["type": "integer"],
                            "inScore": ["type": "integer"],
                            "total":   ["type": "integer"]
                        ],
                        "required": ["label", "kind", "values", "out", "inScore", "total"]
                    ]
                ]
            ],
            "required": ["courseName", "date", "rows"]
        ]

        let prompt = """
이 이미지는 한국 골프 스코어카드(스마트스코어)입니다. 가로 표 형식이거나, 배경 사진 위에 본인 점수 2줄만 있는 앱 공유 카드일 수 있습니다.

규칙:
1. 표의 각 점수 셀에는 PAR 대비 차이값(over-par delta)이 인쇄되어 있습니다. 파4홀에서 5타=+1, 4타=0, 3타=-1(버디). 셀 안의 정수만 읽으세요.
2. 숫자 위/아래의 점(dot)·막대(bar) 같은 작은 마크는 over/under 시각표시이니 무시하세요. 단 음수(버디·이글)는 반드시 음수로 표기.
3. PAR 행이 보이면 kind="par", values=각 홀 실제 par 값(3/4/5).
4. 플레이어 행은 kind="player". values=홀별 over-par 정수(전반9 + 후반9 = 18개, 9홀 카드면 9개). out=전반 실제 타수, inScore=후반 실제 타수, total=18홀 실제 합계.
5. 본인(최상단·가장 진한 글씨·이름 전체표기, 보통 PAR 바로 아래)은 isOwner=true.
6. courseName=골프장 한글명(괄호 안 구 명칭 제외), date=YYYY-MM-DD.
정확도가 가장 중요합니다. 합계가 맞는지 스스로 검산하세요.
"""

        return [
            "contents": [
                [
                    "parts": [
                        ["text": prompt],
                        ["inline_data": ["mime_type": mime, "data": b64]]
                    ]
                ]
            ],
            "generationConfig": [
                "responseMimeType": "application/json",
                "responseSchema": schema,
                "temperature": temperature
            ]
        ]
    }

    // MARK: - 이미지 다운스케일

    /// 긴 변이 maxLongEdge를 초과하면 리사이즈 후 JPEG(0.8) 데이터 반환.
    /// 실패하거나 리사이즈 불필요 시 nil 반환 (원본 사용).
    /// ★ 다운스케일 시 포맷에 무관하게 항상 JPEG 0.8로 인코딩 — PNG 재인코딩으로 인한 폭증 방지.
    private func downscale(imageData: Data, mime: String) -> Data? {
        guard let image = UIImage(data: imageData) else { return nil }
        let size = image.size
        let longEdge = max(size.width, size.height)
        guard longEdge > maxLongEdge else {
            geminiLogger.info("[GeminiOCR] 다운스케일 스킵 — 긴 변 \(Int(longEdge))px ≤ \(Int(self.maxLongEdge))px (원본 전송)")
            return nil  // 리사이즈 불필요 → 원본 데이터 그대로 사용
        }

        let scale = maxLongEdge / longEdge
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }

        // 다운스케일 시: 포맷에 무관하게 JPEG 0.8 인코딩 (PNG 재인코딩 금지 — payload 폭증 방지)
        guard let jpegData = resized.jpegData(compressionQuality: 0.8) else {
            geminiLogger.warning("[GeminiOCR] JPEG 인코딩 실패 — 다운스케일 스킵, 원본 전송")
            return nil
        }
        geminiLogger.info("[GeminiOCR] 다운스케일 적용 — \(Int(size.width))x\(Int(size.height)) → \(Int(newSize.width))x\(Int(newSize.height)), 인코딩: jpeg, payload: \(jpegData.count / 1024)KB (\(jpegData.base64EncodedString().count / 1024)KB b64)")
        return jpegData
    }

    // MARK: - 디버그 로그

    /// 실제 Gemini 응답 키 확인용 (1회 호출 후 로그 출력)
    private func logResponseKeys(_ card: GeminiScorecard) {
        #if DEBUG
        let playerCount = card.players.count
        let hasParRow = card.parRow != nil
        let firstPlayerValues = card.players.first.map { "\($0.values.count)개" } ?? "없음"
        print("[GeminiOCR] 응답 확인 — courseName: \(card.courseName), date: \(card.date), "
            + "players: \(playerCount)명, parRow: \(hasParRow), "
            + "첫 player values: \(firstPlayerValues), "
            + "inScore 키 정상 수신: \(card.players.first.map { "\($0.inScore)" } ?? "없음")")
        #endif
        geminiLogger.info("[GeminiOCR] 응답 키 확인 — courseName: \(card.courseName), date: \(card.date), players: \(card.players.count)명, parRow: \(card.parRow != nil)")
    }
}

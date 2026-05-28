import Foundation
import Shared

// MARK: - ShareAPIClient
// Cloudflare Worker 7개 엔드포인트 (30-API §3~§6)
// URLSession + async/await
// Base URL: https://golf.zerolive.co.kr (30-API §2.1)

// MARK: - 에러

public enum ShareAPIError: LocalizedError, Sendable {
    case unauthorized                   // 401
    case notFound                       // 404
    case gone                           // 410 (만료)
    case tooLarge                       // 413
    case rateLimited                    // 429
    case serverError(Int, String?)      // 5xx
    case networkError(Error)
    case encodingError(Error)
    case decodingError(Error)
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .unauthorized:             return "인증 토큰이 유효하지 않아요."
        case .notFound:                 return "공유 링크를 찾을 수 없어요."
        case .gone:                     return "공유 링크가 만료되었어요."
        case .tooLarge:                 return "요청 페이로드가 너무 커요."
        case .rateLimited:              return "요청이 너무 많아요. 잠시 후 다시 시도해 주세요."
        case .serverError(let code, let msg): return "서버 오류 (\(code))\(msg.map { ": \($0)" } ?? "")"
        case .networkError(let error):  return "네트워크 오류: \(error.localizedDescription)"
        case .encodingError(let error): return "요청 본문 인코딩 오류: \(error.localizedDescription)"
        case .decodingError(let error): return "응답 파싱 오류: \(error.localizedDescription)"
        case .invalidResponse:          return "올바르지 않은 서버 응답이에요."
        }
    }
}

// MARK: - ShareAPIClient

public final class ShareAPIClient: @unchecked Sendable {

    // MARK: Base URL

    public static let baseURL = "https://golf.zerolive.co.kr"

    // MARK: Session

    private let session: URLSession

    // MARK: Init

    public init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: JSON Decoder/Encoder

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        // Worker는 fractional seconds 포함 ISO8601 (예: "2026-05-25T02:05:33.176Z")
        // 기본 .iso8601은 fractional 미지원이라 실패 → 두 포맷 모두 fallback
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            if let date = fractional.date(from: str) ?? standard.date(from: str) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container,
                debugDescription: "Invalid ISO8601 date: \(str)")
        }
        return d
    }()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    // MARK: - POST /api/share (viewer 생성)

    /// viewer 생성 (30-API §3)
    public func createShare(request: CreateShareRequest) async throws -> CreateShareResponse {
        AppLogger.share.info("[Share] createShare 시작 — round=\(request.round.id, privacy: .private), players=\(request.round.players.count), holes=\(request.round.holes.count)")
        let url = try makeURL(path: "/api/share")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        req.setValue(UUID().uuidString, forHTTPHeaderField: "Idempotency-Key")
        do {
            req.httpBody = try encoder.encode(request)
            AppLogger.share.debug("[Share] createShare encoded body bytes=\(req.httpBody?.count ?? 0)")
        } catch {
            AppLogger.share.error("[Share] createShare encode 실패: \(error.localizedDescription)")
            throw ShareAPIError.encodingError(error)
        }

        let data = try await perform(req)
        let resp = try decodeResponse(CreateShareResponse.self, from: data)
        AppLogger.share.info("[Share] createShare 성공 — shortId=\(resp.shortId), url=\(resp.url)")
        return resp
    }

    // MARK: - PUT /api/share/{shortId} (viewer 업데이트)

    /// viewer 업데이트 (30-API §4)
    public func updateShare(shortId: String, editToken: String, request: UpdateShareRequest) async throws -> UpdateShareResponse {
        AppLogger.share.info("[Share] updateShare 시작 — shortId=\(shortId)")
        let url = try makeURL(path: "/api/share/\(shortId)")
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(editToken)", forHTTPHeaderField: "Authorization")
        req.setValue(UUID().uuidString, forHTTPHeaderField: "Idempotency-Key")
        do {
            req.httpBody = try encoder.encode(request)
        } catch {
            AppLogger.share.error("[Share] updateShare encode 실패: \(error.localizedDescription)")
            throw ShareAPIError.encodingError(error)
        }

        let data = try await perform(req)
        let resp = try decodeResponse(UpdateShareResponse.self, from: data)
        AppLogger.share.info("[Share] updateShare 성공 — shortId=\(resp.shortId)")
        return resp
    }

    // MARK: - DELETE /api/share/{shortId} (viewer 회수)

    /// viewer 회수 (30-API §9.6)
    public func deleteShare(shortId: String, editToken: String) async throws {
        AppLogger.share.info("[Share] deleteShare 시작 — shortId=\(shortId)")
        let url = try makeURL(path: "/api/share/\(shortId)")
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.setValue("Bearer \(editToken)", forHTTPHeaderField: "Authorization")

        _ = try await perform(req, expectNoContent: true)
        AppLogger.share.info("[Share] deleteShare 성공 — shortId=\(shortId)")
    }

    // 사진 업로드/삭제 API는 2026-05-18 폐기 (개인정보보호, 비용 절감).
    // 공유 viewer는 스코어카드 + 만료 시각만 표시.

    // MARK: - Private Helpers

    private func makeURL(path: String) throws -> URL {
        guard let url = URL(string: Self.baseURL + path) else {
            throw ShareAPIError.invalidResponse
        }
        return url
    }

    private func perform(_ request: URLRequest, expectNoContent: Bool = false) async throws -> Data {
        let method = request.httpMethod ?? "?"
        let urlStr = request.url?.absoluteString ?? "?"
        AppLogger.share.debug("[Share] perform \(method) \(urlStr)")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            AppLogger.share.error("[Share] \(method) \(urlStr) — 네트워크 실패: \(error.localizedDescription)")
            throw ShareAPIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            AppLogger.share.error("[Share] \(method) \(urlStr) — HTTPURLResponse 캐스트 실패")
            throw ShareAPIError.invalidResponse
        }
        AppLogger.share.debug("[Share] \(method) \(urlStr) → HTTP \(httpResponse.statusCode), body bytes=\(data.count)")

        switch httpResponse.statusCode {
        case 200, 201:
            return data
        case 204:
            return Data()
        case 401:
            AppLogger.share.error("[Share] 401 Unauthorized — editToken 검증 실패")
            throw ShareAPIError.unauthorized
        case 404:
            AppLogger.share.error("[Share] 404 NotFound")
            throw ShareAPIError.notFound
        case 410:
            AppLogger.share.error("[Share] 410 Gone — 만료된 viewer")
            throw ShareAPIError.gone
        case 413:
            AppLogger.share.error("[Share] 413 Payload Too Large")
            throw ShareAPIError.tooLarge
        case 429:
            AppLogger.share.error("[Share] 429 Rate Limited")
            throw ShareAPIError.rateLimited
        default:
            let msg = try? decoder.decode(APIErrorResponse.self, from: data)
            let bodyPreview = String(data: data.prefix(256), encoding: .utf8) ?? "<non-utf8>"
            AppLogger.share.error("[Share] HTTP \(httpResponse.statusCode) 서버 에러 — body=\(bodyPreview, privacy: .public)")
            throw ShareAPIError.serverError(httpResponse.statusCode, msg?.error)
        }
    }

    private func decodeResponse<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            let bodyPreview = String(data: data.prefix(512), encoding: .utf8) ?? "<non-utf8>"
            AppLogger.share.error("[Share] \(String(describing: type)) decode 실패: \(error.localizedDescription) — body=\(bodyPreview, privacy: .public)")
            throw ShareAPIError.decodingError(error)
        }
    }
}

// multipart 헬퍼는 photo upload용이라 폐기 (2026-05-18)

// MARK: - Stats 공유 응답

public struct StatsShareCreateResponse: Sendable {
    public let shortId: String        // "s_xxxxxxxx"
    public let url: String            // "https://golf.zerolive.co.kr/s/..."
    public let editToken: String
    public let expiresAt: Date
}

/// Stats 공유 응답 Codable (내부 디코딩용)
private struct StatsShareCreateResponseCodable: Decodable {
    let shortId: String
    let url: String
    let editToken: String
    let expiresAt: Date
}

// MARK: - ShareAPIClient Stats 확장

extension ShareAPIClient {

    /// POST /api/share/stats — 통계 공유 viewer 생성 (30-API §stats)
    public func createStatsShare(
        payload: StatsSharePayload,
        pin: String?,
        deviceToken: String
    ) async throws -> StatsShareCreateResponse {
        AppLogger.share.info("[Share] createStatsShare 시작 — cardKind=\(payload.cardKind.rawValue)")

        let url = try makeURL(path: "/api/share/stats")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        req.setValue(UUID().uuidString, forHTTPHeaderField: "Idempotency-Key")
        req.setValue("Bearer \(deviceToken)", forHTTPHeaderField: "X-Device-Token")

        // 요청 바디: {payload, pin?, deviceToken}
        let body = StatsShareRequestBody(payload: payload, pin: pin, deviceToken: deviceToken)
        do {
            req.httpBody = try statsEncoder.encode(body)
            AppLogger.share.debug("[Share] createStatsShare encoded bytes=\(req.httpBody?.count ?? 0)")
        } catch {
            AppLogger.share.error("[Share] createStatsShare encode 실패: \(error.localizedDescription)")
            throw ShareAPIError.encodingError(error)
        }

        let data = try await perform(req)
        let resp = try decodeStatsResponse(StatsShareCreateResponseCodable.self, from: data)
        AppLogger.share.info("[Share] createStatsShare 성공 — shortId=\(resp.shortId)")
        return StatsShareCreateResponse(
            shortId: resp.shortId,
            url: resp.url,
            editToken: resp.editToken,
            expiresAt: resp.expiresAt
        )
    }

    /// DELETE /api/share/stats/:shortId — 통계 viewer 회수 (editToken Bearer)
    public func deleteStatsShare(
        shortId: String,
        editToken: String
    ) async throws {
        AppLogger.share.info("[Share] deleteStatsShare 시작 — shortId=\(shortId)")
        let url = try makeURL(path: "/api/share/stats/\(shortId)")
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.setValue("Bearer \(editToken)", forHTTPHeaderField: "Authorization")

        _ = try await perform(req, expectNoContent: true)
        AppLogger.share.info("[Share] deleteStatsShare 성공 — shortId=\(shortId)")
    }

    // MARK: - 내부 헬퍼 (Stats 전용)

    private var statsEncoder: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }

    private func decodeStatsResponse<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let d = JSONDecoder()
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            if let date = fractional.date(from: str) ?? standard.date(from: str) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container,
                debugDescription: "Invalid ISO8601 date: \(str)")
        }
        do {
            return try d.decode(type, from: data)
        } catch {
            let bodyPreview = String(data: data.prefix(512), encoding: .utf8) ?? "<non-utf8>"
            AppLogger.share.error("[Share] \(String(describing: type)) decode 실패: \(error.localizedDescription) — body=\(bodyPreview, privacy: .public)")
            throw ShareAPIError.decodingError(error)
        }
    }
}

// MARK: - Stats 요청 바디

private struct StatsShareRequestBody: Encodable {
    let payload: StatsSharePayload
    let pin: String?
    let deviceToken: String
}

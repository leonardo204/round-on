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
    case tooLarge                       // 413 (사진 10MB 초과)
    case rateLimited                    // 429
    case serverError(Int, String?)      // 5xx
    case networkError(Error)
    case decodingError(Error)
    case photoLimitExceeded             // 30장 제한
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .unauthorized:             return "인증 토큰이 유효하지 않아요."
        case .notFound:                 return "공유 링크를 찾을 수 없어요."
        case .gone:                     return "공유 링크가 만료되었어요."
        case .tooLarge:                 return "사진 용량이 너무 커요. (최대 10MB)"
        case .rateLimited:              return "요청이 너무 많아요. 잠시 후 다시 시도해 주세요."
        case .serverError(let code, let msg): return "서버 오류 (\(code))\(msg.map { ": \($0)" } ?? "")"
        case .networkError(let error):  return "네트워크 오류: \(error.localizedDescription)"
        case .decodingError(let error): return "응답 파싱 오류: \(error.localizedDescription)"
        case .photoLimitExceeded:       return "사진은 최대 30장까지 첨부할 수 있어요."
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
        let url = try makeURL(path: "/api/share")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        req.setValue(UUID().uuidString, forHTTPHeaderField: "Idempotency-Key")
        req.httpBody = try encoder.encode(request)

        let data = try await perform(req)
        return try decodeResponse(CreateShareResponse.self, from: data)
    }

    // MARK: - PUT /api/share/{shortId} (viewer 업데이트)

    /// viewer 업데이트 (30-API §4)
    public func updateShare(shortId: String, editToken: String, request: UpdateShareRequest) async throws -> UpdateShareResponse {
        let url = try makeURL(path: "/api/share/\(shortId)")
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(editToken)", forHTTPHeaderField: "Authorization")
        req.setValue(UUID().uuidString, forHTTPHeaderField: "Idempotency-Key")
        req.httpBody = try encoder.encode(request)

        let data = try await perform(req)
        return try decodeResponse(UpdateShareResponse.self, from: data)
    }

    // MARK: - DELETE /api/share/{shortId} (viewer 회수)

    /// viewer 회수 (30-API §9.6)
    public func deleteShare(shortId: String, editToken: String) async throws {
        let url = try makeURL(path: "/api/share/\(shortId)")
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.setValue("Bearer \(editToken)", forHTTPHeaderField: "Authorization")

        _ = try await perform(req, expectNoContent: true)
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
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ShareAPIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ShareAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200, 201:
            return data
        case 204:
            return Data()
        case 401:
            throw ShareAPIError.unauthorized
        case 404:
            throw ShareAPIError.notFound
        case 410:
            throw ShareAPIError.gone
        case 413:
            throw ShareAPIError.tooLarge
        case 429:
            throw ShareAPIError.rateLimited
        default:
            let msg = try? decoder.decode(APIErrorResponse.self, from: data)
            throw ShareAPIError.serverError(httpResponse.statusCode, msg?.error)
        }
    }

    private func decodeResponse<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw ShareAPIError.decodingError(error)
        }
    }
}

// multipart 헬퍼는 photo upload용이라 폐기 (2026-05-18)

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
        d.dateDecodingStrategy = .iso8601
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

    // MARK: - POST /api/share/{shortId}/photos (사진 업로드)

    /// 사진 업로드 multipart/form-data (30-API §5.1)
    public func uploadPhoto(
        shortId: String,
        editToken: String,
        imageData: Data,
        holeNumber: Int?,
        caption: String?
    ) async throws -> UploadPhotoResponse {
        let url = try makeURL(path: "/api/share/\(shortId)/photos")
        let boundary = "Boundary-\(UUID().uuidString)"

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(editToken)", forHTTPHeaderField: "Authorization")

        var body = Data()
        // photo 파트
        body.appendFormField(name: "photo", filename: "photo.jpg", mimeType: "image/jpeg", data: imageData, boundary: boundary)
        // holeNumber
        if let hole = holeNumber, let holeData = "\(hole)".data(using: .utf8) {
            body.appendTextField(name: "holeNumber", value: String(hole), data: holeData, boundary: boundary)
        }
        // caption
        if let cap = caption, let capData = cap.data(using: .utf8) {
            body.appendTextField(name: "caption", value: cap, data: capData, boundary: boundary)
        }
        // 종료
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        let data = try await perform(req)
        return try decodeResponse(UploadPhotoResponse.self, from: data)
    }

    // MARK: - DELETE /api/share/{shortId}/photos/{photoId} (사진 삭제)

    /// 사진 삭제 (30-API §5.2)
    public func deletePhoto(shortId: String, photoId: String, editToken: String) async throws {
        let url = try makeURL(path: "/api/share/\(shortId)/photos/\(photoId)")
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.setValue("Bearer \(editToken)", forHTTPHeaderField: "Authorization")

        _ = try await perform(req, expectNoContent: true)
    }

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

// MARK: - Data multipart 헬퍼

private extension Data {
    mutating func appendFormField(
        name: String,
        filename: String,
        mimeType: String,
        data fileData: Data,
        boundary: String
    ) {
        var header = "--\(boundary)\r\n"
        header += "Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n"
        header += "Content-Type: \(mimeType)\r\n\r\n"
        if let headerData = header.data(using: .utf8) {
            append(headerData)
        }
        append(fileData)
        if let crlf = "\r\n".data(using: .utf8) {
            append(crlf)
        }
    }

    mutating func appendTextField(
        name: String,
        value: String,
        data valueData: Data,
        boundary: String
    ) {
        var header = "--\(boundary)\r\n"
        header += "Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n"
        if let headerData = header.data(using: .utf8) {
            append(headerData)
        }
        append(valueData)
        if let crlf = "\r\n".data(using: .utf8) {
            append(crlf)
        }
    }
}

import Foundation
import Shared

// MARK: - CourseAddressResolver

/// 로컬 DB GolfCourse의 address가 nil일 때 카카오 keyword 검색으로 lazy fetch + 메모리 캐시.
///
/// 사용법:
///   let addr = await CourseAddressResolver.shared.address(for: course)
///
/// 캐시 정책:
///   - 메모리 캐시 (앱 세션 내 영구). 앱 재시작 시 재검색.
///   - 카카오 API key 없음 → nil 반환 (조용히 무시).
///   - API 실패 → nil 반환 (재시도 없음, 다음 표시 시 재시도).
@MainActor
public final class CourseAddressResolver {

    // MARK: - Shared

    public static let shared = CourseAddressResolver()

    // MARK: - 캐시

    /// courseId → 해결된 주소 (nil이면 API 요청했지만 결과 없음을 나타내는 sentinel 제외)
    private var cache: [String: String] = [:]
    /// 현재 진행 중인 요청 (중복 방지)
    private var inFlight: Set<String> = []

    // MARK: - 상수

    private static let kakaoSearchURL = "https://dapi.kakao.com/v2/local/search/keyword.json"

    // MARK: - Init

    private init() {}

    // MARK: - Public API

    /// GolfCourse의 주소를 반환한다.
    ///
    /// - DB address가 있으면 즉시 반환.
    /// - DB address가 nil이면 카카오 검색 → 캐싱 → 반환.
    public func address(for course: GolfCourse) async -> String? {
        // 1) DB에 이미 있으면 즉시 반환
        if let addr = course.address, !addr.isEmpty {
            return addr
        }

        let id = course.id

        // 2) 메모리 캐시 확인
        if let cached = cache[id] {
            return cached
        }

        // 3) 중복 요청 방지 — 이미 in-flight이면 대기 없이 nil 반환
        //    (뷰가 업데이트되면 자연스럽게 재시도됨)
        guard !inFlight.contains(id) else { return nil }
        inFlight.insert(id)
        defer { inFlight.remove(id) }

        // 4) 카카오 keyword 검색
        guard let apiKey = CourseDiscoveryService.apiKey(), !apiKey.isEmpty else {
            return nil
        }

        var components = URLComponents(string: Self.kakaoSearchURL)!
        components.queryItems = [
            URLQueryItem(name: "query", value: course.name),
            URLQueryItem(name: "size", value: "1")
        ]

        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.setValue("KakaoAK \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 8.0

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }

            let decoded = try JSONDecoder().decode(KakaoAddressSearchResponse.self, from: data)
            guard let first = decoded.documents.first else { return nil }

            // road_address_name 우선, 없으면 address_name
            let addr: String?
            if let road = first.roadAddressName, !road.isEmpty {
                addr = road
            } else if let plain = first.addressName, !plain.isEmpty {
                addr = plain
            } else {
                addr = nil
            }

            if let resolved = addr {
                cache[id] = resolved
                return resolved
            }
            return nil

        } catch {
            return nil
        }
    }
}

// MARK: - 카카오 주소 검색 응답 모델 (CourseAddressResolver 전용)

private struct KakaoAddressSearchResponse: Decodable {
    let documents: [KakaoAddressPlace]
}

private struct KakaoAddressPlace: Decodable {
    let addressName: String?
    let roadAddressName: String?

    enum CodingKeys: String, CodingKey {
        case addressName = "address_name"
        case roadAddressName = "road_address_name"
    }
}

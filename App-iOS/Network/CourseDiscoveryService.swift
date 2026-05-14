import Foundation
import CoreLocation
import Shared

// MARK: - CourseDiscoveryError

/// CourseDiscoveryService가 던지는 에러.
public enum CourseDiscoveryError: Error, Sendable {
    /// API 키가 설정되지 않음
    case unavailable
    /// 쿼리가 너무 짧음 (1자 이하)
    case queryTooShort
    /// 네트워크 오류
    case networkError(Error)
    /// 서버 응답 오류
    case serverError(Int)
}

// MARK: - CourseDiscoveryService

/// 카카오 로컬 API를 사용해 DB 미등록 골프장을 검색·발견하는 서비스.
///
/// 사용 방식:
/// 1. GPS 매칭 없음 → searchNearby()로 근처 카카오 골프장 제안
/// 2. 검색 시 → searchByKeyword()로 로컬 DB와 병렬 호출 후 병합
///
/// API 키 로드: KakaoVerificationService와 동일 우선순위
/// (Info.plist KAKAO_REST_API_KEY → .api-keys.local)
@MainActor
public final class CourseDiscoveryService {

    // MARK: - Shared

    public static let shared = CourseDiscoveryService()

    // MARK: - 상수

    private static let kakaoSearchURL = "https://dapi.kakao.com/v2/local/search/keyword.json"
    /// 캐시 유효 시간 (5분)
    private static let cacheTTL: TimeInterval = 300
    /// 위치 그리드 정밀도 — 소수점 1자리 ≈ 100m
    private static let gridPrecision: Double = 10.0

    // MARK: - 캐시

    /// (query + 위치 그리드 키) → (결과, 만료 시각)
    private var cache: [String: (courses: [DiscoveredCourse], expiresAt: Date)] = [:]

    // MARK: - URLSession (테스트 주입 가능)

    var session: URLSession = .shared

    // MARK: - Init

    private init() {}

    /// 테스트 전용 init — URLSession 주입.
    init(session: URLSession) {
        self.session = session
    }

    // MARK: - Public API

    /// 현재 위치 근처 골프장을 카카오 로컬 API로 검색한다.
    ///
    /// - Parameters:
    ///   - location: 검색 기준 위치
    ///   - radiusM: 검색 반경 (미터). 기본 2000m.
    /// - Returns: 거리 오름차순 정렬된 DiscoveredCourse 목록
    /// - Throws: CourseDiscoveryError.unavailable (API 키 없음)
    public func searchNearby(
        location: CLLocation,
        radiusM: Int = 2000
    ) async throws -> [DiscoveredCourse] {
        guard let apiKey = Self.apiKey(), !apiKey.isEmpty else {
            throw CourseDiscoveryError.unavailable
        }

        // 좌표 유효성 검증
        let lat = location.coordinate.latitude
        let lng = location.coordinate.longitude
        guard lat != 0 || lng != 0,
              lat >= -90 && lat <= 90,
              lng >= -180 && lng <= 180 else {
            return []
        }

        // 캐시 키: "nearby|{그리드 키}|{반경}"
        let gridKey = locationGridKey(location)
        let cacheKey = "nearby|\(gridKey)|\(radiusM)"
        if let cached = cache[cacheKey], cached.expiresAt > Date() {
            return cached.courses
        }

        // 카카오 API 호출
        var components = URLComponents(string: Self.kakaoSearchURL)!
        components.queryItems = [
            URLQueryItem(name: "query", value: "골프장"),
            URLQueryItem(name: "x", value: String(lng)),
            URLQueryItem(name: "y", value: String(lat)),
            URLQueryItem(name: "radius", value: String(radiusM)),
            URLQueryItem(name: "sort", value: "distance"),
            URLQueryItem(name: "size", value: "15")
        ]

        let results = try await fetchAndDecode(
            components: components,
            apiKey: apiKey,
            userLocation: location
        )

        // 캐시 저장 (fetchAndDecode 내부에서 이미 골프장 필터링 완료)
        cache[cacheKey] = (courses: results, expiresAt: Date().addingTimeInterval(Self.cacheTTL))
        return results
    }

    /// 키워드로 골프장을 카카오 로컬 API로 검색한다.
    ///
    /// - Parameters:
    ///   - query: 검색어. 1자 이하면 빈 배열 반환.
    ///   - location: 위치 기반 정렬용 (nil이면 관련도 순 정렬)
    /// - Returns: DiscoveredCourse 목록
    /// - Throws: CourseDiscoveryError.unavailable (API 키 없음)
    public func searchByKeyword(
        query: String,
        location: CLLocation? = nil
    ) async throws -> [DiscoveredCourse] {
        // 빈 쿼리 또는 1자 이하는 빈 배열 반환
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 1 else {
            return []
        }

        guard let apiKey = Self.apiKey(), !apiKey.isEmpty else {
            throw CourseDiscoveryError.unavailable
        }

        // 캐시 키: "keyword|{query}|{그리드 키}"
        let gridKey = location.map { locationGridKey($0) } ?? "nogeo"
        let cacheKey = "keyword|\(trimmed)|\(gridKey)"
        if let cached = cache[cacheKey], cached.expiresAt > Date() {
            return cached.courses
        }

        // 카카오 API 쿼리 구성 — "{query}골프" 패턴
        var components = URLComponents(string: Self.kakaoSearchURL)!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "query", value: "\(trimmed)골프"),
            URLQueryItem(name: "size", value: "15")
        ]

        if let loc = location {
            queryItems += [
                URLQueryItem(name: "x", value: String(loc.coordinate.longitude)),
                URLQueryItem(name: "y", value: String(loc.coordinate.latitude)),
                URLQueryItem(name: "sort", value: "distance")
            ]
        }

        components.queryItems = queryItems

        let results = try await fetchAndDecode(
            components: components,
            apiKey: apiKey,
            userLocation: location
        )

        // 캐시 저장
        cache[cacheKey] = (courses: results, expiresAt: Date().addingTimeInterval(Self.cacheTTL))
        return results
    }

    // MARK: - API 키 로드

    /// API 키 로드. KakaoVerificationService와 동일 우선순위.
    /// 1. Info.plist KAKAO_REST_API_KEY
    /// 2. .api-keys.local 파일
    nonisolated public static func apiKey() -> String? {
        // 1순위: Info.plist (빌드 타임 .xcconfig 주입)
        if let key = Bundle.main.object(forInfoDictionaryKey: "KAKAO_REST_API_KEY") as? String,
           !key.isEmpty,
           key != "$(KAKAO_REST_API_KEY)" {
            return key
        }
        return loadFromLocalFile()
    }

    // MARK: - Private

    /// URL 구성 → 네트워크 요청 → 디코딩 → DiscoveredCourse 변환
    private func fetchAndDecode(
        components: URLComponents,
        apiKey: String,
        userLocation: CLLocation?
    ) async throws -> [DiscoveredCourse] {
        guard let url = components.url else { return [] }

        var request = URLRequest(url: url)
        request.setValue("KakaoAK \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10.0

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            return []
        } catch {
            throw CourseDiscoveryError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else { return [] }
        guard httpResponse.statusCode == 200 else {
            throw CourseDiscoveryError.serverError(httpResponse.statusCode)
        }

        let searchResponse = try JSONDecoder().decode(KakaoDiscoverySearchResponse.self, from: data)

        // 골프장 관련 결과만 필터링: AT4 카테고리 또는 이름/카테고리에 "골프" 포함
        let golfDocs = searchResponse.documents.filter { doc in
            doc.categoryGroupCode == "AT4" || doc.categoryName.contains("골프") || doc.placeName.contains("골프")
        }

        return golfDocs.compactMap { doc -> DiscoveredCourse? in
            guard let lat = Double(doc.y), let lng = Double(doc.x) else { return nil }

            var distKm: Double? = nil
            if let userLoc = userLocation {
                let placeLoc = CLLocation(latitude: lat, longitude: lng)
                distKm = placeLoc.distance(from: userLoc) / 1000.0
            } else if let distStr = doc.distance, let distM = Double(distStr) {
                distKm = distM / 1000.0
            }

            return DiscoveredCourse(
                kakaoPlaceId: doc.id,
                name: doc.placeName,
                address: doc.roadAddressName?.isEmpty == false ? doc.roadAddressName : doc.addressName,
                phone: doc.phone?.isEmpty == false ? doc.phone : nil,
                lat: lat,
                lng: lng,
                placeUrl: doc.placeUrl?.isEmpty == false ? doc.placeUrl : nil,
                distanceKm: distKm
            )
        }
    }

    // NOTE: 카테고리 필터링은 fetchAndDecode 내부에서 doc 기준으로 수행됨.
    // (AT4 카테고리 또는 이름/카테고리에 "골프" 포함 여부 확인)

    /// 위치를 100m 격자 키로 변환 (캐시 granularity).
    private func locationGridKey(_ location: CLLocation) -> String {
        let lat = (location.coordinate.latitude * Self.gridPrecision).rounded() / Self.gridPrecision
        let lng = (location.coordinate.longitude * Self.gridPrecision).rounded() / Self.gridPrecision
        return "\(lat),\(lng)"
    }

    /// .api-keys.local 파일에서 KAKAO_REST_API_KEY 파싱
    nonisolated private static func loadFromLocalFile() -> String? {
        let candidatePaths = [
            Bundle.main.bundlePath + "/../../../../.api-keys.local",
            Bundle.main.bundlePath + "/../../../../../.api-keys.local",
        ]
        for path in candidatePaths {
            let url = URL(fileURLWithPath: path).standardized
            if let content = try? String(contentsOf: url, encoding: .utf8),
               let key = parseKey(from: content, key: "KAKAO_REST_API_KEY"),
               !key.isEmpty {
                return key
            }
        }
        return nil
    }

    nonisolated private static func parseKey(from content: String, key: String) -> String? {
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.hasPrefix("#"), trimmed.contains("=") else { continue }
            let parts = trimmed.components(separatedBy: "=")
            guard parts.count >= 2,
                  parts[0].trimmingCharacters(in: .whitespaces) == key else { continue }
            let value = parts[1...].joined(separator: "=").trimmingCharacters(in: .whitespaces)
            return value.isEmpty ? nil : value
        }
        return nil
    }
}

// MARK: - 카카오 로컬 API 응답 모델 (CourseDiscoveryService 전용)

private struct KakaoDiscoverySearchResponse: Decodable {
    let documents: [KakaoDiscoveryPlace]
    let meta: KakaoDiscoveryMeta?
}

/// 카카오 발견 서비스 전용 응답 모델.
/// categoryGroupCode를 이용해 골프장(AT4) 필터링.
private struct KakaoDiscoveryPlace: Decodable {
    let id: String
    let placeName: String
    let categoryName: String
    let categoryGroupCode: String
    let addressName: String?
    let roadAddressName: String?
    let phone: String?
    let x: String   // 경도 (lng)
    let y: String   // 위도 (lat)
    let placeUrl: String?
    let distance: String?

    enum CodingKeys: String, CodingKey {
        case id
        case placeName = "place_name"
        case categoryName = "category_name"
        case categoryGroupCode = "category_group_code"
        case addressName = "address_name"
        case roadAddressName = "road_address_name"
        case phone
        case x, y
        case placeUrl = "place_url"
        case distance
    }
}

private struct KakaoDiscoveryMeta: Decodable {
    let totalCount: Int
    let isEnd: Bool

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case isEnd = "is_end"
    }
}

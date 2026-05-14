import Foundation
import CoreLocation
import Shared

// MARK: - KakaoVerificationResult

/// 카카오 로컬 API 검증 결과.
/// GPS 매칭된 골프장이 카카오 데이터와 일치하는지 판단하는 데 사용됨.
public enum KakaoVerificationResult: Sendable {
    /// 카카오 API 결과와 200m 이내 좌표 일치 → 자동 매칭 진행
    case matched(distance: Double)
    /// 좌표 불일치(200m 초과) 또는 카카오 검색 결과 없음 → 사용자 확인 필요
    case uncertain(reason: String)
    /// API 키 없음 또는 네트워크 실패 → 검증 스킵, GPS 단독 결과 사용
    case unavailable
}

// MARK: - KakaoVerificationService

/// 카카오 로컬 API를 사용해 GPS 매칭된 골프장을 재검증하는 서비스.
/// F3 GPS 매칭 정확도 보강용 (01-SPEC §F3, 33-SECURITY §API 키 관리).
///
/// 사용 방식:
/// 1. nearestCoursesAdaptive()로 GPS 매칭 후 verify() 호출
/// 2. .matched → "GPS + 카카오 모두 확인됨" 자동 진행
/// 3. .uncertain → 사용자 확인 UI 표시
/// 4. .unavailable → GPS 단독 결과 그대로 사용
@MainActor
public final class KakaoVerificationService {

    // MARK: - Shared

    public static let shared = KakaoVerificationService()

    // MARK: - 캐시

    /// (courseId + 위치 그리드 키) → 결과 + 만료 시각 (5분)
    private var cache: [String: (result: KakaoVerificationResult, expiresAt: Date)] = [:]

    // MARK: - URLSession

    /// 테스트에서 mock으로 교체 가능하도록 주입 가능
    var session: URLSession = .shared

    // MARK: - 카카오 API 상수

    private static let kakaoSearchURL = "https://dapi.kakao.com/v2/local/search/keyword.json"
    /// 200m 이내면 좌표 일치로 판단
    private static let matchThresholdMeters: Double = 200.0
    /// 카카오 키워드 검색 반경 (2km)
    private static let searchRadiusMeters: Int = 2000
    /// 캐시 유효 시간 (5분)
    private static let cacheTTL: TimeInterval = 300

    // MARK: - Init

    private init() {}

    /// 테스트 전용 init — URLSession 주입 가능.
    /// 외부 모듈에서 직접 사용 금지 (테스트 목적).
    init(session: URLSession) {
        self.session = session
    }

    // MARK: - Public API

    /// GPS 매칭된 골프장을 카카오 로컬 API로 재검증한다.
    ///
    /// - Parameters:
    ///   - course: GPS로 매칭된 골프장
    ///   - userLocation: 현재 사용자 위치
    /// - Returns: KakaoVerificationResult
    public func verify(
        course: GolfCourse,
        userLocation: CLLocation
    ) async -> KakaoVerificationResult {
        // API 키 확인
        guard let apiKey = apiKey(), !apiKey.isEmpty else {
            return .unavailable
        }

        // 캐시 확인 (courseId + 100m 그리드 키)
        let gridKey = locationGridKey(userLocation)
        let cacheKey = "\(course.id)|\(gridKey)"
        if let cached = cache[cacheKey], cached.expiresAt > Date() {
            return cached.result
        }

        // clubhouse 좌표 없으면 검증 불가
        guard let clubhouse = course.clubhouse else {
            return .unavailable
        }

        // 카카오 키워드 검색 요청
        let result = await fetchKakaoResult(
            courseName: course.name,
            userLocation: userLocation,
            apiKey: apiKey,
            clubhouse: clubhouse
        )

        // 캐시 저장
        cache[cacheKey] = (result: result, expiresAt: Date().addingTimeInterval(Self.cacheTTL))
        return result
    }

    // MARK: - API 키 로드

    /// API 키 로드 우선순위:
    /// 1. Bundle.main Info.plist의 KAKAO_REST_API_KEY (실 디바이스 배포)
    /// 2. .api-keys.local 파일 파싱 (개발 환경 로컬 fallback)
    ///
    /// 반환값이 nil이면 .unavailable로 처리.
    nonisolated public static func apiKey() -> String? {
        // 1순위: Info.plist (빌드 타임 .xcconfig 주입)
        if let key = Bundle.main.object(forInfoDictionaryKey: "KAKAO_REST_API_KEY") as? String,
           !key.isEmpty,
           key != "$(KAKAO_REST_API_KEY)" {
            return key
        }

        // 2순위: .api-keys.local (로컬 개발 환경)
        return loadFromLocalFile()
    }

    /// 인스턴스 메서드 버전 (테스트 주입 용이)
    nonisolated func apiKey() -> String? {
        KakaoVerificationService.apiKey()
    }

    // MARK: - Private

    /// 카카오 키워드 검색 실행 후 결과 분석
    private func fetchKakaoResult(
        courseName: String,
        userLocation: CLLocation,
        apiKey: String,
        clubhouse: Clubhouse
    ) async -> KakaoVerificationResult {
        // URL 구성
        var components = URLComponents(string: Self.kakaoSearchURL)!
        components.queryItems = [
            URLQueryItem(name: "query", value: "\(courseName) 골프장"),
            URLQueryItem(name: "size", value: "5"),
            URLQueryItem(name: "x", value: String(userLocation.coordinate.longitude)),
            URLQueryItem(name: "y", value: String(userLocation.coordinate.latitude)),
            URLQueryItem(name: "radius", value: String(Self.searchRadiusMeters)),
            URLQueryItem(name: "sort", value: "distance")
        ]

        guard let url = components.url else {
            return .unavailable
        }

        var request = URLRequest(url: url)
        request.setValue("KakaoAK \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10.0

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return .unavailable
            }

            let searchResponse = try JSONDecoder().decode(KakaoLocalSearchResponse.self, from: data)

            // 골프장 카테고리 필터링 (AT4: 체육시설 > 골프장 / 이름 포함 확인)
            let golfPlaces = searchResponse.documents.filter { doc in
                doc.categoryGroupCode == "AT4" || doc.categoryName.contains("골프")
            }

            guard let topPlace = golfPlaces.first,
                  let placeLat = Double(topPlace.y),
                  let placeLng = Double(topPlace.x) else {
                return .uncertain(reason: "카카오에서 '\(courseName)' 골프장을 찾을 수 없어요")
            }

            // 카카오 결과 좌표 ↔ 코스 clubhouse 좌표 비교
            let kakaoLocation = CLLocation(latitude: placeLat, longitude: placeLng)
            let clubhouseLocation = CLLocation(latitude: clubhouse.lat, longitude: clubhouse.lng)
            let distanceMeters = kakaoLocation.distance(from: clubhouseLocation)

            if distanceMeters <= Self.matchThresholdMeters {
                return .matched(distance: distanceMeters)
            } else {
                let distStr = String(format: "%.0f", distanceMeters)
                return .uncertain(
                    reason: "카카오 위치가 DB 좌표와 \(distStr)m 차이가 있어요"
                )
            }

        } catch is CancellationError {
            return .unavailable
        } catch {
            return .unavailable
        }
    }

    /// 사용자 위치를 100m 격자 키로 변환 (캐시 granularity)
    private func locationGridKey(_ location: CLLocation) -> String {
        // 소수점 3자리 = 약 100m 정밀도
        let lat = (location.coordinate.latitude * 10).rounded() / 10
        let lng = (location.coordinate.longitude * 10).rounded() / 10
        return "\(lat),\(lng)"
    }

    /// .api-keys.local 파일에서 KAKAO_REST_API_KEY 파싱
    nonisolated private static func loadFromLocalFile() -> String? {
        // 개발 환경: 프로젝트 루트 기준 탐색
        let candidatePaths = [
            // 실행 파일 옆 (시뮬레이터)
            Bundle.main.bundlePath + "/../../../../.api-keys.local",
            // 테스트 번들
            Bundle.main.bundlePath + "/../../../../../.api-keys.local",
        ]

        for path in candidatePaths {
            let url = URL(fileURLWithPath: path).standardized
            if let content = try? String(contentsOf: url, encoding: .utf8) {
                if let key = parseKeyFromContent(content, key: "KAKAO_REST_API_KEY") {
                    return key
                }
            }
        }

        return nil
    }

    /// `KEY=VALUE` 형식에서 지정 키 값 추출
    nonisolated private static func parseKeyFromContent(_ content: String, key: String) -> String? {
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

// MARK: - 카카오 로컬 API 응답 모델

private struct KakaoLocalSearchResponse: Decodable {
    let documents: [KakaoPlace]
    let meta: KakaoMeta?
}

private struct KakaoPlace: Decodable {
    let id: String
    let placeName: String
    let categoryName: String
    let categoryGroupCode: String
    let x: String  // 경도 (lng)
    let y: String  // 위도 (lat)
    let placeUrl: String?
    let distance: String?

    enum CodingKeys: String, CodingKey {
        case id
        case placeName = "place_name"
        case categoryName = "category_name"
        case categoryGroupCode = "category_group_code"
        case x, y
        case placeUrl = "place_url"
        case distance
    }
}

private struct KakaoMeta: Decodable {
    let totalCount: Int
    let isEnd: Bool

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case isEnd = "is_end"
    }
}

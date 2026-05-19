import Foundation
import SwiftData

// MARK: - CourseRepository

/// 번들 JSON에서 골프장 목록을 로드하는 actor.
/// cold load는 첫 호출 시 1회만 수행하고 이후 메모리 캐시를 반환한다.
/// Watch 앱에는 포함되지 않음 (WatchConnectivity로 수신). iOS 앱 전용.
///
/// 원격 fetch 지원:
/// - fetchRemoteIfStale: cold start 시 호출. 7일 stale 시 GET /v1/courses
/// - fetchRemoteForce: SettingsView 수동 갱신 버튼 시 호출
/// 4단 fallback: 원격(200) → 304/캐시 → 번들 → 빈 배열 + 로그
public actor CourseRepository {
    public static let shared = CourseRepository()

    private var cache: [GolfCourse]?

    // MARK: - 원격 fetch 설정

    /// Worker API base URL (30-API §2.1)
    private static let baseURL = "https://golf.zerolive.co.kr"

    /// Application Support 디스크 캐시 경로
    private static var diskCachePath: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("courses.cache.json")
    }

    // MARK: Public API

    /// 전체 골프장 목록 반환. 첫 호출 시 번들 JSON을 파싱한다.
    public func loadAll() async throws -> [GolfCourse] {
        if let cache { return cache }

        guard let url = Bundle(for: BundleToken.self).url(forResource: "courses", withExtension: "json")
                ?? Bundle.main.url(forResource: "courses", withExtension: "json") else {
            throw CourseRepositoryError.bundleResourceMissing
        }

        let data = try Data(contentsOf: url)
        let dto = try JSONDecoder().decode(CourseDatasetDTO.self, from: data)
        let courses = dto.courses
        self.cache = courses
        return courses
    }

    // MARK: - 원격 fetch (4단 fallback)

    /// cold start 트리거용. staleAfterSeconds 이상 경과 시에만 원격 요청.
    /// context: CoursesSyncMeta ETag 보존용. 라운드 진행 중 호출 금지.
    /// - Returns: (coursesUpdated, parsUpdated) 갱신 여부
    @discardableResult
    public func fetchRemoteIfStale(
        staleAfterSeconds: TimeInterval = 7 * 86_400,
        context: ModelContext
    ) async -> (coursesUpdated: Bool, parsUpdated: Bool) {
        let meta = fetchOrCreateSyncMeta(endpoint: "courses", context: context)
        let elapsed = Date().timeIntervalSince(meta.lastSuccessAt)
        guard elapsed >= staleAfterSeconds else {
            AppLogger.persistence.debug("CourseRepository: stale 미경과 (\(Int(elapsed))s < \(Int(staleAfterSeconds))s) — fetch 생략")
            return (false, false)
        }
        let coursesUpdated = await fetchEndpoint("courses", meta: meta, context: context)
        let parsMeta = fetchOrCreateSyncMeta(endpoint: "course-pars", context: context)
        let parsUpdated = await fetchEndpoint("course-pars", meta: parsMeta, context: context)
        return (coursesUpdated, parsUpdated)
    }

    /// SettingsView 수동 갱신 — stale 여부 무관하게 강제 fetch.
    /// - Returns: (coursesUpdated, parsUpdated) 갱신 여부
    @discardableResult
    public func fetchRemoteForce(context: ModelContext) async -> (coursesUpdated: Bool, parsUpdated: Bool) {
        let meta = fetchOrCreateSyncMeta(endpoint: "courses", context: context)
        let coursesUpdated = await fetchEndpoint("courses", meta: meta, context: context)
        let parsMeta = fetchOrCreateSyncMeta(endpoint: "course-pars", context: context)
        let parsUpdated = await fetchEndpoint("course-pars", meta: parsMeta, context: context)
        return (coursesUpdated, parsUpdated)
    }

    // MARK: - Private fetch logic

    /// 단일 endpoint fetch. 4단 fallback 처리.
    /// - Returns: 새 데이터로 캐시 갱신 여부
    private func fetchEndpoint(
        _ endpoint: String,
        meta: CoursesSyncMeta,
        context: ModelContext
    ) async -> Bool {
        let urlString = "\(Self.baseURL)/v1/\(endpoint)"
        guard let url = URL(string: urlString) else {
            AppLogger.persistence.error("CourseRepository: 잘못된 URL — \(urlString)")
            return false
        }

        meta.lastFetchedAt = Date()
        try? context.save()

        // A. 원격 요청
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.httpMethod = "GET"
        if !meta.etag.isEmpty {
            request.setValue(meta.etag, forHTTPHeaderField: "If-None-Match")
        }
        if let token = bearerToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return await fallbackToCache(endpoint: endpoint)
            }

            if http.statusCode == 304 {
                // B. 304 — 캐시 그대로
                AppLogger.persistence.info("CourseRepository [\(endpoint)]: 304 Not Modified — 캐시 유효")
                meta.lastSuccessAt = Date()
                try? context.save()
                return false
            }

            if (200...299).contains(http.statusCode) {
                // A. 200 — 새 데이터
                let newEtag = http.value(forHTTPHeaderField: "ETag") ?? ""
                meta.etag = newEtag
                meta.lastSuccessAt = Date()
                try? context.save()

                // 디스크 캐시 기록 (endpoint별)
                writeDiskCache(data: data, endpoint: endpoint)

                // courses 엔드포인트면 인메모리 캐시 갱신
                if endpoint == "courses" {
                    await updateCourseCache(data: data, source: "remote")
                    return true
                }
                return true
            }

            AppLogger.persistence.warning("CourseRepository [\(endpoint)]: HTTP \(http.statusCode) — fallback")
            return await fallbackToCache(endpoint: endpoint)

        } catch {
            AppLogger.persistence.warning("CourseRepository [\(endpoint)]: 네트워크 오류 — \(error.localizedDescription)")
            return await fallbackToCache(endpoint: endpoint)
        }
    }

    /// B/C: 디스크 캐시 → 번들 순서 fallback. 캐시 7일 stale 여부와 무관하게 디스크 우선.
    private func fallbackToCache(endpoint: String) async -> Bool {
        // B. 디스크 캐시
        if endpoint == "courses", let cacheURL = diskCacheURL(endpoint: endpoint),
           let data = try? Data(contentsOf: cacheURL) {
            AppLogger.persistence.info("CourseRepository [\(endpoint)]: 디스크 캐시 사용")
            await updateCourseCache(data: data, source: "disk-cache")
            return false
        }

        // C. 번들 리소스 (이미 loadAll에서 처리되므로 여기서는 로그만)
        AppLogger.persistence.info("CourseRepository [\(endpoint)]: 번들 리소스 fallback")
        // D: 캐시/번들 모두 실패 시 현재 인메모리 상태 유지 (크래시 금지)
        return false
    }

    /// 새 JSON 데이터로 인메모리 courses 캐시 업데이트.
    private func updateCourseCache(data: Data, source: String) async {
        do {
            let dto = try JSONDecoder().decode(CourseDatasetDTO.self, from: data)
            self.cache = dto.courses
            AppLogger.persistence.info("CourseRepository: 캐시 갱신 (\(source)) — \(dto.courses.count)개 골프장")
        } catch {
            AppLogger.persistence.error("CourseRepository: JSON 파싱 실패 (\(source)) — \(error.localizedDescription)")
        }
    }

    /// Bearer 토큰 로딩.
    /// Info.plist → .api-keys.local 순서 (카카오 키 패턴과 동일).
    private func bearerToken() -> String? {
        // 1순위: Info.plist (빌드 타임 .xcconfig 주입)
        if let token = Bundle.main.object(forInfoDictionaryKey: "ROUNDON_API_BEARER") as? String,
           !token.isEmpty,
           token != "$(ROUNDON_API_BEARER)" {
            return token
        }
        // 2순위: .api-keys.local
        let candidatePaths = [
            Bundle.main.bundlePath + "/../../../../.api-keys.local",
            Bundle.main.bundlePath + "/../../../../../.api-keys.local",
        ]
        for path in candidatePaths {
            let url = URL(fileURLWithPath: path).standardized
            if let content = try? String(contentsOf: url, encoding: .utf8) {
                for line in content.components(separatedBy: .newlines) {
                    let t = line.trimmingCharacters(in: .whitespaces)
                    guard !t.hasPrefix("#"), t.contains("=") else { continue }
                    let parts = t.components(separatedBy: "=")
                    guard parts.count >= 2,
                          parts[0].trimmingCharacters(in: .whitespaces) == "ROUNDON_API_BEARER" else { continue }
                    let value = parts[1...].joined(separator: "=").trimmingCharacters(in: .whitespaces)
                    return value.isEmpty ? nil : value
                }
            }
        }
        return nil
    }

    /// CoursesSyncMeta fetch or create (FetchDescriptor 조회 후 없으면 insert)
    private func fetchOrCreateSyncMeta(endpoint: String, context: ModelContext) -> CoursesSyncMeta {
        var descriptor = FetchDescriptor<CoursesSyncMeta>(
            predicate: #Predicate { $0.endpoint == endpoint }
        )
        descriptor.fetchLimit = 1
        if let existing = (try? context.fetch(descriptor))?.first {
            return existing
        }
        let meta = CoursesSyncMeta(endpoint: endpoint)
        context.insert(meta)
        try? context.save()
        return meta
    }

    private func writeDiskCache(data: Data, endpoint: String) {
        guard let url = diskCacheURL(endpoint: endpoint) else { return }
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }

    private func diskCacheURL(endpoint: String) -> URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("\(endpoint).cache.json")
    }

    /// 이름 prefix로 골프장 검색 (대소문자 무시, 한글 포함).
    /// - Parameter prefix: 검색어. 빈 문자열이면 전체 반환.
    public func search(byName prefix: String) async throws -> [GolfCourse] {
        let all = try await loadAll()
        guard !prefix.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(prefix) }
    }

    /// 지역명으로 필터링.
    /// - Parameter region: "경기", "서울" 등 지역 문자열.
    public func filter(region: String) async throws -> [GolfCourse] {
        let all = try await loadAll()
        return all.filter { $0.region == region }
    }

    /// 특정 좌표 근처 골프장 목록 반환 (haversine 거리 기준 오름차순 정렬).
    /// clubhouse 좌표가 없는 코스는 제외된다.
    ///
    /// - Parameters:
    ///   - coord: 기준 좌표 (lat, lng)
    ///   - limit: 반환할 최대 개수 (기본 20)
    /// - Returns: 거리 오름차순으로 정렬된 골프장 목록
    public func nearestCourses(
        to coord: (lat: Double, lng: Double),
        limit: Int = 20
    ) async throws -> [GolfCourse] {
        let all = try await loadAll()

        // clubhouse 좌표 있는 코스만 대상
        let withCoord = all.compactMap { course -> (GolfCourse, Double)? in
            guard let ch = course.clubhouse else { return nil }
            let dist = haversineKm(
                lat1: coord.lat, lng1: coord.lng,
                lat2: ch.lat, lng2: ch.lng
            )
            return (course, dist)
        }

        // 거리 오름차순 정렬 후 limit 개수 반환
        return withCoord
            .sorted { $0.1 < $1.1 }
            .prefix(limit)
            .map { $0.0 }
    }

    // MARK: - 적응형 임계값 매칭

    /// 지역별 골프장 밀도를 고려한 적응형 임계값 기반 가장 가까운 골프장 탐색.
    ///
    /// 알고리즘:
    /// 1. 1km 반경 검색 → 결과 있으면 가장 가까운 1건 자동 매칭
    /// 2. 1km 없으면 3km 반경 → 1건이면 자동 매칭, 2건 이상이면 후보 목록 반환
    /// 3. 3km 없으면 5km 반경 → 후보 목록만 (자동 매칭 X)
    /// 4. 5km에도 없으면 matched: nil + candidates: []
    ///
    /// - Parameter coord: 기준 좌표 (lat, lng)
    /// - Returns: (matched: 단일 자동 매칭 결과, candidates: 후보 목록, radiusKm: 실제 사용된 반경)
    public func nearestCoursesAdaptive(
        to coord: (lat: Double, lng: Double)
    ) async throws -> AdaptiveMatchResult {
        let all = try await loadAll()

        // clubhouse 좌표 있는 코스만 거리와 함께 계산
        let withDistance: [(GolfCourse, Double)] = all.compactMap { course in
            guard let ch = course.clubhouse else { return nil }
            let dist = haversineKm(
                lat1: coord.lat, lng1: coord.lng,
                lat2: ch.lat, lng2: ch.lng
            )
            return (course, dist)
        }
        let sorted = withDistance.sorted { $0.1 < $1.1 }

        // 1단계: 1km 반경
        let within1km = sorted.filter { $0.1 <= 1.0 }
        if let best = within1km.first {
            return AdaptiveMatchResult(
                matched: best.0,
                candidates: [best.0],
                radiusKm: 1.0
            )
        }

        // 2단계: 3km 반경
        let within3km = sorted.filter { $0.1 <= 3.0 }
        if within3km.count == 1 {
            // 단일 결과 → 자동 매칭
            return AdaptiveMatchResult(
                matched: within3km[0].0,
                candidates: [within3km[0].0],
                radiusKm: 3.0
            )
        } else if within3km.count > 1 {
            // 다중 결과 → 후보 목록, 자동 매칭 X
            return AdaptiveMatchResult(
                matched: nil,
                candidates: within3km.map { $0.0 },
                radiusKm: 3.0
            )
        }

        // 3단계: 5km 반경
        let within5km = sorted.filter { $0.1 <= 5.0 }
        if !within5km.isEmpty {
            return AdaptiveMatchResult(
                matched: nil,
                candidates: within5km.map { $0.0 },
                radiusKm: 5.0
            )
        }

        // 4단계: 매칭 없음
        return AdaptiveMatchResult(
            matched: nil,
            candidates: [],
            radiusKm: 5.0
        )
    }

    // MARK: - 캐시 포함 적응형 매칭

    /// 번들 GolfCourse + 영구 캐시된 DiscoveredCourse를 합산한 적응형 매칭.
    ///
    /// PersistedDiscoveredCourse는 호출자가 fetch해 GolfCourse로 변환한 뒤 전달한다.
    /// 이 메서드는 두 소스를 병합 후 nearestCoursesAdaptive와 동일 알고리즘 적용.
    ///
    /// - Parameters:
    ///   - coord: 기준 좌표 (lat, lng)
    ///   - cachedDiscovered: PersistedDiscoveredCourse.toGolfCourse()로 변환된 목록
    /// - Returns: AdaptiveMatchResult
    public func nearestCoursesAdaptiveWithCache(
        to coord: (lat: Double, lng: Double),
        cachedDiscovered: [GolfCourse]
    ) async throws -> AdaptiveMatchResult {
        let bundleCourses = try await loadAll()

        // 번들 ID 집합으로 중복 제거 (kakao: 접두 ID는 번들에 없으므로 자연 분리됨)
        let merged = bundleCourses + cachedDiscovered

        let withDistance: [(GolfCourse, Double)] = merged.compactMap { course in
            guard let ch = course.clubhouse else { return nil }
            let dist = haversineKm(
                lat1: coord.lat, lng1: coord.lng,
                lat2: ch.lat, lng2: ch.lng
            )
            return (course, dist)
        }
        let sorted = withDistance.sorted { $0.1 < $1.1 }

        // 1단계: 1km 반경
        let within1km = sorted.filter { $0.1 <= 1.0 }
        if let best = within1km.first {
            return AdaptiveMatchResult(matched: best.0, candidates: [best.0], radiusKm: 1.0)
        }

        // 2단계: 3km 반경
        let within3km = sorted.filter { $0.1 <= 3.0 }
        if within3km.count == 1 {
            return AdaptiveMatchResult(matched: within3km[0].0, candidates: [within3km[0].0], radiusKm: 3.0)
        } else if within3km.count > 1 {
            return AdaptiveMatchResult(matched: nil, candidates: within3km.map { $0.0 }, radiusKm: 3.0)
        }

        // 3단계: 5km 반경
        let within5km = sorted.filter { $0.1 <= 5.0 }
        if !within5km.isEmpty {
            return AdaptiveMatchResult(matched: nil, candidates: within5km.map { $0.0 }, radiusKm: 5.0)
        }

        // 4단계: 매칭 없음
        return AdaptiveMatchResult(matched: nil, candidates: [], radiusKm: 5.0)
    }

    // MARK: - 통합 이름 검색

    /// 번들 DB + 영구 캐시 GolfCourse를 병합해 prefix 검색한다.
    ///
    /// - Parameters:
    ///   - prefix: 검색어. 빈 문자열이면 전체 반환.
    ///   - cachedDiscovered: PersistedDiscoveredCourse.toGolfCourse()로 변환된 목록
    /// - Returns: 이름 검색 결과 (번들 + 캐시 병합)
    public func searchAll(
        prefix: String,
        cachedDiscovered: [GolfCourse]
    ) async throws -> [GolfCourse] {
        let bundleResults = try await search(byName: prefix)

        if prefix.isEmpty {
            return bundleResults + cachedDiscovered
        }

        let cachedResults = cachedDiscovered.filter {
            $0.name.localizedCaseInsensitiveContains(prefix)
        }

        return bundleResults + cachedResults
    }
}

// MARK: - AdaptiveMatchResult

/// nearestCoursesAdaptive 반환 타입.
/// matched가 nil이고 candidates가 비어있으면 "매칭 없음" 상태.
public struct AdaptiveMatchResult: Sendable {
    /// 단일 자동 매칭된 골프장. 다중 후보 또는 없음이면 nil.
    public let matched: GolfCourse?
    /// 반경 내 모든 후보 목록 (거리 오름차순).
    public let candidates: [GolfCourse]
    /// 실제 탐색에 사용된 반경 (km).
    public let radiusKm: Double

    public init(matched: GolfCourse?, candidates: [GolfCourse], radiusKm: Double) {
        self.matched = matched
        self.candidates = candidates
        self.radiusKm = radiusKm
    }
}

// MARK: - CourseRepositoryError

public enum CourseRepositoryError: Error, Sendable {
    case bundleResourceMissing
}

// MARK: - Private DTO

/// JSON 최상위 래퍼. 외부에는 [GolfCourse]만 노출.
private struct CourseDatasetDTO: Codable {
    let version: String
    let totalCourses: Int
    let courses: [GolfCourse]
}

/// framework 번들 탐색용 토큰 클래스.
private final class BundleToken {}

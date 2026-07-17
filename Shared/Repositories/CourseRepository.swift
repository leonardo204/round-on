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
        saveSyncMeta(context: context, step: "lastFetchedAt", endpoint: endpoint)

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
                // B. 304 — 캐시 그대로 (성공으로 간주)
                AppLogger.persistence.info("CourseRepository [\(endpoint)]: 304 Not Modified — 캐시 유효")
                meta.lastSuccessAt = Date()
                saveSyncMeta(context: context, step: "304.lastSuccessAt", endpoint: endpoint)
                return false
            }

            if (200...299).contains(http.statusCode) {
                // A. 200 — 새 데이터. 디스크에 기록 후 디코드+머지 성공 시에만 lastSuccessAt 기록.
                let newEtag = http.value(forHTTPHeaderField: "ETag") ?? ""
                meta.etag = newEtag
                // ★ lastSuccessAt은 디코드+머지 성공 후에만 기록 (아래 updateCacheXxx 내부)
                saveSyncMeta(context: context, step: "etag", endpoint: endpoint)

                // 디스크 캐시 기록 (endpoint별)
                writeDiskCache(data: data, endpoint: endpoint)

                if endpoint == "courses" {
                    let ok = await updateCourseListCache(data: data, source: "remote")
                    if ok {
                        meta.lastSuccessAt = Date()
                        saveSyncMeta(context: context, step: "courses.lastSuccessAt", endpoint: endpoint)
                    }
                    return ok
                } else if endpoint == "course-pars" {
                    let merged = await mergeCourseParCache(data: data, source: "remote")
                    if merged >= 0 {
                        meta.lastSuccessAt = Date()
                        saveSyncMeta(context: context, step: "course-pars.lastSuccessAt", endpoint: endpoint)
                    }
                    return merged > 0
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
        // B. 디스크 캐시 (course-pars도 별도 캐시에서 복원 시도)
        if let cacheURL = diskCacheURL(endpoint: endpoint),
           let data = try? Data(contentsOf: cacheURL) {
            AppLogger.persistence.info("CourseRepository [\(endpoint)]: 디스크 캐시 사용")
            if endpoint == "courses" {
                await updateCourseListCache(data: data, source: "disk-cache")
            } else if endpoint == "course-pars" {
                await mergeCourseParCache(data: data, source: "disk-cache")
            }
            return false
        }

        // C. 번들 리소스 (이미 loadAll에서 처리되므로 여기서는 로그만)
        AppLogger.persistence.info("CourseRepository [\(endpoint)]: 번들 리소스 fallback")
        // D: 캐시/번들 모두 실패 시 현재 인메모리 상태 유지 (크래시 금지)
        return false
    }

    /// /v1/courses 응답 처리 — 관대한 minimal DTO로 디코드 (id+name만 확인).
    /// 번들 캐시를 교체하지 않고 코스 존재 여부 로깅만 수행.
    /// - Returns: 디코드 성공 여부
    @discardableResult
    private func updateCourseListCache(data: Data, source: String) async -> Bool {
        do {
            let dto = try JSONDecoder().decode(RemoteCoursesDTO.self, from: data)
            AppLogger.persistence.info("CourseRepository: /v1/courses 디코드 성공 (\(source)) — \(dto.courses.count)개 메타 확인 (번들 캐시 유지)")
            // ★ 번들 캐시 교체 금지 — id+name 메타만 확인하고 끝
            return true
        } catch {
            AppLogger.persistence.error("CourseRepository: /v1/courses 파싱 실패 (\(source)) — \(error.localizedDescription)")
            return false
        }
    }

    /// /v1/course-pars 응답을 번들 인메모리 캐시에 머지(보강).
    /// id 우선 매칭 → 이름 유사도 폴백. 매칭된 코스의 subCourses.holes에 par 채우고 dataQuality 승격.
    /// - Returns: 머지된 코스 수 (실패 시 -1)
    @discardableResult
    private func mergeCourseParCache(data: Data, source: String) async -> Int {
        do {
            let dto = try JSONDecoder().decode(RemoteCourseParsDTO.self, from: data)
            AppLogger.persistence.info("CourseRepository: /v1/course-pars 디코드 성공 (\(source)) — \(dto.coursePars.count)개")

            // 번들 캐시 로드 (없으면 번들에서 로드)
            let baseCourses: [GolfCourse]
            if let cached = self.cache {
                baseCourses = cached
            } else {
                baseCourses = (try? await loadAll()) ?? []
            }

            var courseById = Dictionary(uniqueKeysWithValues: baseCourses.map { ($0.id, $0) })
            var mergedCount = 0
            var skipCount = 0

            for parEntry in dto.coursePars {
                // 1순위: id 직접 매칭
                if courseById[parEntry.courseId] != nil {
                    let enriched = applyParsToGolfCourse(courseById[parEntry.courseId]!, parEntry: parEntry)
                    courseById[parEntry.courseId] = enriched
                    mergedCount += 1
                } else {
                    // 2순위: 이름 유사도 매칭 (id 불일치 폴백)
                    var nameMatched = false
                    for (bid, bc) in courseById {
                        if CourseNameMatcher.areSimilar(bc.name, parEntry.courseName) {
                            let enriched = applyParsToGolfCourse(bc, parEntry: parEntry)
                            courseById[bid] = enriched
                            mergedCount += 1
                            nameMatched = true
                            AppLogger.persistence.debug("CourseRepository: 이름 매칭 — '\(parEntry.courseName)' → '\(bc.name)'")
                            break
                        }
                    }
                    if !nameMatched {
                        skipCount += 1
                        AppLogger.persistence.debug("CourseRepository: 매칭 실패 스킵 — '\(parEntry.courseId)' (\(parEntry.courseName))")
                    }
                }
            }

            // 머지된 결과를 인메모리 캐시에 반영
            let mergedList = baseCourses.map { courseById[$0.id] ?? $0 }
            self.cache = mergedList
            AppLogger.persistence.info("CourseRepository: par 머지 완료 — \(mergedCount)개 보강, \(skipCount)개 스킵 (총 \(mergedList.count)개)")
            return mergedCount

        } catch {
            AppLogger.persistence.error("CourseRepository: /v1/course-pars 파싱 실패 (\(source)) — \(error.localizedDescription)")
            return -1
        }
    }

    /// API coursePar 항목을 기존 GolfCourse에 보강하여 새 인스턴스 반환.
    /// subCourses를 API 데이터 기반으로 교체 (par가 신뢰원천: 골프존 > 번들).
    /// dataQuality를 .verified로 승격.
    private func applyParsToGolfCourse(_ course: GolfCourse, parEntry: RemoteCourseParsDTO.CoursePar) -> GolfCourse {
        CourseRepository.applyPars(course, parEntry: parEntry)
    }

    /// 테스트 및 외부 접근용 static helper (actor 격리 없이 호출 가능).
    /// applyParsToGolfCourse의 순수 함수 구현체. actor isolation과 무관.
    internal static func applyPars(_ course: GolfCourse, parEntry: RemoteCourseParsDTO.CoursePar) -> GolfCourse {
        // API subCourses → [SubCourse] with holes filled from pars
        let newSubCourses: [SubCourse] = parEntry.subCourses.map { apiSub in
            let holes = apiSub.pars.enumerated().map { idx, par in
                HoleInfo(number: idx + 1, par: par)
            }
            return SubCourse(name: apiSub.name, holes: holes)
        }

        return GolfCourse(
            id: course.id,
            name: course.name,
            subName: course.subName,
            region: course.region,
            address: course.address,
            phone: course.phone,
            clubhouse: course.clubhouse,
            holesCount: course.holesCount,
            courseType: course.courseType,
            kakaoPlaceUrl: course.kakaoPlaceUrl,
            subCourses: newSubCourses,
            holes: course.holes,   // 기존 홀 좌표 데이터 보존
            dataQuality: .verified,
            sources: course.sources,
            aliases: course.aliases
        )
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
        saveSyncMeta(context: context, step: "createSyncMeta", endpoint: endpoint)
        return meta
    }

    /// CoursesSyncMeta 저장 전용 통로. 실패해도 골프장 데이터 자체는 디스크 캐시/번들로 서빙되므로
    /// 흐름을 중단하지 않지만, 실패가 누적되면 etag/stale 판정이 깨져 매 실행마다 재fetch(사용자 데이터 소모)가
    /// 발생하므로 반드시 로그로 남긴다.
    private func saveSyncMeta(context: ModelContext, step: String, endpoint: String) {
        do {
            try context.save()
        } catch {
            AppLogger.persistence.error("CourseRepository [\(endpoint)]: sync meta 저장 실패 (\(step)) — \(error.localizedDescription)")
        }
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
    /// name contains 매칭에 더해 alias 정규화 매칭(CourseNameMatcher.matches)도 OR 조건으로 포함한다.
    /// - Parameter prefix: 검색어. 빈 문자열이면 전체 반환.
    public func search(byName prefix: String) async throws -> [GolfCourse] {
        let all = try await loadAll()
        guard !prefix.isEmpty else { return all }
        return all.filter {
            $0.name.localizedCaseInsensitiveContains(prefix)
                || CourseNameMatcher.matches(course: $0, query: prefix)
        }
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
                || CourseNameMatcher.matches(course: $0, query: prefix)
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

/// 번들 JSON 최상위 래퍼. loadAll() 전용 (full GolfCourse 디코드). 외부에는 [GolfCourse]만 노출.
private struct CourseDatasetDTO: Codable {
    let version: String
    let totalCourses: Int
    let courses: [GolfCourse]
}

// MARK: - 원격 전용 관대한 DTO

/// GET /v1/courses 응답용 minimal DTO.
/// 실제 페이로드: { version?, updatedAt?, schema?, count?, courses:[{id, name}] }
/// 필드 누락 시 디코드 실패 없도록 전부 Optional 처리.
struct RemoteCoursesDTO: Codable {
    let version: String?
    let updatedAt: String?
    let schema: Int?
    let count: Int?
    let courses: [RemoteCourseItem]

    struct RemoteCourseItem: Codable {
        let id: String
        let name: String
    }
}

/// GET /v1/course-pars 응답용 DTO.
/// 실제 페이로드: { version?, updatedAt?, schema?, count?, coursePars:[{courseId, courseName, subCourses:[{name, pars:[Int]}]}] }
struct RemoteCourseParsDTO: Codable {
    let version: String?
    let updatedAt: String?
    let schema: Int?
    let count: Int?
    let coursePars: [CoursePar]

    struct CoursePar: Codable {
        let courseId: String
        let courseName: String
        let subCourses: [SubCoursePar]
    }

    struct SubCoursePar: Codable {
        let name: String
        let pars: [Int]
    }
}

/// framework 번들 탐색용 토큰 클래스.
private final class BundleToken {}

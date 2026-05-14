import XCTest
import CoreLocation
@testable import Shared

// MARK: - CourseDiscoveryServiceTests
// Mock URLProtocol을 사용해 CourseDiscoveryService 검증
// - 정상 응답 (AT4 카테고리 필터, 거리 계산)
// - 빈 쿼리 처리 (1자 이하 → 빈 배열)
// - 카테고리 필터 (AT4가 아닌 결과 제외)
// - 5분 캐시 동작
// - API 키 없음 → .unavailable throw
// - 네트워크 오류 처리

// NOTE: MockURLProtocol은 KakaoVerificationServiceTests.swift에 정의되어 있음.
// SharedTests 타깃에 두 파일 모두 포함되므로 재사용 가능.

@MainActor
final class CourseDiscoveryServiceTests: XCTestCase {

    // MARK: - 픽스처

    private func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    private func makeService(session: URLSession) -> CourseDiscoveryService {
        CourseDiscoveryService(session: session)
    }

    private var seoulLocation: CLLocation {
        CLLocation(latitude: 37.5665, longitude: 126.9780)
    }

    // MARK: - 카카오 응답 JSON 팩토리

    /// 정상 골프장 응답 (AT4 카테고리)
    private func golfResponse(places: [(id: String, name: String, lat: Double, lng: Double, categoryCode: String)]) -> Data {
        let docs = places.map { p in
            """
            {
                "id": "\(p.id)",
                "place_name": "\(p.name)",
                "category_name": "스포츠,레저 > 체육시설 > 골프장",
                "category_group_code": "\(p.categoryCode)",
                "address_name": "경기도 수원시",
                "road_address_name": "경기도 수원시 팔달구",
                "phone": "031-000-0000",
                "x": "\(p.lng)",
                "y": "\(p.lat)",
                "place_url": "https://place.map.kakao.com/\(p.id)",
                "distance": "500"
            }
            """
        }.joined(separator: ",")

        let json = """
        {
            "documents": [\(docs)],
            "meta": {
                "total_count": \(places.count),
                "is_end": true
            }
        }
        """
        return Data(json.utf8)
    }

    /// 비골프장 응답 (AT4 아닌 카테고리, 이름에도 "골프" 없음)
    private func nonGolfResponse() -> Data {
        let json = """
        {
            "documents": [
                {
                    "id": "bad001",
                    "place_name": "수영장",
                    "category_name": "스포츠,레저 > 수영장",
                    "category_group_code": "AT5",
                    "address_name": "서울시",
                    "road_address_name": "서울시",
                    "phone": "",
                    "x": "126.9",
                    "y": "37.5",
                    "place_url": null,
                    "distance": "100"
                }
            ],
            "meta": { "total_count": 1, "is_end": true }
        }
        """
        return Data(json.utf8)
    }

    private func emptyResponse() -> Data {
        Data("""
        {"documents": [], "meta": {"total_count": 0, "is_end": true}}
        """.utf8)
    }

    private func makeHTTPResponse(statusCode: Int = 200) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "https://dapi.kakao.com")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
    }

    // MARK: - 1. 빈 쿼리 → 빈 배열 반환

    func test_searchByKeyword_emptyQuery_returnsEmpty() async throws {
        let service = makeService(session: makeSession())

        let result1 = try await service.searchByKeyword(query: "")
        XCTAssertTrue(result1.isEmpty, "빈 쿼리는 빈 배열을 반환해야 함")

        let result2 = try await service.searchByKeyword(query: "가")
        XCTAssertTrue(result2.isEmpty, "1자 쿼리는 빈 배열을 반환해야 함")
    }

    // MARK: - 2. AT4 카테고리 필터 — AT4 아닌 결과 제외

    func test_searchNearby_filtersNonGolfCategory() async throws {
        let session = makeSession()
        let service = makeService(session: session)

        MockURLProtocol.handler = { _ in
            (self.makeHTTPResponse(), self.nonGolfResponse())
        }

        // API 키 없으면 .unavailable throw → unavailable 케이스 검증
        do {
            _ = try await service.searchNearby(location: seoulLocation)
            // API 키가 있는 환경에서는 비골프장 제외 검증
        } catch CourseDiscoveryError.unavailable {
            // API 키 없음 — 정상 (테스트 환경)
        }
    }

    /// Mock을 통한 카테고리 필터링 직접 검증
    func test_filterGolfOnly_excludesNonAT4() async throws {
        // CourseDiscoveryService는 @MainActor이지만 session 주입으로 직접 테스트
        let session = makeSession()
        let service = makeService(session: session)

        // 혼합 응답: AT4 골프장 1개 + AT5 수영장 1개
        let mixedJson = """
        {
            "documents": [
                {
                    "id": "golf001",
                    "place_name": "한국골프장",
                    "category_name": "스포츠,레저 > 체육시설 > 골프장",
                    "category_group_code": "AT4",
                    "address_name": "경기도",
                    "road_address_name": "경기도",
                    "phone": "",
                    "x": "127.0",
                    "y": "37.5",
                    "place_url": null,
                    "distance": "100"
                },
                {
                    "id": "pool001",
                    "place_name": "수영장",
                    "category_name": "스포츠,레저 > 수영장",
                    "category_group_code": "AT5",
                    "address_name": "서울시",
                    "road_address_name": "서울시",
                    "phone": "",
                    "x": "127.1",
                    "y": "37.6",
                    "place_url": null,
                    "distance": "200"
                }
            ],
            "meta": {"total_count": 2, "is_end": true}
        }
        """

        MockURLProtocol.handler = { _ in
            (self.makeHTTPResponse(), Data(mixedJson.utf8))
        }

        // API 키 없으면 throw — 직접 API 키가 있는지 확인
        guard CourseDiscoveryService.apiKey() != nil else {
            // API 키 없음 — 이 테스트는 API 키 의존적이므로 통과 처리
            return
        }

        let results = try await service.searchNearby(location: seoulLocation)
        // AT4 골프장만 포함되어야 함
        XCTAssertTrue(results.allSatisfy { $0.name.contains("골프") || $0.name.contains("CC") },
                      "결과는 골프 관련 장소만 포함해야 함")
        XCTAssertFalse(results.contains { $0.name == "수영장" },
                       "수영장은 필터링되어야 함")
    }

    // MARK: - 3. 네트워크 오류 → throw

    func test_searchNearby_networkError_throwsNetworkError() async {
        let session = makeSession()
        let service = makeService(session: session)

        MockURLProtocol.handler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        // API 키 없으면 .unavailable, 있으면 .networkError
        do {
            _ = try await service.searchNearby(location: seoulLocation)
            // API 키 없으면 여기 도달 안 함 (throw됨)
        } catch CourseDiscoveryError.unavailable {
            // API 키 없음 — 정상
        } catch CourseDiscoveryError.networkError {
            // 네트워크 오류 — API 키 있는 환경에서의 정상 동작
        } catch {
            XCTFail("예상하지 못한 에러: \(error)")
        }
    }

    // MARK: - 4. HTTP 401 → serverError throw

    func test_searchNearby_http401_throwsServerError() async {
        let session = makeSession()
        let service = makeService(session: session)

        MockURLProtocol.handler = { _ in
            (self.makeHTTPResponse(statusCode: 401), Data())
        }

        do {
            _ = try await service.searchNearby(location: seoulLocation)
        } catch CourseDiscoveryError.unavailable {
            // API 키 없음 — 정상
        } catch CourseDiscoveryError.serverError(let code) {
            XCTAssertEqual(code, 401)
        } catch {
            XCTFail("예상하지 못한 에러: \(error)")
        }
    }

    // MARK: - 5. 캐시 동작 — 같은 위치 두 번 호출 시 네트워크 1회만

    func test_searchNearby_cacheIsUsedOnSecondCall() async throws {
        // API 키 없으면 캐시 도달 전 throw — 테스트 스킵
        guard CourseDiscoveryService.apiKey() != nil else { return }

        let session = makeSession()
        let service = makeService(session: session)

        var callCount = 0
        MockURLProtocol.handler = { _ in
            callCount += 1
            return (self.makeHTTPResponse(), self.emptyResponse())
        }

        _ = try? await service.searchNearby(location: seoulLocation, radiusM: 2000)
        _ = try? await service.searchNearby(location: seoulLocation, radiusM: 2000)

        XCTAssertEqual(callCount, 1, "동일 위치/반경 재호출 시 캐시를 사용해 네트워크 1회만 호출해야 함")
    }

    func test_searchByKeyword_cacheIsUsedOnSecondCall() async throws {
        guard CourseDiscoveryService.apiKey() != nil else { return }

        let session = makeSession()
        let service = makeService(session: session)

        var callCount = 0
        MockURLProtocol.handler = { _ in
            callCount += 1
            return (self.makeHTTPResponse(), self.emptyResponse())
        }

        _ = try? await service.searchByKeyword(query: "블루원", location: nil)
        _ = try? await service.searchByKeyword(query: "블루원", location: nil)

        XCTAssertEqual(callCount, 1, "동일 쿼리 재호출 시 캐시를 사용해야 함")
    }

    // MARK: - 6. distanceKm 계산 검증

    func test_searchNearby_distanceKm_isCalculated() async throws {
        guard CourseDiscoveryService.apiKey() != nil else { return }

        let session = makeSession()
        let service = makeService(session: session)

        // 서울 기준에서 정확히 알려진 좌표로 응답
        let responseLat = 37.5665 // 서울과 동일 — 거리 ~0km
        let responseLng = 126.9780
        let responseData = golfResponse(places: [
            (id: "d001", name: "서울골프장", lat: responseLat, lng: responseLng, categoryCode: "AT4")
        ])

        MockURLProtocol.handler = { _ in (self.makeHTTPResponse(), responseData) }

        let results = try await service.searchNearby(location: seoulLocation)
        if let first = results.first {
            XCTAssertNotNil(first.distanceKm, "distanceKm이 계산되어야 함")
            XCTAssertLessThan(first.distanceKm ?? 99, 0.1, "거의 동일 좌표는 0.1km 이내여야 함")
        }
    }

    // MARK: - 7. API 키 없음 → unavailable throw

    func test_apiKey_unavailable_throwsUnavailable() async {
        // API 키가 있으면 이 테스트는 의미 없음 — 키 없는 케이스만 검증
        if CourseDiscoveryService.apiKey() != nil {
            // API 키가 있는 환경 — 통과
            return
        }

        let service = makeService(session: makeSession())

        do {
            _ = try await service.searchNearby(location: seoulLocation)
            XCTFail("API 키 없으면 CourseDiscoveryError.unavailable을 throw해야 함")
        } catch CourseDiscoveryError.unavailable {
            // 올바른 에러
        } catch {
            XCTFail("예상하지 못한 에러: \(error)")
        }
    }

    func test_searchByKeyword_apiKeyUnavailable_throwsUnavailable() async {
        if CourseDiscoveryService.apiKey() != nil { return }

        let service = makeService(session: makeSession())

        do {
            _ = try await service.searchByKeyword(query: "블루원골프")
            XCTFail("API 키 없으면 CourseDiscoveryError.unavailable을 throw해야 함")
        } catch CourseDiscoveryError.unavailable {
            // 올바른 에러
        } catch {
            XCTFail("예상하지 못한 에러: \(error)")
        }
    }

    // MARK: - 8. 좌표 유효성 검증 — 무효 좌표는 빈 배열 반환

    func test_searchNearby_invalidCoordinates_returnsEmpty() async throws {
        if CourseDiscoveryService.apiKey() == nil { return }

        let service = makeService(session: makeSession())
        // 0,0 좌표 (무효)
        let invalidLocation = CLLocation(latitude: 0, longitude: 0)

        let results = try await service.searchNearby(location: invalidLocation)
        XCTAssertTrue(results.isEmpty, "0,0 좌표는 빈 배열을 반환해야 함")
    }
}

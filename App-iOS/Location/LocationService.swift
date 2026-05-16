import Foundation
import CoreLocation
import Shared

// MARK: - LocationService
// F1 자동 골프장 매칭 + F3 GPS 감지를 위한 CoreLocation 래퍼 (01-SPEC §F1, §F3)
// CLLocationManagerDelegate는 메인 스레드에서 콜백되므로 @MainActor 클래스로 구현.
// one-shot 위치 획득 패턴: continuation으로 async/await 브리지.

@MainActor
public final class LocationService: NSObject {

    // MARK: Shared

    public static let shared = LocationService()

    // MARK: Private state

    private let manager = CLLocationManager()
    private var authContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?

    // MARK: Init

    override private init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    // MARK: Public API

    /// 현재 위치 권한 상태 반환
    public var authorizationStatus: CLAuthorizationStatus {
        manager.authorizationStatus
    }

    /// 위치 권한 요청. 이미 결정된 경우 즉시 현재 상태 반환.
    public func requestAuthorization() async -> CLAuthorizationStatus {
        let current = manager.authorizationStatus
        guard current == .notDetermined else {
            AppLogger.location.debug("위치 권한 이미 결정됨: \(current.rawValue)")
            return current
        }

        let result = await withCheckedContinuation { continuation in
            authContinuation = continuation
            manager.requestWhenInUseAuthorization()
        }
        AppLogger.location.info("위치 권한 요청 결과: \(result.rawValue)")
        return result
    }

    /// 현재 위치를 한 번 획득한다.
    /// - 권한 없으면 nil 반환 (시뮬레이터 fallback 포함)
    /// - 5초 타임아웃 후 nil 반환
    public func currentLocation() async -> CLLocation? {
        let status = manager.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            AppLogger.location.warning("위치 권한 없음 — 현재 위치 획득 불가")
            return nil
        }

        // 캐시된 최근 위치가 10초 이내면 그대로 반환
        if let cached = manager.location,
           abs(cached.timestamp.timeIntervalSinceNow) < 10 {
            AppLogger.location.debug("캐시된 위치 반환: \(cached.coordinate.latitude, privacy: .private), \(cached.coordinate.longitude, privacy: .private)")
            return cached
        }

        let result = await withCheckedContinuation { continuation in
            locationContinuation = continuation
            manager.requestLocation()

            // 5초 타임아웃
            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                // continuation이 아직 남아있으면 nil로 완료
                if let cont = self.locationContinuation {
                    self.locationContinuation = nil
                    self.manager.stopUpdatingLocation()
                    AppLogger.location.warning("위치 획득 타임아웃 (5초)")
                    cont.resume(returning: nil)
                }
            }
        }

        if let loc = result {
            AppLogger.location.info("위치 획득 성공: \(loc.coordinate.latitude, privacy: .private), \(loc.coordinate.longitude, privacy: .private)")
        } else {
            AppLogger.location.error("위치 획득 실패")
        }
        return result
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {

    /// iOS 14+ 권한 변경 콜백. 옛 didChangeAuthorization은 deprecated이며
    /// requestWhenInUseAuthorization 직후 다이얼로그 띄우기 전에 .notDetermined로
    /// 즉시 발화되는 경우가 있어 continuation 조기 해결 버그를 유발한다.
    /// 여기서는 status가 .notDetermined가 아닐 때(즉 사용자가 응답했을 때)만 resume.
    nonisolated public func locationManagerDidChangeAuthorization(
        _ manager: CLLocationManager
    ) {
        let status = manager.authorizationStatus
        Task { @MainActor [weak self] in
            guard let self else { return }
            // 사용자 응답 전 .notDetermined 발화는 무시 (다이얼로그 표시 대기 중)
            guard status != .notDetermined else { return }
            if let cont = self.authContinuation {
                self.authContinuation = nil
                cont.resume(returning: status)
            }
        }
    }

    nonisolated public func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let location = locations.last else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let cont = self.locationContinuation {
                self.locationContinuation = nil
                cont.resume(returning: location)
            }
        }
    }

    nonisolated public func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let cont = self.locationContinuation {
                self.locationContinuation = nil
                cont.resume(returning: nil)
            }
        }
    }
}

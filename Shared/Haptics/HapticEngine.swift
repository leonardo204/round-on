import Foundation

// MARK: - HapticEngine
// 13-HAPTICS_AND_MOTION §3 F1~F14 매핑 구현
// 플랫폼 분기: #if os(watchOS) → WKInterfaceDevice, #if os(iOS) → UIKit generators

#if os(watchOS)
import WatchKit
#elseif os(iOS)
import UIKit
#endif

public actor HapticEngine {

    // MARK: - Shared instance

    public static let shared = HapticEngine()

    private init() {}

    // MARK: - Event enum (13종)

    public enum Event: Sendable {
        /// F4 카운터 +1 (탭 또는 Crown 시계방향)
        case shotIncrement
        /// F4 카운터 -1 (수정)
        case shotDecrement
        /// F4 OB +2 (강한 경고)
        case penaltyOB
        /// F4 해저드 +1
        case penaltyHazard
        /// F4 OK / 컨시드 +1
        case penaltyOK
        /// F4 수동 홀 전환 (스와이프)
        case holeManualChange
        /// F2 동반자 전환
        case playerSwitch
        /// F3 GPS 골프장+서브코스 매칭 완료
        case gpsMatchComplete
        /// F5 라운드 시작
        case roundStart
        /// F5 라운드 종료
        case roundEnd
        /// F9 viewer 공유 완료
        case shareSuccess
        /// F9 공유 실패
        case shareError
        /// F11 사진 첨부
        case photoAttach
        /// F12 viewer 만료 안내
        case viewerExpired
        /// 권한 거부 / 에러
        case permissionDenied
    }

    // MARK: - Play

    /// 이벤트에 맞는 햅틱 발화
    public func play(_ event: Event) {
        // Reduce Motion + 무음 모드 조합은 시스템이 자동 처리 (13-HAPTICS §4)
        // 햅틱은 Reduce Motion과 무관하게 발화 (13-HAPTICS §7)
        performHaptic(for: event)
    }

    // MARK: - Platform implementation

    private func performHaptic(for event: Event) {
        #if os(watchOS)
        playWatch(event)
        #elseif os(iOS)
        playiOS(event)
        #endif
    }

    // MARK: watchOS

    #if os(watchOS)
    private func playWatch(_ event: Event) {
        let device = WKInterfaceDevice.current()
        switch event {
        case .shotIncrement:
            // F4 +1: .click — 가벼운 클릭감
            device.play(.click)

        case .shotDecrement:
            // F4 -1: .click 단일 (스펙 §9 "다른 톤" 미지원 → click 단일)
            device.play(.click)

        case .penaltyOB:
            // F4 OB: .directionUp — 강한 경고
            device.play(.directionUp)

        case .penaltyHazard:
            // F4 해저드: .click × 2 (100ms 간격)
            device.play(.click)
            Task {
                try? await Task.sleep(nanoseconds: 100_000_000)
                WKInterfaceDevice.current().play(.click)
            }

        case .penaltyOK:
            // F4 OK: .success
            device.play(.success)

        case .holeManualChange:
            // F4 수동 홀 전환: .directionUp (다음) 또는 .directionDown (이전)
            // 방향 정보가 없으므로 기본 .directionUp 사용
            device.play(.directionUp)

        case .playerSwitch:
            // F2 동반자 전환: .click × 2
            device.play(.click)
            Task {
                try? await Task.sleep(nanoseconds: 100_000_000)
                WKInterfaceDevice.current().play(.click)
            }

        case .gpsMatchComplete:
            // F3 GPS 매칭 완료: .start + 시각 토스트 (토스트는 UI 레이어)
            device.play(.start)

        case .roundStart:
            // F5 라운드 시작
            device.play(.start)

        case .roundEnd:
            // F5 라운드 종료: .stop — "길게"
            device.play(.stop)

        case .shareSuccess:
            // F9 공유 완료: Watch 미참여 — 무시
            break

        case .shareError:
            // 에러: Watch 미참여 — 무시
            break

        case .photoAttach:
            // F11 사진 첨부: Watch 미참여 — 무시
            break

        case .viewerExpired:
            // F12 viewer 만료: Watch 미참여 — 무시
            break

        case .permissionDenied:
            // 권한 거부: .failure
            device.play(.failure)
        }
    }
    #endif

    // MARK: iOS

    #if os(iOS)
    private func playiOS(_ event: Event) {
        switch event {
        case .shotIncrement:
            // F4 +1: .light (Impact)
            impact(.light)

        case .shotDecrement:
            // F4 -1: .light (Impact)
            impact(.light)

        case .penaltyOB:
            // F4 OB: .warning (Notification)
            notification(.warning)

        case .penaltyHazard:
            // F4 해저드: .medium (Impact) — 80ms 간격 × 2
            impact(.medium)
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 80_000_000)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }

        case .penaltyOK:
            // F4 OK: .success (Notification)
            notification(.success)

        case .holeManualChange:
            // F4 수동 홀 전환: .light × 2 (80ms 간격)
            impact(.light)
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 80_000_000)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }

        case .playerSwitch:
            // F2 동반자 전환: .selection (Selection)
            Task { @MainActor in
                let gen = UISelectionFeedbackGenerator()
                gen.prepare()
                gen.selectionChanged()
            }

        case .gpsMatchComplete:
            // F3 GPS 매칭 완료: .success (Notification)
            notification(.success)

        case .roundStart:
            // F5 라운드 시작: .success (Notification)
            notification(.success)

        case .roundEnd:
            // F5 라운드 종료: .success (Notification)
            notification(.success)

        case .shareSuccess:
            // F9 공유 완료: .success (Notification)
            notification(.success)

        case .shareError:
            // 공유 실패: .error (Notification)
            notification(.error)

        case .photoAttach:
            // F11 사진 첨부: .light (Impact)
            impact(.light)

        case .viewerExpired:
            // F12 viewer 만료: .warning (Notification)
            notification(.warning)

        case .permissionDenied:
            // 권한 거부: .error (Notification)
            notification(.error)
        }
    }

    // MARK: iOS helpers

    private func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        Task { @MainActor in
            let gen = UIImpactFeedbackGenerator(style: style)
            gen.prepare()
            gen.impactOccurred()
        }
    }

    private func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        Task { @MainActor in
            let gen = UINotificationFeedbackGenerator()
            gen.prepare()
            gen.notificationOccurred(type)
        }
    }
    #endif
}

import XCTest
@testable import Shared

// MARK: - SyncCoordinatorStressTests
// Task E: SyncCoordinator 보강 테스트
// - 동일 eventId 1000번 연속 → 1회만 적용
// - 다른 deviceId의 ShotEvent 처리
// - HoleChange / PlayerSwitch 시퀀스 검증

final class SyncCoordinatorStressTests: XCTestCase {

    // MARK: - 동일 eventId 1000번 → 1회만 적용

    func test_dedupe_sameEventId_1000times_appliedOnce() async throws {
        let coordinator = SyncCoordinator.shared
        await coordinator.resetForTesting()

        let eventId = UUID()
        let event = ShotEvent(
            eventId: eventId,
            type: .increment,
            playerId: UUID(),
            holeNumber: 1,
            deviceId: "iPhone",
            perDeviceCounter: 1
        )

        // 1000번 반복 전송
        for _ in 0..<1000 {
            await coordinator.receive(shotEvent: event)
        }

        let count = await coordinator.appliedEventCount
        XCTAssertEqual(count, 1, "동일 eventId 1000번 → 1회만 적용되어야 해요")
    }

    // MARK: - 다른 deviceId의 ShotEvent (iPhone + Watch 동시)

    func test_differentDevice_shotEvents_bothApplied() async throws {
        let coordinator = SyncCoordinator.shared
        await coordinator.resetForTesting()

        let pid = UUID()
        let e1 = ShotEvent(eventId: UUID(), type: .increment, playerId: pid, holeNumber: 1, deviceId: "iPhone", perDeviceCounter: 1)
        let e2 = ShotEvent(eventId: UUID(), type: .increment, playerId: pid, holeNumber: 1, deviceId: "Watch", perDeviceCounter: 1)

        await coordinator.receive(shotEvent: e1)
        await coordinator.receive(shotEvent: e2)

        let count = await coordinator.appliedEventCount
        XCTAssertEqual(count, 2, "서로 다른 deviceId의 이벤트는 각각 적용되어야 해요")
    }

    // MARK: - 여러 플레이어 이벤트 모두 적용

    func test_multiplePlayer_events_allApplied() async throws {
        let coordinator = SyncCoordinator.shared
        await coordinator.resetForTesting()

        let players = (0..<4).map { _ in UUID() }
        var events: [ShotEvent] = []
        for (idx, pid) in players.enumerated() {
            let e = ShotEvent(
                eventId: UUID(),
                type: .increment,
                playerId: pid,
                holeNumber: idx + 1,
                deviceId: "iPhone",
                perDeviceCounter: UInt64(idx + 1)
            )
            events.append(e)
        }

        for e in events {
            await coordinator.receive(shotEvent: e)
        }

        let count = await coordinator.appliedEventCount
        XCTAssertEqual(count, 4, "4명 각자 이벤트 4개 모두 적용되어야 해요")
    }

    // MARK: - OB/Hazard/OK 타입별 countDelta 시퀀스

    func test_shotEvent_allTypes_countDelta_sequence() {
        let pid = UUID()
        // ShotType enum 사용 (WCMessages.swift 정의)
        let types: [(ShotType, Int)] = [
            (.increment, 1),
            (.decrement, -1),
            (.ob, 2),
            (.hazard, 1),
            (.ok, 1),
        ]

        for (type, expectedDelta) in types {
            let e = ShotEvent(eventId: UUID(), type: type, playerId: pid, holeNumber: 1, deviceId: "iPhone", perDeviceCounter: 1)
            XCTAssertEqual(e.countDelta, expectedDelta, "\(type) countDelta는 \(expectedDelta)여야 해요")
        }
    }

    // MARK: - HoleChange Codable roundtrip + trigger 검증

    func test_holeChange_manualSwipe_trigger_codable() throws {
        // ChangeTrigger enum 사용 (WCMessages.swift 정의, manualSwipe만 존재)
        let original = HoleChange(
            newHoleNumber: 5,
            trigger: .manualSwipe,
            subCourseName: nil,
            timestamp: .now,
            deviceId: "Watch",
            perDeviceCounter: 10
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(HoleChange.self, from: data)
        XCTAssertEqual(decoded.trigger, .manualSwipe, "manualSwipe trigger roundtrip 일치해야 해요")
        XCTAssertEqual(decoded.newHoleNumber, 5)
    }

    // MARK: - 혼합 eventId 시퀀스: dedupe 정확도

    func test_mixed_eventIds_dedupeAccuracy() async throws {
        let coordinator = SyncCoordinator.shared
        await coordinator.resetForTesting()

        let uniqueIds = (0..<10).map { _ in UUID() }
        let pid = UUID()

        // 각 eventId를 3번씩 전송 (총 30회) → 10개만 적용되어야 함
        for _ in 0..<3 {
            for eid in uniqueIds {
                let e = ShotEvent(eventId: eid, type: .increment, playerId: pid, holeNumber: 1, deviceId: "iPhone", perDeviceCounter: 1)
                await coordinator.receive(shotEvent: e)
            }
        }

        let count = await coordinator.appliedEventCount
        XCTAssertEqual(count, 10, "10개 고유 eventId → 10개만 적용되어야 해요")
    }
}

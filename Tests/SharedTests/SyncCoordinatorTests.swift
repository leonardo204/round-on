import XCTest
@testable import Shared

// MARK: - SyncCoordinatorTests
// A3: delta-merge dedupe (동일 eventId 두 번 적용 시 1회만) + WCMessages Codable round-trip
// 22-STATE_MANAGEMENT §6 SyncCoordinator 검증

final class SyncCoordinatorTests: XCTestCase {

    // MARK: - Dedupe 테스트

    func test_dedupe_sameEventId_appliedOnce() async throws {
        let coordinator = SyncCoordinator.shared
        await coordinator.resetForTesting()

        // 카운터 (delegate 없이 내부 dedupe만 검증)
        let eventId = UUID()
        let event = ShotEvent(
            eventId: eventId,
            type: .increment,
            playerId: UUID(),
            holeNumber: 1,
            deviceId: "iPhone",
            perDeviceCounter: 1
        )

        // 동일 eventId 두 번 처리
        await coordinator.receive(shotEvent: event)
        await coordinator.receive(shotEvent: event)

        // appliedEventIds에 1번만 등록되어야 함
        let count = await coordinator.appliedEventCount
        XCTAssertEqual(count, 1, "동일 eventId는 1회만 처리되어야 해요")
    }

    func test_dedupe_differentEventId_appliedBoth() async throws {
        let coordinator = SyncCoordinator.shared
        await coordinator.resetForTesting()

        let e1 = ShotEvent(eventId: UUID(), type: .increment, playerId: UUID(), holeNumber: 1, deviceId: "iPhone", perDeviceCounter: 1)
        let e2 = ShotEvent(eventId: UUID(), type: .decrement, playerId: UUID(), holeNumber: 2, deviceId: "Watch", perDeviceCounter: 2)

        await coordinator.receive(shotEvent: e1)
        await coordinator.receive(shotEvent: e2)

        let count = await coordinator.appliedEventCount
        XCTAssertEqual(count, 2, "서로 다른 eventId는 각각 적용되어야 해요")
    }

    func test_dedupe_reset_clears() async throws {
        let coordinator = SyncCoordinator.shared
        await coordinator.resetForTesting()

        let event = ShotEvent(eventId: UUID(), type: .ob, playerId: UUID(), holeNumber: 3, deviceId: "iPhone", perDeviceCounter: 10)
        await coordinator.receive(shotEvent: event)

        var count = await coordinator.appliedEventCount
        XCTAssertEqual(count, 1)

        await coordinator.resetForTesting()
        count = await coordinator.appliedEventCount
        XCTAssertEqual(count, 0, "resetForTesting 후 카운트는 0이어야 해요")
    }

    // MARK: - WCMessages Codable Round-Trip 테스트

    func test_shotEvent_codable_roundTrip() throws {
        let playerId = UUID()
        let eventId = UUID()
        let original = ShotEvent(
            eventId: eventId,
            type: .hazard,
            playerId: playerId,
            holeNumber: 7,
            timestamp: Date(timeIntervalSince1970: 1_000_000),
            deviceId: "Watch",
            perDeviceCounter: 42
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ShotEvent.self, from: encoded)

        XCTAssertEqual(decoded.eventId, original.eventId)
        XCTAssertEqual(decoded.type, original.type)
        XCTAssertEqual(decoded.playerId, original.playerId)
        XCTAssertEqual(decoded.holeNumber, original.holeNumber)
        XCTAssertEqual(decoded.deviceId, original.deviceId)
        XCTAssertEqual(decoded.perDeviceCounter, original.perDeviceCounter)
    }

    func test_holeChange_codable_roundTrip() throws {
        let original = HoleChange(
            newHoleNumber: 5,
            trigger: .manualSwipe,
            subCourseName: "동코스",
            timestamp: Date(timeIntervalSince1970: 2_000_000),
            deviceId: "iPhone",
            perDeviceCounter: 10
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(HoleChange.self, from: encoded)

        XCTAssertEqual(decoded.newHoleNumber, original.newHoleNumber)
        XCTAssertEqual(decoded.trigger, original.trigger)
        XCTAssertEqual(decoded.subCourseName, original.subCourseName)
        XCTAssertEqual(decoded.deviceId, original.deviceId)
        XCTAssertEqual(decoded.perDeviceCounter, original.perDeviceCounter)
    }

    func test_playerSwitch_codable_roundTrip() throws {
        let original = PlayerSwitch(
            newPlayerIndex: 2,
            timestamp: Date(timeIntervalSince1970: 3_000_000),
            deviceId: "Watch",
            perDeviceCounter: 5
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PlayerSwitch.self, from: encoded)

        XCTAssertEqual(decoded.newPlayerIndex, original.newPlayerIndex)
        XCTAssertEqual(decoded.deviceId, original.deviceId)
        XCTAssertEqual(decoded.perDeviceCounter, original.perDeviceCounter)
    }

    func test_roundSnapshot_codable_roundTrip() throws {
        let roundId = UUID()
        let players = [
            PlayerSnapshot(id: UUID(), name: "나", isOwner: true, order: 0),
            PlayerSnapshot(id: UUID(), name: "동반자", isOwner: false, order: 1),
        ]
        let original = RoundSnapshot(
            roundId: roundId,
            courseId: "course-001",
            players: players,
            activeHoleNumber: 3,
            activePlayerIndex: 1,
            parArray: [4, 3, 5, 4, 4, 4, 3, 5, 4, 4, 4, 3, 5, 4, 4, 4, 3, 4]
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RoundSnapshot.self, from: encoded)

        XCTAssertEqual(decoded.roundId, original.roundId)
        XCTAssertEqual(decoded.courseId, original.courseId)
        XCTAssertEqual(decoded.players.count, original.players.count)
        XCTAssertEqual(decoded.players[0].name, original.players[0].name)
        XCTAssertEqual(decoded.players[1].isOwner, original.players[1].isOwner)
        XCTAssertEqual(decoded.activeHoleNumber, original.activeHoleNumber)
        XCTAssertEqual(decoded.activePlayerIndex, original.activePlayerIndex)
        XCTAssertEqual(decoded.parArray, original.parArray)
    }

    // MARK: - ShotEvent countDelta 테스트

    func test_shotEvent_countDelta() {
        let pid = UUID()
        XCTAssertEqual(ShotEvent(eventId: UUID(), type: .increment, playerId: pid, holeNumber: 1, deviceId: "iPhone", perDeviceCounter: 1).countDelta, 1)
        XCTAssertEqual(ShotEvent(eventId: UUID(), type: .decrement, playerId: pid, holeNumber: 1, deviceId: "iPhone", perDeviceCounter: 2).countDelta, -1)
        XCTAssertEqual(ShotEvent(eventId: UUID(), type: .ob, playerId: pid, holeNumber: 1, deviceId: "iPhone", perDeviceCounter: 3).countDelta, 2)
        XCTAssertEqual(ShotEvent(eventId: UUID(), type: .hazard, playerId: pid, holeNumber: 1, deviceId: "iPhone", perDeviceCounter: 4).countDelta, 1)
        XCTAssertEqual(ShotEvent(eventId: UUID(), type: .ok, playerId: pid, holeNumber: 1, deviceId: "iPhone", perDeviceCounter: 5).countDelta, 1)
    }

    // MARK: - obDelta / hazardDelta 테스트

    func test_shotEvent_obDelta_hazardDelta() {
        let pid = UUID()
        let obEvent = ShotEvent(eventId: UUID(), type: .ob, playerId: pid, holeNumber: 1, deviceId: "iPhone", perDeviceCounter: 1)
        XCTAssertEqual(obEvent.obDelta, 1)
        XCTAssertEqual(obEvent.hazardDelta, 0)

        let hazardEvent = ShotEvent(eventId: UUID(), type: .hazard, playerId: pid, holeNumber: 1, deviceId: "iPhone", perDeviceCounter: 2)
        XCTAssertEqual(hazardEvent.obDelta, 0)
        XCTAssertEqual(hazardEvent.hazardDelta, 1)

        let incrementEvent = ShotEvent(eventId: UUID(), type: .increment, playerId: pid, holeNumber: 1, deviceId: "iPhone", perDeviceCounter: 3)
        XCTAssertEqual(incrementEvent.obDelta, 0)
        XCTAssertEqual(incrementEvent.hazardDelta, 0)
    }
}

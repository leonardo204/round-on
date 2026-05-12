import XCTest
import SwiftData
@testable import Shared

final class SwiftDataModelTests: XCTestCase {
    @MainActor
    func test_Round_roundTrip() throws {
        let schema = Schema([Round.self, Player.self, HoleScore.self, RoundPhoto.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        let ctx = container.mainContext

        let round = Round(courseId: "test", courseName: "테스트 골프장")
        ctx.insert(round)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<Round>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.courseName, "테스트 골프장")
    }

    @MainActor
    func test_HoleScore_ScoreEntry_roundTrip() throws {
        let schema = Schema([Round.self, Player.self, HoleScore.self, RoundPhoto.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        let ctx = container.mainContext

        let p1 = UUID()
        let p2 = UUID()
        let hole = HoleScore(
            holeNumber: 1,
            par: 4,
            counts: [ScoreEntry(playerId: p1, value: 5), ScoreEntry(playerId: p2, value: 4)],
            obCount: [ScoreEntry(playerId: p1, value: 1)],
            hazardCount: []
        )
        ctx.insert(hole)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<HoleScore>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.count(for: p1), 5)
        XCTAssertEqual(fetched.first?.count(for: p2), 4)
        XCTAssertEqual(fetched.first?.ob(for: p1), 1)
        XCTAssertEqual(fetched.first?.hazard(for: p1), 0)
    }
}

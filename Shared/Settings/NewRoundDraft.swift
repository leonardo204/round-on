import Foundation

// MARK: - NewRoundDraft
// NewRoundView 입력 중인 임시 상태 (앱 background 후 복귀 시 복원용).
// UserDefaults 저장. 실제 라운드 시작 또는 사용자 명시 폐기 시 clear.

public struct NewRoundDraft: Codable, Sendable, Equatable {
    public let courseId: String         // 빈 문자열이면 골프장 미선택
    public let courseName: String
    public let frontSubCourseName: String?
    public let backSubCourseName: String?
    public let isBackTentative: Bool     // 후반 코스 "추후 결정" (잠정 배정) 여부
    public let holesCount: Int          // 9 또는 18
    public let playerNames: [String]    // 4개 슬롯 ["나", "동반자1", ...]
    public let playerCount: Int         // 1...4
    public let updatedAt: Date

    public init(
        courseId: String,
        courseName: String,
        frontSubCourseName: String?,
        backSubCourseName: String?,
        isBackTentative: Bool = false,
        holesCount: Int,
        playerNames: [String],
        playerCount: Int,
        updatedAt: Date = .now
    ) {
        self.courseId = courseId
        self.courseName = courseName
        self.frontSubCourseName = frontSubCourseName
        self.backSubCourseName = backSubCourseName
        self.isBackTentative = isBackTentative
        self.holesCount = holesCount
        self.playerNames = playerNames
        self.playerCount = playerCount
        self.updatedAt = updatedAt
    }

    /// 복원할 만한 의미 있는 입력이 있는지 — 골프장명 또는 동반자 1명 이상 추가된 경우
    public var hasMeaningfulInput: Bool {
        if !courseName.isEmpty { return true }
        if playerCount > 1 { return true }
        let extraPlayer = playerNames.dropFirst().contains { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return extraPlayer
    }
}

// MARK: - Store

public enum NewRoundDraftStore {

    private static let key = "newRound.draft"

    /// 저장 — 의미 없는 입력(빈 상태)이면 자동 clear
    public static func save(_ draft: NewRoundDraft) {
        guard draft.hasMeaningfulInput else {
            clear()
            return
        }
        guard let data = try? JSONEncoder().encode(draft) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    public static func load() -> NewRoundDraft? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(NewRoundDraft.self, from: data)
    }

    public static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    public static var hasDraft: Bool {
        load()?.hasMeaningfulInput == true
    }
}

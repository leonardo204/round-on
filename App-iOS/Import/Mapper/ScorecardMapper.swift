import Foundation
import SwiftData
import Shared

// MARK: - ScorecardImportDraft

/// OCR 결과를 UI가 편집 가능한 드래프트 형태로 변환한 중간 모델.
/// PAR 행은 절대 타수, 선수 행은 PAR 대비 상대값(카드 표기 그대로).
public struct ScorecardImportDraft: Identifiable {
    public var id: UUID = UUID()
    public var clubName: String?
    /// DB 검색 또는 카카오 검색으로 선택한 골프장 ID (옵션)
    public var courseId: String?
    /// 클럽명 선택 출처 — DB 매칭·DB 선택·카카오 선택·직접 입력 구분
    public var clubSource: ClubSource = .autoMatched
    public var dateText: String?
    public var teeOffText: String?
    public var resolvedDate: Date
    public var sections: [ImportSection]
    public var players: [ImportPlayer]

    public enum ClubSource: Equatable {
        case autoMatched   // OCR 자동 매칭
        case dbSelected    // DB 검색으로 직접 선택
        case kakaoSelected // 카카오 검색으로 선택
        case manual        // 직접 입력
    }

    public init(
        id: UUID = UUID(),
        clubName: String? = nil,
        courseId: String? = nil,
        clubSource: ClubSource = .autoMatched,
        dateText: String? = nil,
        teeOffText: String? = nil,
        resolvedDate: Date = .now,
        sections: [ImportSection] = [],
        players: [ImportPlayer] = []
    ) {
        self.id = id
        self.clubName = clubName
        self.courseId = courseId
        self.clubSource = clubSource
        self.dateText = dateText
        self.teeOffText = teeOffText
        self.resolvedDate = resolvedDate
        self.sections = sections
        self.players = players
    }
}

// MARK: - ImportSection

/// 9홀 섹션 (전반/후반). parRow는 절대 타수.
public struct ImportSection: Identifiable {
    public var id: UUID = UUID()
    public var name: String
    /// 이 섹션이 전체 18홀 기준 몇 번째 홀에서 시작하는지 (0 또는 9)
    public var holeOffset: Int
    /// 절대 타수 9개 (nil = OCR 미인식)
    public var parRow: [Int?]

    public init(id: UUID = UUID(), name: String, holeOffset: Int, parRow: [Int?]) {
        self.id = id
        self.name = name
        self.holeOffset = holeOffset
        self.parRow = parRow
    }

    public var sectionPar: Int {
        parRow.compactMap { $0 }.reduce(0, +)
    }
}

// MARK: - ImportPlayer

/// 선수 한 명의 편집 가능한 스코어 드래프트.
/// scores[sectionId][holeIndex] = PAR 대비 상대값 (Int?, nil = 미인식)
public struct ImportPlayer: Identifiable {
    public var id: UUID = UUID()
    public var rawLabel: String
    public var isOwner: Bool
    public var matchedPlayerName: String?
    /// sectionId → 9개 상대값 배열 (PAR 대비 가감)
    public var scores: [UUID: [Int?]]

    public init(
        id: UUID = UUID(),
        rawLabel: String,
        isOwner: Bool = false,
        matchedPlayerName: String? = nil,
        scores: [UUID: [Int?]] = [:]
    ) {
        self.id = id
        self.rawLabel = rawLabel
        self.isOwner = isOwner
        self.matchedPlayerName = matchedPlayerName
        self.scores = scores
    }

    public var displayName: String {
        matchedPlayerName ?? rawLabel
    }

    /// 섹션별 상대 합계 (nil 셀 제외)
    public func relativeSum(for sectionId: UUID) -> Int {
        scores[sectionId]?.compactMap { $0 }.reduce(0, +) ?? 0
    }

    /// 섹션의 절대 타수 합 (nil 셀은 par로 대체)
    public func absoluteSum(for section: ImportSection) -> Int {
        let sectionScores = scores[section.id] ?? Array(repeating: nil, count: 9)
        return sectionScores.enumerated().reduce(0) { acc, item in
            let (holeIdx, rel) = item
            let par: Int = section.parRow.indices.contains(holeIdx) ? (section.parRow[holeIdx] ?? 4) : 4
            let absVal: Int = rel.map { ScorecardMapper.absoluteStrokes(par: par, relative: $0) } ?? par
            return acc + absVal
        }
    }

    /// 전체 섹션 상대 합계
    public func totalRelative(sections: [ImportSection]) -> Int {
        sections.reduce(0) { $0 + relativeSum(for: $1.id) }
    }

    /// 전체 섹션 절대 타수 합
    public func totalAbsolute(sections: [ImportSection]) -> Int {
        sections.reduce(0) { $0 + absoluteSum(for: $1) }
    }
}

// MARK: - ScorecardMapper

public enum ScorecardMapper {

    // MARK: 핵심 변환 함수

    /// PAR 대비 상대값 → 절대 타수
    public static func absoluteStrokes(par: Int, relative: Int) -> Int {
        par + relative
    }

    // MARK: OCR Scorecard → ScorecardImportDraft

    public static func makeDraft(
        from scorecard: Scorecard,
        ownerName: String? = nil
    ) throws -> ScorecardImportDraft {
        let resolvedDate = parseDate(scorecard.dateText)

        // 섹션 변환 (최대 2개: 전반/후반)
        var sections: [ImportSection] = []
        // OCR 출력 순서를 보존하는 배열 사용 (Dictionary 순회는 순서 무보장 → owner 비결정성 방지)
        var playerEntries: [(label: String, scoresBySection: [UUID: [Int?]])] = []

        for (tableIndex, table) in scorecard.tables.prefix(2).enumerated() {
            let holeOffset = tableIndex * 9
            let parRow = extractParRow(from: table)
            let sectionId = UUID()
            let section = ImportSection(
                id: sectionId,
                name: table.sectionName,
                holeOffset: holeOffset,
                parRow: parRow
            )
            sections.append(section)

            // 선수 행 추출 (OCR 등장 순서 보존)
            // join 조건에 "이 섹션 값이 아직 비어있음"을 포함한다.
            // 골프장이 인쇄한 마스킹 라벨은 동성 동반자끼리 같은 문자열("이**")이 되므로
            // label만으로 join하면 같은 섹션의 다른 사람을 덮어쓴다.
            // 섹션 값이 비어있는 엔트리에만 join → 전반/후반 결합은 유지, 섹션 내 충돌은 방지.
            for row in table.rows where row.kind == .player {
                let label = row.label
                let values = extractPlayerRow(from: row, expectedCount: 9)
                if let idx = playerEntries.firstIndex(where: {
                    $0.label == label && $0.scoresBySection[sectionId] == nil
                }) {
                    playerEntries[idx].scoresBySection[sectionId] = values
                } else {
                    playerEntries.append((label: label, scoresBySection: [sectionId: values]))
                }
            }
        }

        // 선수 배열 구성 — owner 선택: ownerName 매칭 → 없으면 첫 번째 entry (사전순 X)
        // 동성 마스킹으로 같은 라벨이 여러 명일 수 있으므로 라벨이 아닌 인덱스로 owner를 특정한다.
        // (라벨 비교 시 "이**" 2명이 모두 owner가 된다)
        var players: [ImportPlayer] = []
        let ownerIndex: Int?

        if let ownerName {
            // ownerName 매칭 우선순위:
            // 1) 정확 일치
            // 2) 라벨에 마스킹("*") 포함 → ownerName 첫 글자만 prefix 매칭
            // 3) 라벨 비마스킹 → ownerName 2글자 prefix 매칭
            // 4) 매칭 없으면 첫 번째 entry로 fallback
            let matched = playerEntries.firstIndex {
                let label = $0.label
                if label == ownerName { return true }
                if label.contains("*") {
                    return label.hasPrefix(String(ownerName.prefix(1)))
                } else {
                    return label.hasPrefix(String(ownerName.prefix(2)))
                }
            }
            ownerIndex = matched ?? (playerEntries.isEmpty ? nil : 0)
        } else {
            // 첫 번째 entry = owner (OCR 카드 순서 기준)
            ownerIndex = playerEntries.isEmpty ? nil : 0
        }

        for (index, entry) in playerEntries.enumerated() {
            let player = ImportPlayer(
                rawLabel: entry.label,
                isOwner: (index == ownerIndex),
                matchedPlayerName: nil,
                scores: entry.scoresBySection
            )
            players.append(player)
        }

        // owner가 없으면 첫 번째를 owner로 지정 (안전망)
        if !players.isEmpty && !players.contains(where: { $0.isOwner }) {
            players[0].isOwner = true
        }

        return ScorecardImportDraft(
            clubName: scorecard.clubName,
            dateText: scorecard.dateText,
            teeOffText: scorecard.teeOffText,
            resolvedDate: resolvedDate,
            sections: sections,
            players: players
        )
    }

    // MARK: ScorecardImportDraft → Round (SwiftData)

    @MainActor
    public static func makeRound(
        from draft: ScorecardImportDraft,
        modelContext: ModelContext
    ) throws -> Round {
        let round = Round(
            date: draft.resolvedDate,
            courseId: draft.courseId ?? "",
            courseName: draft.clubName ?? "알 수 없는 클럽",
            frontCourseName: draft.sections[safe: 0]?.name,
            backCourseName: draft.sections[safe: 1]?.name,
            isFinished: true,
            startedAt: draft.resolvedDate,
            finishedAt: draft.resolvedDate
        )
        round.isImported = true

        // CloudKit inverse 관계 안정화: Round를 먼저 insert한 뒤 관계 설정
        modelContext.insert(round)

        // 선수 생성 및 연결
        var playerModels: [UUID: Player] = [:]
        for (order, importPlayer) in draft.players.enumerated() {
            let player = Player(
                name: importPlayer.displayName,
                isOwner: importPlayer.isOwner,
                order: order
            )
            modelContext.insert(player)
            round.players = (round.players ?? []) + [player]
            playerModels[importPlayer.id] = player
        }

        // 홀 스코어 생성 (섹션 × 9홀 = 최대 18홀)
        for section in draft.sections {
            for holeIdx in 0..<9 {
                let holeNumber = section.holeOffset + holeIdx + 1
                let par: Int = section.parRow.indices.contains(holeIdx) ? (section.parRow[holeIdx] ?? 4) : 4

                var counts: [ScoreEntry] = []
                for importPlayer in draft.players {
                    guard let playerModel = playerModels[importPlayer.id] else { continue }
                    let scoreArr = importPlayer.scores[section.id] ?? []
                    let relative: Int? = scoreArr.indices.contains(holeIdx) ? scoreArr[holeIdx] : nil
                    let absStrokes: Int = relative.map { absoluteStrokes(par: par, relative: $0) } ?? par
                    counts.append(ScoreEntry(playerId: playerModel.id, value: absStrokes))
                }

                let holeScore = HoleScore(holeNumber: holeNumber, par: par, counts: counts)
                modelContext.insert(holeScore)
                round.holes = (round.holes ?? []) + [holeScore]
            }
        }

        try modelContext.save()
        return round
    }

    // MARK: Private helpers

    private static func extractParRow(from table: ScoreTable) -> [Int?] {
        guard let parRow = table.rows.first(where: { $0.kind == .par }) else {
            return Array(repeating: nil, count: 9)
        }
        // TOTAL 제외하고 앞 9개 값만 사용
        let holeValues = parRow.values.prefix(9).map { $0?.intValue }
        let padded = Array(holeValues) + Array(repeating: nil, count: max(0, 9 - holeValues.count))
        return padded
    }

    private static func extractPlayerRow(from row: ScoreRow, expectedCount: Int) -> [Int?] {
        let holeValues = row.values.prefix(expectedCount).map { $0?.intValue }
        let padded = Array(holeValues) + Array(repeating: nil, count: max(0, expectedCount - holeValues.count))
        return padded
    }

    private static func parseDate(_ dateText: String?) -> Date {
        guard let text = dateText else { return .now }
        // "2026/04/30" 형태 파싱 (KST 기준 — GeminiScorecardAdapter.resolveDateText와 타임존 통일)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return formatter.date(from: text) ?? .now
    }
}

// MARK: - Collection safe subscript

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

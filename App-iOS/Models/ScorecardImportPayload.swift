import Foundation
import SwiftUI
import Shared

// MARK: - ScorecardImportPayload
// OCR 결과를 사용자 검토/편집 가능한 폼 상태로 변환하는 모델

/// 단일 플레이어의 편집 가능 상태
struct ImportPlayer: Identifiable {
    var id = UUID()
    var name: String
    var scores: [Int]           // 18개 (9홀이면 9개)
    var isOwner: Bool

    /// 점수 합계 (사용자가 직접 편집 가능하도록 계산 표시용)
    var computedTotal: Int { scores.reduce(0, +) }
}

/// ScorecardImportView 에서 사용할 편집 가능 상태 모델
@Observable
class ScorecardImportPayload {

    // MARK: 편집 가능 필드

    var courseName: String = ""
    var courseId: String = ""           // CourseRepository 매칭 결과
    var date: Date = Date.now
    var teeOffTime: String = ""
    var frontCourseName: String = ""
    var backCourseName: String = ""
    var pars: [Int]                     // 9 또는 18개
    var players: [ImportPlayer]

    // MARK: UI 상태

    var matchedCourses: [GolfCourse] = []   // fuzzy 매칭 후보
    var isCourseConfirmed: Bool = false
    /// OCR 부분 인식 경고 — 편집 화면 상단 배너용
    var warnings: [ScorecardOCRWarning] = []

    // MARK: Init from OCR Result

    init(from ocr: ScorecardOCRResult) {
        self.warnings = ocr.warnings
        self.courseName = ocr.courseName ?? ""
        self.date = ocr.date ?? Date.now
        self.teeOffTime = ocr.teeOffTime ?? ""
        self.frontCourseName = ocr.frontCourseName ?? ""
        self.backCourseName = ocr.backCourseName ?? ""

        // pars 정규화: 9홀 단위로 유효한 값만, 나머지 4로 채움
        let rawPars = ocr.pars
        let holeCount = rawPars.count >= 18 ? 18 : 9
        var normalizedPars = rawPars.prefix(holeCount).map { max(3, min(5, $0)) }
        while normalizedPars.count < holeCount { normalizedPars.append(4) }
        self.pars = Array(normalizedPars)

        // 플레이어 변환
        self.players = ocr.players.map { ocrPlayer in
            var scores = ocrPlayer.scores
            // pars 길이에 맞게 점수 배열 크기 조정
            while scores.count < holeCount { scores.append(0) }
            scores = Array(scores.prefix(holeCount))
            return ImportPlayer(
                name: ocrPlayer.name,
                scores: scores,
                isOwner: ocrPlayer.isOwnerCandidate
            )
        }

        // owner가 없으면 첫 번째 플레이어를 owner로
        if !players.isEmpty && !players.contains(where: { $0.isOwner }) {
            players[0].isOwner = true
        }
    }

    // MARK: Convenience

    var holeCount: Int { pars.count }

    var isValid: Bool {
        !courseName.isEmpty && !players.isEmpty && players.contains(where: { $0.isOwner })
    }

    /// owner 플레이어 (저장 시 필수)
    var ownerPlayer: ImportPlayer? {
        players.first(where: { $0.isOwner })
    }

    /// 플레이어 추가
    func addPlayer() {
        let idx = players.count + 1
        players.append(ImportPlayer(
            name: "동반자\(idx)",
            scores: Array(repeating: 0, count: holeCount),
            isOwner: false
        ))
    }

    /// 플레이어 삭제
    func removePlayer(at offsets: IndexSet) {
        players.remove(atOffsets: offsets)
        // owner가 사라진 경우 첫 번째에게 owner 부여
        if !players.isEmpty && !players.contains(where: { $0.isOwner }) {
            players[0].isOwner = true
        }
    }

    /// owner 변경
    func setOwner(id: UUID) {
        for i in players.indices {
            players[i].isOwner = (players[i].id == id)
        }
    }
}

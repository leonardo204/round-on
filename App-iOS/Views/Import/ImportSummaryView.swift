import SwiftUI
import SwiftData
import Shared

// MARK: - ImportSummaryView
// 저장 직전 검증 요약 화면 — mockup §⑤
// 미입력 셀 경고 표시 (차단 없음)
// 충돌 감지: 같은 날짜 + 유사 코스명 기존 라운드가 있으면 통합 확인 Alert 표시

struct ImportSummaryView: View {
    @Environment(\.modelContext) private var modelContext

    let draft: ScorecardImportDraft
    let onSave: () -> Void
    let onBack: () -> Void

    // MARK: - 충돌 Alert 상태

    @State private var conflictRound: Round? = nil
    @State private var showConflictAlert = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 12) {
                        // 저장 요약 카드
                        summaryCard

                        // 미입력 셀 경고 (있을 때만)
                        if !emptyCells.isEmpty {
                            emptyCellsCard
                        }

                        // 안내 메시지
                        Text("미입력 셀이 있어도 저장할 수 있습니다. 저장 후 '이번 라운드'에서 언제든 편집할 수 있어요. 원본 이미지는 저장되지 않습니다.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 14)
                            .lineSpacing(3)

                        Spacer(minLength: 80)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }

                // 액션 바
                HStack(spacing: 10) {
                    Button("되돌아가기") {
                        onBack()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(.systemGray5))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    Button("저장하고 닫기") {
                        attemptSave()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .padding(.bottom, 16)
                .background(.ultraThinMaterial)
            }
            .navigationTitle("검증 결과")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.large])
        .alert(conflictAlertTitle, isPresented: $showConflictAlert) {
            Button("통합", role: .destructive) {
                if let existing = conflictRound {
                    modelContext.delete(existing)
                    try? modelContext.save()
                }
                onSave()
            }
            Button("취소", role: .cancel) {
                conflictRound = nil
            }
        } message: {
            Text(conflictAlertMessage)
        }
    }

    // MARK: - 충돌 감지 후 저장 흐름

    private func attemptSave() {
        let courseName = draft.clubName ?? ""
        let conflict = CourseNameMatcher.findConflictingRound(
            date: draft.resolvedDate,
            courseName: courseName,
            context: modelContext
        )
        if let conflict {
            conflictRound = conflict
            showConflictAlert = true
        } else {
            onSave()
        }
    }

    // MARK: - Alert 문자열

    private var conflictAlertTitle: String {
        "같은 날짜에 라운드가 있어요"
    }

    private var conflictAlertMessage: String {
        let dateStr = formattedDateShort(conflictRound?.date ?? draft.resolvedDate)
        let name = conflictRound?.courseName ?? (draft.clubName ?? "알 수 없음")
        return "\(dateStr) '\(name)' 라운드가 이미 있습니다.\n가져온 스코어카드가 기준이 되며, 이전 기록은 삭제됩니다.\n\n통합하시겠어요?"
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("저장 요약")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 4)

            Divider().padding(.horizontal, 14)

            summaryRow(key: "코스", value: courseText)
            Divider().padding(.horizontal, 14)
            summaryRow(key: "날짜", value: formattedDate(draft.resolvedDate))
            Divider().padding(.horizontal, 14)
            summaryRow(key: "본인 스코어", value: ownerScoreText)
            Divider().padding(.horizontal, 14)
            summaryRow(key: "동반자", value: companionText)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
    }

    private func summaryRow(key: String, value: String) -> some View {
        HStack {
            Text(key)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.system(size: 15, weight: .medium))
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Empty Cells Card

    private var emptyCellsCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("미입력 셀")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 4)

            Divider().padding(.horizontal, 14)

            ForEach(Array(emptyCells.enumerated()), id: \.offset) { index, cell in
                if index > 0 {
                    Divider().padding(.horizontal, 14)
                }
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                        .font(.system(size: 14))
                    Text(cell)
                        .font(.system(size: 14))
                    Spacer()
                    Text("확인")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.12))
                        .foregroundStyle(.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
    }

    // MARK: - Computed

    private var courseText: String {
        let name = draft.clubName ?? "알 수 없는 클럽"
        let sections = draft.sections.map { $0.name }.joined(separator: "+")
        return sections.isEmpty ? name : "\(name) · \(sections)"
    }

    private var ownerScoreText: String {
        guard let owner = draft.players.first(where: { $0.isOwner }) else { return "알 수 없음" }
        let total = owner.totalAbsolute(sections: draft.sections)
        return "\(total)타"
    }

    private var companionText: String {
        let companions = draft.players.filter { !$0.isOwner }
        if companions.isEmpty { return "없음" }
        let newCount = companions.filter { $0.matchedPlayerName == nil }.count
        let text = "\(companions.count)명"
        if newCount > 0 { return "\(text) (\(newCount)명 신규)" }
        return text
    }

    private var emptyCells: [String] {
        var cells: [String] = []
        for section in draft.sections {
            // PAR 미입력
            for (holeIdx, par) in section.parRow.enumerated() {
                if par == nil {
                    cells.append("PAR \(section.holeOffset + holeIdx + 1)번 홀 비어 있음")
                }
            }
            // 선수 미입력
            for player in draft.players {
                let scores = player.scores[section.id] ?? []
                for (holeIdx, score) in scores.enumerated() {
                    if score == nil {
                        cells.append("\(player.rawLabel) \(section.holeOffset + holeIdx + 1)번 홀 비어 있음")
                    }
                }
            }
        }
        return cells
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy/MM/dd HH:mm"
        f.locale = Locale(identifier: "ko_KR")
        return f.string(from: date)
    }

    private func formattedDateShort(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "ko_KR")
        return f.string(from: date)
    }
}

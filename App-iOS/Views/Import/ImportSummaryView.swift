import SwiftUI
import SwiftData
import Shared
import os.log

// MARK: - ImportSummaryView
// 저장 직전 검증 요약 화면 — mockup §⑤
// 미입력 셀 경고 표시 (차단 없음)
// 충돌 감지: 같은 날짜 + 유사 코스명 기존 라운드가 있으면 통합 확인 오버레이 표시
//
// [수정 2026-05-29] 중첩 .sheet(ConflictResolutionSheet) → ZStack 오버레이로 교체.
// fullScreenCover → sheet → sheet 3중 중첩이 시트 타이밍 버그(빈화면)를 유발했으므로
// 같은 뷰 트리 내 오버레이로 대체해 안정적 렌더링 보장.

private let logger = Logger(subsystem: "kr.zerolive.golf.roundon", category: "Import")

struct ImportSummaryView: View {
    @Environment(\.modelContext) private var modelContext

    let draft: ScorecardImportDraft
    let onSave: () -> Void
    let onBack: () -> Void

    // MARK: - 충돌 오버레이 상태

    @State private var conflictRound: Round? = nil
    @State private var showConflictAlert = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // 메인 콘텐츠 스크롤
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

                // MARK: - 충돌 오버레이 (ZStack 내부 — 중첩 시트 대체)
                // fullScreenCover → sheet(Summary) → sheet(Conflict) 3중 중첩 대신
                // 같은 뷰 트리의 최상위 레이어로 표시해 빈화면 버그 원천 차단.
                if showConflictAlert, let existing = conflictRound {
                    // 딤 배경 (탭 시 취소)
                    Color.black.opacity(0.45)
                        .ignoresSafeArea()
                        .onTapGesture {
                            logger.info("[Import] 충돌 오버레이: 배경 탭 → 취소")
                            withAnimation(.easeOut(duration: 0.2)) {
                                showConflictAlert = false
                                conflictRound = nil
                            }
                        }
                        .transition(.opacity)
                        .zIndex(10)

                    // ConflictResolutionSheet 카드 (오버레이 카드 스타일)
                    conflictCard(existing: existing)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(11)
                }
            }
            .navigationTitle("검증 결과")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.large])
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showConflictAlert)
    }

    // MARK: - 충돌 카드 (오버레이 래퍼)
    // ConflictResolutionSheet를 카드 형태로 감싸 좌우 패딩 + 라운드 모서리 + 그림자 적용.
    // 핸들바 등 시트 전용 요소를 제거하고 카드 스타일로 교체.

    @ViewBuilder
    private func conflictCard(existing: Round) -> some View {
        VStack(spacing: 0) {
            // 상단 드래그 핸들 제거 → 카드 상단 라운드 처리만 유지

            ConflictResolutionSheet(
                existingRound: existing,
                draft: draft,
                onReplace: {
                    let name = existing.courseName
                    let date = existing.date.formatted(.iso8601.year().month().day())
                    let isImported = existing.isImported
                    logger.info("[Import] 충돌 액션: 대체 선택 — 기존 라운드 '\(name)' \(date) isImported=\(isImported)")
                    modelContext.delete(existing)
                    try? modelContext.save()
                    withAnimation(.easeOut(duration: 0.2)) {
                        showConflictAlert = false
                    }
                    onSave()
                },
                onSaveAsNew: {
                    let name = existing.courseName
                    let date = existing.date.formatted(.iso8601.year().month().day())
                    logger.info("[Import] 충돌 액션: 새 기록으로 저장 — 기존 라운드 '\(name)' \(date) 유지")
                    withAnimation(.easeOut(duration: 0.2)) {
                        showConflictAlert = false
                    }
                    onSave()
                },
                onCancel: {
                    logger.info("[Import] 충돌 액션: 취소 → conflictRound 초기화")
                    withAnimation(.easeOut(duration: 0.2)) {
                        showConflictAlert = false
                        conflictRound = nil
                    }
                }
            )
            // 카드 배경 + 라운드 + 그림자 (시트 전용 presentationDetents 제거됨)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.18), radius: 24, x: 0, y: -4)
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .bottom)
        .frame(maxHeight: .infinity, alignment: .bottom)
    }

    // MARK: - 충돌 감지 후 저장 흐름

    private func attemptSave() {
        let courseName = draft.clubName ?? ""
        logger.info("[Import] attemptSave 진입 — 코스: '\(courseName)', 날짜: \(draft.resolvedDate.formatted(.iso8601.year().month().day()))")

        let conflict = CourseNameMatcher.findConflictingRound(
            date: draft.resolvedDate,
            courseName: courseName,
            context: modelContext
        )
        if let conflict {
            let existingName = conflict.courseName
            let existingDate = conflict.date.formatted(.iso8601.year().month().day())
            let isImported = conflict.isImported
            logger.info("[Import] 충돌 감지: 기존 라운드 '\(existingName)' \(existingDate) isImported=\(isImported) → 오버레이 표시")
            conflictRound = conflict
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                showConflictAlert = true
            }
        } else {
            logger.info("[Import] 충돌 없음 → 바로 저장")
            onSave()
        }
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

}

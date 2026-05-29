import SwiftUI
import SwiftData
import Shared
import os.log

private let reviewLogger = Logger(subsystem: "kr.zerolive.golf.roundon", category: "Import")

// MARK: - ImportReviewView
// 검토·편집 화면 — mockup §② 충실 구현.
// 상단 50%: 이미지 뷰어 (줌/패닝)
// 하단 50%: 결과 패널 스크롤 (메타 + 섹션별 PAR행/선수행)

struct ImportReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var viewModel: ImportViewModel
    @State var draft: ScorecardImportDraft
    let sourceImage: UIImage

    // 선택된 셀: (playerId, sectionId, holeIndexInSection)
    @State private var activeCell: ActiveCell?

    // 동반자 매칭 시트
    @State private var showCompanionMatch = false
    // 저장 요약 시트
    @State private var showSummary = false

    // 날짜 편집
    @State private var showDatePicker = false

    // 클럽 이름 편집 (CourseSearchSheet)
    @State private var showClubNameEdit = false
    @State private var courseSearchText: String = ""
    @State private var allCourses: [GolfCourse] = []

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // 상단: 이미지 뷰어 (55%)
                ScorecardImageViewer(image: sourceImage)
                    .frame(maxHeight: UIScreen.main.bounds.height * 0.45)

                Divider()

                // 하단: 결과 패널
                resultPanel
            }

            // 액션 바 (고정 하단)
            actionBar
        }
        .navigationTitle("가져오기 검토")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("취소") {
                    viewModel.cancel()
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("저장") {
                    reviewLogger.info("[Import] ImportReviewView '저장' 탭 → 검증 요약 시트 표시")
                    showSummary = true
                }
                .fontWeight(.semibold)
            }
        }
        .sheet(isPresented: $showCompanionMatch) {
            CompanionMatchSheet(draft: $draft)
        }
        .sheet(isPresented: $showSummary) {
            ImportSummaryView(
                draft: draft,
                onSave: {
                    viewModel.draft = draft
                    // commit() 내부에서 phase = .completed 로 전이
                    // → ImportLandingView의 onChange가 fullScreenCover 전체 dismiss 처리
                    viewModel.commit(modelContext: modelContext)
                },
                onBack: { showSummary = false }
            )
        }
        .sheet(isPresented: $showDatePicker) {
            datePicker
        }
        .sheet(isPresented: $showClubNameEdit) {
            CourseSearchSheet(
                localCourses: allCourses,
                searchText: $courseSearchText,
                userLocation: nil,
                modelContext: modelContext,
                onSelectLocal: { course in
                    draft.clubName = course.name
                    draft.courseId = course.id
                    draft.clubSource = .dbSelected
                    showClubNameEdit = false
                },
                onSelectDiscovered: { discovered in
                    draft.clubName = discovered.name
                    draft.courseId = discovered.roundCourseId
                    draft.clubSource = .kakaoSelected
                    showClubNameEdit = false
                }
            )
        }
        .task {
            if allCourses.isEmpty {
                allCourses = (try? await CourseRepository.shared.loadAll()) ?? []
            }
        }
    }

    // MARK: - Result Panel

    private var resultPanel: some View {
        ScrollView {
            // LazyVStack 대신 VStack: 셀 수가 많지 않고(최대 2섹션×4선수)
            // LazyVStack의 lazy 재생성이 stepper 편집 중 흰 화면을 유발할 수 있어 교체
            VStack(spacing: 12) {
                // 경고 배너 (의심 셀 있을 때)
                if hasSuspectCells {
                    warningBanner
                }

                // 메타 카드
                metaCard

                // 섹션들 (전반 + 후반 세로 배열)
                // id: \.id 명시 — ImportSection.id(UUID) 기반 안정 identity 보장
                ForEach($draft.sections, id: \.id) { $section in
                    sectionView(section: $section)
                }

                Spacer(minLength: 80)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
        }
    }

    // MARK: - Warning Banner

    private var hasSuspectCells: Bool {
        for section in draft.sections {
            for player in draft.players {
                let scores = player.scores[section.id] ?? []
                if scores.contains(where: { $0 == nil }) { return true }
            }
        }
        return false
    }

    private var warningBanner: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.red)
                .frame(width: 6, height: 6)
            Text("의심 셀이 있습니다. 값은 PAR 대비 가감입니다 (예: 파3 홀에 「1」이면 4타)")
                .font(.system(size: 12))
                .foregroundStyle(.red)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.red.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Meta Card

    private var metaCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("메타 정보")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 4)

            Divider().padding(.horizontal, 14)

            // 클럽 (편집 가능 — CourseSearchSheet)
            Button {
                courseSearchText = ""
                showClubNameEdit = true
            } label: {
                HStack {
                    Text("클럽")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .frame(width: 56, alignment: .leading)
                    Text(draft.clubName ?? "알 수 없음")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.primary)
                    Spacer()
                    clubSourceChip
                    Image(systemName: "pencil")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.accentColor)
                        .padding(.leading, 4)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }

            Divider().padding(.horizontal, 14)

            // 날짜 (편집 가능)
            Button {
                showDatePicker = true
            } label: {
                HStack {
                    Text("날짜")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .frame(width: 56, alignment: .leading)
                    Text(formattedDate(draft.resolvedDate))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("편집")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.12))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }

            Divider().padding(.horizontal, 14)

            // 본인
            HStack {
                Text("본인")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(width: 56, alignment: .leading)
                Text(draft.players.first(where: { $0.isOwner })?.rawLabel ?? "알 수 없음")
                    .font(.system(size: 15, weight: .medium))
                Spacer()
                Text("프로필")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(Color(.systemGray5))
                    .foregroundStyle(.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
    }

    @ViewBuilder
    private var clubSourceChip: some View {
        switch draft.clubSource {
        case .autoMatched:
            if draft.clubName != nil {
                Text("DB 매칭")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.12))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        case .dbSelected:
            Text("DB")
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(Color.accentColor.opacity(0.12))
                .foregroundStyle(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        case .kakaoSelected:
            Text("카카오")
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(Color.yellow.opacity(0.15))
                .foregroundStyle(Color(red: 0.9, green: 0.5, blue: 0.0))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        case .manual:
            Text("수동")
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(Color(.systemGray5))
                .foregroundStyle(.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func metaRow(key: String, value: String, chip: String?) -> some View {
        HStack {
            Text(key)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .leading)
            Text(value)
                .font(.system(size: 15, weight: .medium))
            Spacer()
            if let chip {
                Text(chip)
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.12))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Section View

    private func sectionView(section: Binding<ImportSection>) -> some View {
        let s = section.wrappedValue
        return VStack(alignment: .leading, spacing: 6) {
            // 섹션 라벨
            HStack {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 6, height: 6)
                Text(s.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Text("PAR \(s.sectionPar)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)

            // PAR 행 (편집 가능)
            parPlayerCard(section: section)

            // 본인 + 동반자 행
            // id: \.id 명시 — ImportPlayer.id(UUID) 기반 안정 identity 보장
            ForEach($draft.players, id: \.id) { $player in
                playerCard(player: $player, section: s)
            }
        }
    }

    // MARK: PAR Card (편집 가능)

    private func parPlayerCard(section: Binding<ImportSection>) -> some View {
        let s = section.wrappedValue

        // 현재 이 PAR 카드에서 선택된 셀 인덱스
        let activeCellIdx: Int? = {
            guard let ac = activeCell,
                  ac.isParCell,
                  ac.sectionId == s.id
            else { return nil }
            return ac.holeIndex
        }()

        return VStack(spacing: 0) {
            // 헤더
            HStack {
                Text("PAR")
                    .font(.system(size: 15, weight: .semibold))
                Text("· 코스 기준")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(s.sectionPar)")
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemGray6).opacity(0.5))

            Divider()

            // 그리드 (탭 가능)
            ScoreGridView(
                section: ImportSectionDisplay(
                    holeOffset: s.holeOffset,
                    parRow: s.parRow,
                    playerScores: nil
                ),
                isParRow: true,
                activeCellIndex: activeCellIdx,
                onCellTap: { holeIdx in
                    if activeCellIdx == holeIdx {
                        activeCell = nil
                    } else {
                        activeCell = ActiveCell(
                            playerId: nil,
                            sectionId: s.id,
                            holeIndex: holeIdx
                        )
                    }
                }
            )
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            // inline stepper (PAR 셀 선택 시)
            if let holeIdx = activeCellIdx {
                let parValue: Int? = s.parRow.indices.contains(holeIdx) ? s.parRow[holeIdx] : nil
                InlineScoreStepper(
                    holeNumber: s.holeOffset + holeIdx + 1,
                    par: parValue ?? 4,
                    relative: nil,
                    isParMode: true,
                    parValue: parValue,
                    onChanged: { newPar in
                        updatePar(
                            sectionId: s.id,
                            holeIndex: holeIdx,
                            newPar: newPar,
                            sections: &draft.sections
                        )
                    }
                )
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
    }

    // MARK: Player Card

    private func playerCard(player: Binding<ImportPlayer>, section: ImportSection) -> some View {
        let p = player.wrappedValue
        let relSum = p.relativeSum(for: section.id)
        let absSum = p.absoluteSum(for: section)

        // 현재 이 카드에서 선택된 셀 인덱스
        let activeCellIdx: Int? = {
            guard let ac = activeCell,
                  !ac.isParCell,
                  ac.playerId == p.id,
                  ac.sectionId == section.id
            else { return nil }
            return ac.holeIndex
        }()

        return VStack(spacing: 0) {
            // 헤더
            HStack {
                HStack(spacing: 6) {
                    Text(p.displayName)
                        .font(.system(size: 15, weight: .semibold))
                    if p.isOwner {
                        Text("· 본인")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    } else {
                        Button {
                            showCompanionMatch = true
                        } label: {
                            Text("동반자 매칭")
                                .font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.12))
                                .foregroundStyle(Color.accentColor)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                Spacer()
                PlayerTotalBadge(relativeSum: relSum, absoluteSum: absSum)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            // 그리드
            ScoreGridView(
                section: ImportSectionDisplay(
                    holeOffset: section.holeOffset,
                    parRow: section.parRow,
                    playerScores: p.scores[section.id]
                ),
                isParRow: false,
                activeCellIndex: activeCellIdx,
                onCellTap: { holeIdx in
                    if activeCellIdx == holeIdx {
                        // 같은 셀 탭 → 선택 해제
                        activeCell = nil
                    } else {
                        activeCell = ActiveCell(
                            playerId: p.id,
                            sectionId: section.id,
                            holeIndex: holeIdx
                        )
                    }
                }
            )
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            // inline stepper (선택된 셀이 이 카드에 있을 때만)
            if let holeIdx = activeCellIdx {
                let par: Int = section.parRow.indices.contains(holeIdx) ? (section.parRow[holeIdx] ?? 4) : 4
                let scoreArr = p.scores[section.id] ?? []
                let relative: Int? = scoreArr.indices.contains(holeIdx) ? scoreArr[holeIdx] : nil
                InlineScoreStepper(
                    holeNumber: section.holeOffset + holeIdx + 1,
                    par: par,
                    relative: relative,
                    onChanged: { newRelative in
                        updateScore(
                            playerId: p.id,
                            sectionId: section.id,
                            holeIndex: holeIdx,
                            newRelative: newRelative,
                            players: &draft.players
                        )
                    }
                )
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button("취소") {
                viewModel.cancel()
                dismiss()
            }
            .font(.system(size: 16, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(.systemGray5))
            .foregroundStyle(.primary)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            Button("저장") {
                reviewLogger.info("[Import] ImportReviewView 액션바 '저장' 탭 → 검증 요약 시트 표시")
                showSummary = true
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

    // MARK: - Date Picker Sheet

    private var datePicker: some View {
        NavigationStack {
            DatePicker(
                "날짜 선택",
                selection: Binding(
                    get: { draft.resolvedDate },
                    set: { draft.resolvedDate = $0 }
                ),
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.graphical)
            .navigationTitle("날짜 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { showDatePicker = false }
                }
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Helpers

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy/MM/dd a hh:mm"
        f.locale = Locale(identifier: "ko_KR")
        return f.string(from: date)
    }

    private func updateScore(
        playerId: UUID,
        sectionId: UUID,
        holeIndex: Int,
        newRelative: Int,
        players: inout [ImportPlayer]
    ) {
        guard let idx = players.firstIndex(where: { $0.id == playerId }) else { return }
        var scores = players[idx].scores[sectionId] ?? Array(repeating: nil, count: 9)
        if holeIndex < scores.count {
            scores[holeIndex] = newRelative
        } else {
            while scores.count <= holeIndex { scores.append(nil) }
            scores[holeIndex] = newRelative
        }
        players[idx].scores[sectionId] = scores
    }

    private func updatePar(
        sectionId: UUID,
        holeIndex: Int,
        newPar: Int,
        sections: inout [ImportSection]
    ) {
        guard let idx = sections.firstIndex(where: { $0.id == sectionId }) else { return }
        // 범위 검증: 1~6
        let clamped = max(1, min(6, newPar))
        if holeIndex < sections[idx].parRow.count {
            sections[idx].parRow[holeIndex] = clamped
        }
    }
}

// MARK: - ActiveCell

private struct ActiveCell: Equatable {
    /// nil = PAR 행, non-nil = 선수 행
    let playerId: UUID?
    let sectionId: UUID
    let holeIndex: Int

    var isParCell: Bool { playerId == nil }
}

// MARK: - Array safe subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

import SwiftUI
import SwiftData
import UIKit
import Shared

// MARK: - RoundDetailView
// iphone-2.8: 완료 라운드 사후 보기 (12-SCREENS 2.8)
// viewer URL 복사 + 만료 표시 + 재공유 진입
// 사진 기능은 2026-05-18 폐기 (개인정보보호, 비용 절감)
// 디자인: viewer.ts v6 (2026-05-24) 이식

struct RoundDetailView: View {

    // MARK: Props

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let round: Round

    // MARK: State

    @State private var scoreVM: ScoreCardViewModel
    @State private var shareVM: ShareViewModel
    @State private var showShare = false
    @State private var showDeleteConfirm = false
    @State private var bannerMessage: String?
    @State private var bannerSeverity: BannerNotice.Severity = .info
    @State private var showSafari = false
    @State private var showCopyToast = false

    // F7 편집 모드
    @State private var isEditMode = false
    @State private var editRoundVM: RoundViewModel?

    // E: 구장 수정 (추천 → 직접 검색)
    @State private var showCourseEdit = false

    private let apiClient = ShareAPIClient()
    private let keychainStore = KeychainStore.shared

    // MARK: Init

    init(round: Round) {
        self.round = round
        _scoreVM = State(initialValue: ScoreCardViewModel(round: round))
        _shareVM = State(initialValue: ShareViewModel(round: round))
    }

    // MARK: Body

    var body: some View {
        ZStack {
            Color.paleSageBg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    // 배너
                    if let msg = bannerMessage {
                        BannerNotice(message: msg, severity: bannerSeverity, dismissAction: {
                            bannerMessage = nil
                        })
                        .padding(.horizontal, 16)
                    }

                    // Hero 카드 (viewer eyebrow + 코스명 + 메타)
                    heroCard
                        .padding(.horizontal, 16)

                    // 공유 링크 섹션
                    shareLinkSection

                    // Player 요약 카드
                    playerSummarySection
                        .padding(.horizontal, 16)

                    // 홀별 스코어카드 (전반/후반)
                    scorecardSection

                    // 범례
                    legendCard
                        .padding(.horizontal, 16)

                    Spacer(minLength: 80)
                }
                .padding(.top, 16)
            }

            // 공유 버튼 (하단 고정)
            VStack {
                Spacer()
                shareButton
            }
        }
        .navigationTitle(round.courseName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isEditMode {
                    Button("저장") {
                        saveEdit()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.houseGreen)
                } else {
                    Menu {
                        Button {
                            enterEditMode()
                        } label: {
                            Label("편집", systemImage: "pencil")
                        }
                        Button {
                            AppLogger.round.info("[RoundDetail] 구장 수정 진입 — round=\(round.courseName, privacy: .private) (id=\(round.id))")
                            showCourseEdit = true
                        } label: {
                            Label("구장 수정", systemImage: "mappin.and.ellipse")
                        }
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("라운드 삭제", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(Color.houseGreen)
                    }
                    .accessibilityLabel("라운드 메뉴")
                }
            }
        }
        .confirmationDialog(
            "라운드를 삭제할까요?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) {
                deleteRound()
            }
            Button("취소", role: .cancel) { }
        } message: {
            Text("\(round.courseName) 라운드와 모든 스코어가 영구 삭제됩니다. 되돌릴 수 없습니다.")
        }
        .sheet(isPresented: $showCourseEdit) {
            CourseEditSheet(
                round: round,
                modelContext: modelContext,
                onSelectLocal: { course in
                    applyCourseSelection(courseId: course.id, courseName: course.name, source: "local")
                    showCourseEdit = false
                },
                onSelectDiscovered: { discovered in
                    upsertDiscovered(discovered)
                    applyCourseSelection(courseId: discovered.roundCourseId, courseName: discovered.name, source: "kakao")
                    showCourseEdit = false
                }
            )
        }
        .sheet(isPresented: $showShare) {
            ShareSheetView(round: round, shareVM: shareVM, onShared: { url in
                bannerMessage = "공유 링크가 생성되었어요."
                bannerSeverity = .success
                let snapshot = bannerMessage
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    if bannerMessage == snapshot {
                        withAnimation { bannerMessage = nil }
                    }
                }
            })
        }
        .task {
            // C2: 기존 평문 editToken Keychain 마이그레이션
            keychainStore.migrateIfNeeded(round: round)
            try? modelContext.save()

            // C4: 만료 자동 감지
            let expired = round.sharedExpiresAt.map { $0 < .now } ?? false
            if expired {
                shareVM.checkExpiration()
                bannerMessage = "공유 링크가 만료되었어요. 재공유해 주세요."
                bannerSeverity = .error
                Task { await HapticEngine.shared.play(.viewerExpired) }
            }
        }
    }

    // MARK: - Hero Card (viewer eyebrow + 코스명 + 메타)

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 상단 5pt 그라데이션 라인
            LinearGradient(
                colors: [Color.houseGreen, Color.heroLeaderDelta, Color.accentGreen],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 5)

            VStack(alignment: .leading, spacing: 12) {
                // eyebrow
                HStack(spacing: 7) {
                    Circle()
                        .fill(Color.accentGreen)
                        .frame(width: 6, height: 6)
                    Text("ROUND SCORECARD")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.8)
                        .foregroundStyle(Color.accentGreen)
                }

                // 코스명
                Text(round.courseName)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(2)

                // 메타 (날짜 · 플레이어 · Par)
                heroMeta
            }
            .padding(.horizontal, 22)
            .padding(.top, 22)
            .padding(.bottom, 22)
        }
        .background(Color.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(Color.cardBorder, lineWidth: 1)
        )
        .shadow(color: Color(red: 0.059, green: 0.239, blue: 0.180).opacity(0.04), radius: 2, x: 0, y: 1)
        .shadow(color: Color(red: 0.059, green: 0.239, blue: 0.180).opacity(0.10), radius: 20, x: 0, y: 10)
    }

    private var heroMeta: some View {
        let dateStr = formattedViewerDate(round.finishedAt ?? round.date)
        let players = scoreVM.players
        let playerLabel: String = {
            if players.isEmpty { return "" }
            if players.count == 1 { return players[0].name }
            return "\(players[0].name) 외 \(players.count - 1)명"
        }()
        let totalPar = scoreVM.totalPar

        return HStack(spacing: 12) {
            if !dateStr.isEmpty {
                Text(dateStr)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.inkSoft)
            }
            if !dateStr.isEmpty && !playerLabel.isEmpty {
                Circle()
                    .fill(Color.inkFaint)
                    .frame(width: 4, height: 4)
            }
            if !playerLabel.isEmpty {
                Text(playerLabel)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.inkSoft)
                    .lineLimit(1)
            }
            if totalPar > 0 {
                Circle()
                    .fill(Color.inkFaint)
                    .frame(width: 4, height: 4)
                Text("Par \(totalPar)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.inkSoft)
            }
            if round.isImported {
                importedChip
            }
        }
    }

    private var importedChip: some View {
        HStack(spacing: 3) {
            Image(systemName: "square.and.arrow.down")
                .font(.system(size: 9, weight: .semibold))
            Text("가져옴")
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(Color(red: 0.55, green: 0.45, blue: 0.05))
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(Color(red: 1.0, green: 0.95, blue: 0.7).opacity(0.9))
        .clipShape(Capsule())
        .accessibilityLabel("스코어카드에서 가져온 라운드")
    }

    // MARK: - Share Link Section

    private var shareLinkSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("공유 링크")
                .padding(.horizontal, 16)

            if let url = round.sharedURL, round.sharedShortId != nil {
                HStack(spacing: 8) {
                    Text(url.replacingOccurrences(of: "https://", with: ""))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color.houseGreen)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 6) {
                        compactIconButton(icon: "safari", label: "바로보기") {
                            showSafari = true
                            AppLogger.share.info("[RoundDetail] 바로보기: \(url)")
                        }
                        compactIconButton(icon: "doc.on.doc", label: "복사") {
                            UIPasteboard.general.string = url
                            AppLogger.share.info("[RoundDetail] 링크 복사: \(url)")
                            Task { await HapticEngine.shared.play(.shareSuccess) }
                            withAnimation { showCopyToast = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation { showCopyToast = false }
                            }
                        }
                        compactIconButton(icon: "square.and.arrow.up", label: "공유") {
                            if let u = URL(string: url) {
                                AppLogger.share.info("[RoundDetail] 시스템 공유 시트: \(url)")
                                presentActivitySheet(url: u)
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.cardSurface)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.cardBorder, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
                .padding(.horizontal, 16)
                .overlay(alignment: .bottom) {
                    if showCopyToast {
                        copyToast
                            .offset(y: -12)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .sheet(isPresented: $showSafari) {
                    if let u = URL(string: url) {
                        SafariView(url: u)
                            .ignoresSafeArea()
                    }
                }

                if let expiresAt = round.sharedExpiresAt {
                    let expired = expiresAt < .now
                    HStack(spacing: 4) {
                        Image(systemName: expired ? "exclamationmark.circle" : "clock")
                            .font(.system(size: 11))
                        Text(expired
                            ? "만료됨 (\(formattedExpiry(expiresAt)))"
                            : "만료: \(formattedExpiry(expiresAt))")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(expired ? .red : Color.inkSoft)
                    .padding(.horizontal, 22)
                    .padding(.top, 2)
                }
            } else {
                Text("아직 공유하지 않았어요.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.inkSoft)
                    .padding(.horizontal, 16)
            }
        }
    }

    private func compactIconButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.houseGreen)
                .frame(width: 32, height: 32)
                .background(Color.accentGreen.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var copyToast: some View {
        Text("링크 복사됨")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.houseGreen.opacity(0.95), in: Capsule())
            .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 2)
    }

    // MARK: - Player Summary Section (viewer .players 3-card hero)

    private var playerSummarySection: some View {
        let players = scoreVM.players
        let totalPar = scoreVM.totalPar

        // (player, sum) 목록 — 점수 낮은 순 정렬 (미입력 0점은 후미)
        let sums: [(player: Player, sum: Int)] = players.map { player in
            let sum = scoreVM.totalByPlayer[player.id] ?? 0
            return (player, sum)
        }.sorted {
            if $0.sum == 0 && $1.sum == 0 { return false }
            if $0.sum == 0 { return false }
            if $1.sum == 0 { return true }
            return $0.sum < $1.sum
        }

        let validSums = sums.filter { $0.sum > 0 }
        let minSum = validSums.map(\.sum).min() ?? 0

        // 1~4명: 한 행에 모두 표시 / 5명 이상: 4열 wrap
        let colCount = min(players.count, 4)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: max(1, colCount))
        let isTight = colCount == 4

        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Array(sums.enumerated()), id: \.offset) { _, entry in
                let isLeader = entry.sum > 0 && entry.sum == minSum
                let rank = rankLabel(for: entry.player.id, sums: sums)
                PlayerHeroCard(
                    player: entry.player,
                    sum: entry.sum,
                    totalPar: totalPar,
                    isLeader: isLeader,
                    rank: rank,
                    isTight: isTight
                )
            }
        }
    }

    private func rankLabel(for playerId: UUID, sums: [(player: Player, sum: Int)]) -> String {
        let validSorted = sums.filter { $0.sum > 0 }.sorted { $0.sum < $1.sum }
        var i = 0
        while i < validSorted.count {
            let currentSum = validSorted[i].sum
            var j = i
            while j < validSorted.count && validSorted[j].sum == currentSum { j += 1 }
            let tied = j - i
            for k in i..<j {
                if validSorted[k].player.id == playerId {
                    return tied > 1 ? "T\(i + 1)" : "\(i + 1)"
                }
            }
            i = j
        }
        return ""
    }

    // MARK: - Scorecard Section (전반/후반 카드)

    private var scorecardSection: some View {
        VStack(spacing: 18) {
            // 편집 토글 버튼
            HStack {
                sectionLabel("스코어카드")
                    .padding(.leading, 16)
                Button {
                    if isEditMode { saveEdit() } else { enterEditMode() }
                } label: {
                    Image(systemName: isEditMode ? "checkmark.circle.fill" : "square.and.pencil")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.houseGreen)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isEditMode ? "편집 완료" : "스코어 편집")

                if isEditMode {
                    Text("탭+1 / 길게누르기-1")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.inkSoft)
                }
                Spacer()
            }

            // 전반 카드
            if !scoreVM.outHoles.isEmpty {
                halfCard(
                    holes: scoreVM.outHoles,
                    groupLabel: "OUT",
                    halfTitle: round.frontCourseName ?? "전반 홀",
                    groupPar: scoreVM.outParTotal
                )
                .padding(.horizontal, 16)
            }

            // 후반 카드
            if !scoreVM.inHoles.isEmpty {
                halfCard(
                    holes: scoreVM.inHoles,
                    groupLabel: "IN",
                    halfTitle: round.backCourseName ?? "후반 홀",
                    groupPar: scoreVM.inParTotal
                )
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: Half Card (전반/후반 공통)

    private func halfCard(
        holes: [Int],
        groupLabel: String,
        halfTitle: String,
        groupPar: Int
    ) -> some View {
        VStack(spacing: 0) {
            // 카드 헤더
            HStack {
                Text(halfTitle)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
                // OUT/IN pill
                Text("\(groupLabel) · Par \(groupPar)")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.0)
                    .foregroundStyle(Color.accentGreen)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 5)
                    .background(Color.tableHeaderBg)
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.accentGreen.opacity(0.25), lineWidth: 1)
                    )
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // 테이블 — device width fit (가로 스크롤 없음, viewer @media max-width 방식)
            GeometryReader { geo in
                // 라벨 컬럼: 72pt 고정, 합계 컬럼: 52pt 고정, 나머지를 홀 개수로 균등 분배
                let labelW: CGFloat = 72
                let sumW: CGFloat = 52
                let holeW: CGFloat = max(24, (geo.size.width - labelW - sumW) / CGFloat(max(1, holes.count)))
                VStack(spacing: 0) {
                    // 헤더 행 (green-50 배경)
                    HStack(spacing: 0) {
                        tableHeaderPlayerCol(width: labelW)
                        ForEach(holes, id: \.self) { h in
                            tableHeaderHoleCol(holeNumber: h, par: scoreVM.parByHole[h] ?? 4, width: holeW)
                        }
                        tableHeaderSumCol(groupLabel: groupLabel, groupPar: groupPar, width: sumW)
                    }
                    .background(Color.tableHeaderBg)

                    Divider().background(Color.cardBorder)

                    // 플레이어 행
                    ForEach(Array(scoreVM.players.enumerated()), id: \.offset) { idx, player in
                        playerTableRow(
                            player: player,
                            holes: holes,
                            groupPar: groupPar,
                            isEven: idx % 2 == 1,
                            labelW: labelW,
                            holeW: holeW,
                            sumW: sumW
                        )
                        if idx < scoreVM.players.count - 1 {
                            Divider().background(Color.cardBorder)
                        }
                    }
                }
            }
            .frame(height: CGFloat(scoreVM.players.count + 1) * 40 + 1)
        }
        .background(Color.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(Color.cardBorder, lineWidth: 1)
        )
        .shadow(color: Color(red: 0.059, green: 0.239, blue: 0.180).opacity(0.04), radius: 2, x: 0, y: 1)
    }

    // MARK: Table Header Cells

    private func tableHeaderPlayerCol(width: CGFloat) -> some View {
        Text("홀")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Color.inkPrimary)
            .frame(width: width, alignment: .leading)
            .padding(.leading, 10)
            .padding(.vertical, 9)
    }

    private func tableHeaderHoleCol(holeNumber: Int, par: Int, width: CGFloat) -> some View {
        VStack(spacing: 2) {
            Text("\(holeNumber)")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.inkPrimary)
                .minimumScaleFactor(0.7)
            Text("(\(par))")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.inkFaint)
                .minimumScaleFactor(0.7)
        }
        .frame(width: width)
        .padding(.vertical, 9)
    }

    private func tableHeaderSumCol(groupLabel: String, groupPar: Int, width: CGFloat) -> some View {
        VStack(spacing: 2) {
            Text(groupLabel)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)
            Text("(\(groupPar))")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
                .minimumScaleFactor(0.7)
        }
        .frame(width: width)
        .padding(.vertical, 9)
        .background(Color.houseGreen)
    }

    // MARK: Player Table Row

    private func playerTableRow(
        player: Player,
        holes: [Int],
        groupPar: Int,
        isEven: Bool,
        labelW: CGFloat,
        holeW: CGFloat,
        sumW: CGFloat
    ) -> some View {
        let cellH: CGFloat = 38
        return HStack(spacing: 0) {
            // 이름 셀 (좌측 swatch + 이름)
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentGreen)
                    .frame(width: 6, height: 6)
                Text(player.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(width: labelW, alignment: .leading)
            .padding(.leading, 10)
            .padding(.vertical, 8)

            // 홀별 점수 셀
            ForEach(holes, id: \.self) { h in
                let count = scoreVM.count(holeNumber: h, playerId: player.id)
                let cat = scoreVM.scoreCategory(holeNumber: h, playerId: player.id)
                let par = scoreVM.parByHole[h] ?? 4

                if isEditMode {
                    ScoreCell(
                        count: count,
                        category: cat,
                        isCurrentHole: false,
                        holeNumber: h,
                        playerName: player.name,
                        par: par,
                        interactive: true,
                        onTap: {
                            guard let hole = round.holeList.first(where: { $0.holeNumber == h }) else { return }
                            editIncrement(hole: hole, playerId: player.id)
                        },
                        onLongPress: {
                            guard let hole = round.holeList.first(where: { $0.holeNumber == h }) else { return }
                            editDecrement(hole: hole, playerId: player.id)
                        }
                    )
                    .frame(width: holeW, height: cellH)
                } else {
                    ScoreCellView(
                        strokes: count,
                        par: par,
                        cellSize: min(24, holeW - 4),
                        holeNumber: h,
                        playerName: player.name,
                        showRelative: round.isImported
                    )
                    .frame(width: holeW, height: cellH)
                }
            }

            // 합계 셀
            let groupSum: Int = holes.reduce(0) { acc, h in
                acc + scoreVM.count(holeNumber: h, playerId: player.id)
            }
            VStack(spacing: 1) {
                if groupSum > 0 {
                    Text("\(groupSum)")
                        .font(.system(size: 15, weight: .semibold))
                        .monospacedDigit()
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(Color.inkPrimary)
                    let delta = groupSum - groupPar
                    Text(delta == 0 ? "E" : delta > 0 ? "+\(delta)" : "\(delta)")
                        .font(.system(size: 9, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(Color.sumDelta)
                } else {
                    Text("—")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.inkFaint)
                }
            }
            .frame(width: sumW)
            .padding(.vertical, 8)
            .background(Color.tableHeaderBg)
        }
        .background(isEven ? Color(red: 0.988, green: 0.996, blue: 0.988) : Color.clear)
    }

    // MARK: - Legend Card

    private var legendCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 20) {
                legendChip(label: "버디 이상 (≤-1)", diff: -1, par: 4)
                legendChip(label: "파 (E)", diff: 0, par: 4)
            }
            HStack(spacing: 20) {
                legendChip(label: "보기 (+1)", diff: 1, par: 4)
                legendChip(label: "더블+ (≥+2)", diff: 2, par: 4)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color.cardBorder, lineWidth: 1)
        )
    }

    private func legendChip(label: String, diff: Int, par: Int) -> some View {
        let strokes = par + diff
        return HStack(spacing: 10) {
            ScoreCellView(strokes: strokes, par: par, cellSize: 30)
                .frame(width: 30, height: 30)
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Share Button

    private var shareButton: some View {
        Button {
            showShare = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: round.sharedShortId != nil ? "arrow.2.circlepath" : "square.and.arrow.up")
                Text(round.sharedShortId != nil ? "viewer 업데이트 / 회수" : "공유하기")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                LinearGradient(
                    colors: [Color.houseGreen, Color(red: 0.078, green: 0.282, blue: 0.184)],
                    startPoint: UnitPoint(x: 0.1, y: 0),
                    endPoint: UnitPoint(x: 0.9, y: 1)
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .background(
            LinearGradient(
                colors: [Color.paleSageBg.opacity(0), Color.paleSageBg],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - F7: 사후 편집 헬퍼

    private func enterEditMode() {
        let vm = RoundViewModel(modelContext: modelContext)
        vm.editRound(round)
        editRoundVM = vm
        isEditMode = true
    }

    private func saveEdit() {
        do {
            try editRoundVM?.commitEdit()
            scoreVM.refresh(from: round)
            bannerMessage = "수정 내용을 저장했어요."
            bannerSeverity = .success
            let snapshotMessage = bannerMessage
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if bannerMessage == snapshotMessage {
                    withAnimation { bannerMessage = nil }
                }
            }
        } catch {
            bannerMessage = "저장 중 오류가 발생했어요."
            bannerSeverity = .error
        }
        isEditMode = false
        editRoundVM = nil
    }

    private func editIncrement(hole: HoleScore, playerId: UUID) {
        let maxCount = 15
        let current = hole.count(for: playerId)
        guard current < maxCount else { return }
        if let idx = hole.counts.firstIndex(where: { $0.playerId == playerId }) {
            hole.counts[idx].value += 1
        } else {
            hole.counts.append(ScoreEntry(playerId: playerId, value: 1))
        }
        scoreVM.refresh(from: round)
    }

    private func editDecrement(hole: HoleScore, playerId: UUID) {
        let current = hole.count(for: playerId)
        guard current > 0 else { return }
        if let idx = hole.counts.firstIndex(where: { $0.playerId == playerId }) {
            hole.counts[idx].value = max(0, hole.counts[idx].value - 1)
        }
        scoreVM.refresh(from: round)
    }

    // MARK: - E: 구장 수정 선택 처리

    /// 선택된 골프장으로 round.courseId/courseName 갱신 후 저장.
    private func applyCourseSelection(courseId: String, courseName: String, source: String) {
        round.courseId = courseId
        round.courseName = courseName
        do {
            try modelContext.save()
            AppLogger.round.info("[RoundDetail] 구장 수정 저장 완료 (\(source, privacy: .public)) — '\(courseName, privacy: .private)' (id=\(courseId, privacy: .public))")
            bannerMessage = "구장을 '\(courseName)'(으)로 변경했어요."
            bannerSeverity = .success
            let snapshot = bannerMessage
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if bannerMessage == snapshot {
                    withAnimation { bannerMessage = nil }
                }
            }
            Task { await HapticEngine.shared.play(.shareSuccess) }
        } catch {
            AppLogger.persistence.error("[RoundDetail] 구장 수정 저장 실패: \(error.localizedDescription)")
            bannerMessage = "구장 변경 저장 중 오류가 발생했어요."
            bannerSeverity = .error
        }
    }

    /// 카카오 발견 골프장을 PersistedDiscoveredCourse로 upsert (NewRoundView 패턴).
    private func upsertDiscovered(_ discovered: DiscoveredCourse) {
        let kakaoId = discovered.kakaoPlaceId
        let predicate = #Predicate<PersistedDiscoveredCourse> { $0.kakaoPlaceId == kakaoId }
        let existing = (try? modelContext.fetch(FetchDescriptor(predicate: predicate))) ?? []
        guard existing.isEmpty else {
            AppLogger.round.info("[RoundDetail] 카카오 골프장 캐시 이미 존재 — id=\(kakaoId, privacy: .public)")
            return
        }
        let persisted = PersistedDiscoveredCourse(
            kakaoPlaceId: discovered.kakaoPlaceId,
            name: discovered.name,
            address: discovered.address,
            phone: discovered.phone,
            lat: discovered.lat,
            lng: discovered.lng,
            placeUrl: discovered.placeUrl,
            firstUsedAt: .now
        )
        modelContext.insert(persisted)
        try? modelContext.save()
        AppLogger.round.info("[RoundDetail] 카카오 골프장 영구 캐시 저장 — '\(discovered.name, privacy: .private)' (id=\(kakaoId, privacy: .public))")
    }

    // MARK: - 라운드 삭제

    private func deleteRound() {
        AppLogger.view.info("라운드 삭제: \(round.courseName) (id=\(round.id))")
        modelContext.delete(round)
        do {
            try modelContext.save()
        } catch {
            AppLogger.persistence.error("라운드 삭제 후 저장 실패: \(error)")
            bannerMessage = "삭제 중 오류가 발생했어요."
            bannerSeverity = .error
            return
        }
        dismiss()
    }

    private func presentActivitySheet(url: URL) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        guard let root = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?.rootViewController else {
            AppLogger.share.error("[RoundDetail] keyWindow rootViewController 없음 — 공유 시트 표시 실패")
            return
        }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        if let pop = activityVC.popoverPresentationController {
            pop.sourceView = top.view
            pop.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 0, height: 0)
            pop.permittedArrowDirections = []
        }
        top.present(activityVC, animated: true)
    }

    // MARK: - Helpers

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .bold))
            .tracking(1.2)
            .foregroundStyle(Color.inkFaint)
            .textCase(.uppercase)
    }

    /// viewer.ts 날짜 포맷: "2026 · 05 · 24"
    private func formattedViewerDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy · MM · dd"
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        return formatter.string(from: date)
    }

    /// 만료 시각용 (분 단위): "2026-05-25 11:35 KST"
    private func formattedExpiry(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm 'KST'"
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        return formatter.string(from: date)
    }
}

// MARK: - CourseEditSheet (E: 유사 구장 추천 → 직접 검색)

/// 라운드 구장 수정 시트.
/// 흐름: ① findSimilarCourses 추천 카드 → ② 추천에 없으면 [직접 검색] = 기존 CourseSearchSheet (DB + 카카오맵).
/// custom 직접입력 경로는 제공하지 않음 (DB/카카오만).
private struct CourseEditSheet: View {
    let round: Round
    let modelContext: ModelContext
    let onSelectLocal: (GolfCourse) -> Void
    let onSelectDiscovered: (DiscoveredCourse) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var allCourses: [GolfCourse] = []
    @State private var suggestions: [GolfCourse] = []
    @State private var isLoading = true
    @State private var showDirectSearch = false
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.paleSageBg.ignoresSafeArea()

                if isLoading {
                    ProgressView()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            // 현재 구장
                            VStack(alignment: .leading, spacing: 4) {
                                Text("현재 구장")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.inkSoft)
                                Text(round.courseName.isEmpty ? "미지정" : round.courseName)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(Color.inkPrimary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(Color.cardSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(Color.cardBorder, lineWidth: 1)
                            )

                            // 추천 구장
                            if !suggestions.isEmpty {
                                Text("추천 구장")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.inkSoft)
                                    .padding(.leading, 4)

                                VStack(spacing: 0) {
                                    ForEach(Array(suggestions.enumerated()), id: \.element.id) { idx, course in
                                        if idx > 0 { Divider().padding(.leading, 16) }
                                        Button {
                                            AppLogger.round.info("[RoundDetail] 추천 구장 선택 — '\(course.name, privacy: .private)' (id=\(course.id, privacy: .public))")
                                            onSelectLocal(course)
                                        } label: {
                                            suggestionRow(course: course)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .background(Color.cardSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(Color.cardBorder, lineWidth: 1)
                                )
                            } else {
                                Text("유사한 구장을 찾지 못했어요. 직접 검색해 주세요.")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.inkSoft)
                                    .padding(.leading, 4)
                            }

                            // 직접 검색 버튼
                            Button {
                                searchText = ""
                                AppLogger.round.info("[RoundDetail] 구장 직접 검색 진입")
                                showDirectSearch = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "magnifyingglass")
                                    Text("직접 검색 (DB · 카카오맵)")
                                        .font(.system(size: 15, weight: .semibold))
                                }
                                .foregroundStyle(Color.houseGreen)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.accentGreen.opacity(0.10))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .padding(.top, 4)

                            Spacer(minLength: 20)
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("구장 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                }
            }
            .sheet(isPresented: $showDirectSearch) {
                CourseSearchSheet(
                    localCourses: allCourses,
                    searchText: $searchText,
                    userLocation: nil,
                    modelContext: modelContext,
                    onSelectLocal: { course in
                        showDirectSearch = false
                        onSelectLocal(course)
                    },
                    onSelectDiscovered: { discovered in
                        showDirectSearch = false
                        onSelectDiscovered(discovered)
                    }
                )
            }
            .task {
                if allCourses.isEmpty {
                    allCourses = (try? await CourseRepository.shared.loadAll()) ?? []
                }
                suggestions = CourseNameMatcher.findSimilarCourses(
                    query: round.courseName,
                    from: allCourses,
                    limit: 5
                )
                AppLogger.round.info("[RoundDetail] 추천 구장 \(suggestions.count)개 생성 — query='\(round.courseName, privacy: .private)'")
                isLoading = false
            }
        }
    }

    private func suggestionRow(course: GolfCourse) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "flag.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.accentGreen)
            VStack(alignment: .leading, spacing: 2) {
                Text(course.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.inkPrimary)
                if let region = course.region.nilIfEmpty {
                    Text(region)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.inkSoft)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.inkFaint)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

// MARK: - PlayerHeroCard (viewer .player-card / .player-card.leader)

private struct PlayerHeroCard: View {
    let player: Player
    let sum: Int
    let totalPar: Int
    let isLeader: Bool
    let rank: String
    let isTight: Bool  // 4열일 때 더 타이트한 패딩

    init(player: Player, sum: Int, totalPar: Int, isLeader: Bool, rank: String, isTight: Bool = false) {
        self.player = player
        self.sum = sum
        self.totalPar = totalPar
        self.isLeader = isLeader
        self.rank = rank
        self.isTight = isTight
    }

    /// 점수 + delta를 단일 Text로 합성 — lineLimit/minimumScaleFactor가 합쳐진 폭 기준으로 작동해 줄바꿈 방지
    private var scoreText: Text {
        let scoreFontSize: CGFloat = isTight ? 24 : 28
        let deltaFontSize: CGFloat = isTight ? 12 : 14
        let delta = sum - totalPar
        let deltaLabel = delta == 0 ? "E" : delta > 0 ? "+\(delta)" : "\(delta)"
        return Text("\(sum) ")
            .font(.system(size: scoreFontSize, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundColor(isLeader ? .white : Color.houseGreen)
        + Text(deltaLabel)
            .font(.system(size: deltaFontSize, weight: .bold))
            .monospacedDigit()
            .foregroundColor(isLeader ? Color.accentGreen : Color.sumDelta)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // 카드 본문
            VStack(alignment: .leading, spacing: 0) {
                // 이름 (viewer .player-name)
                Text(player.name)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(isLeader ? Color.white.opacity(0.78) : Color.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                // 점수 + delta (viewer .player-score) — 단일 Text로 합성해 wrap 방지
                if sum > 0 {
                    scoreText
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)
                } else {
                    Text("—")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(isLeader ? Color.white.opacity(0.55) : Color.inkFaint)
                        .padding(.top, 8)
                }
            }
            .padding(.horizontal, isTight ? 10 : 14)
            .padding(.vertical, isTight ? 10 : 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isLeader
                ? LinearGradient(
                    colors: [Color.houseGreen, Color(red: 0.078, green: 0.282, blue: 0.184)],
                    startPoint: UnitPoint(x: 0.1, y: 0),
                    endPoint: UnitPoint(x: 0.9, y: 1)
                  )
                : LinearGradient(colors: [Color.cardSurface, Color.cardSurface], startPoint: .top, endPoint: .bottom)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(isLeader ? Color.houseGreen : Color.cardBorder, lineWidth: 1)
            )
            .shadow(color: Color(red: 0.059, green: 0.239, blue: 0.180).opacity(isLeader ? 0.18 : 0.06), radius: isLeader ? 12 : 4, x: 0, y: isLeader ? 6 : 2)

            // 우상단 rank 뱃지 (viewer .rank)
            if !rank.isEmpty {
                Text(rank)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(isLeader ? Color.white.opacity(0.55) : Color.inkFaint)
                    .padding(.top, 9)
                    .padding(.trailing, 10)
            }
        }
    }
}

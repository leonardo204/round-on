import SwiftUI
import Shared

// MARK: - HoleScoreGrid
// 옵션 A: split9x2 홀별 스코어카드 그리드 — ActiveRoundView / RoundDetailView 공용
// interactive=true 이면 par 셀 탭(Menu), score 셀 탭/길게누르기 활성
// interactive=false 이면 read-only 표시만

struct HoleScoreGrid: View {

    // MARK: Props

    let scoreVM: ScoreCardViewModel
    /// true = par/score 셀 인터랙션 활성 (ActiveRoundView 등 편집 모드)
    let interactive: Bool
    /// 현재 홀 번호 (활성 하이라이트용 — read-only 시 nil)
    let currentHoleNumber: Int?
    /// par 셀 탭 콜백 (interactive only): (holeNumber, newPar)
    let onParChange: ((Int, Int) -> Void)?
    /// score 셀 탭 콜백 (interactive only, delta: +1)
    let onScoreTap: ((Int, UUID) -> Void)?
    /// score 셀 길게누르기 콜백 (interactive only, delta: -1)
    let onScoreLongPress: ((Int, UUID) -> Void)?
    /// 섹션 전반 라벨 (nil이면 "전반")
    let frontLabel: String?
    /// 섹션 후반 라벨 (nil이면 "후반")
    let backLabel: String?

    // MARK: Init

    init(
        scoreVM: ScoreCardViewModel,
        interactive: Bool,
        currentHoleNumber: Int? = nil,
        onParChange: ((Int, Int) -> Void)? = nil,
        onScoreTap: ((Int, UUID) -> Void)? = nil,
        onScoreLongPress: ((Int, UUID) -> Void)? = nil,
        frontLabel: String? = nil,
        backLabel: String? = nil
    ) {
        self.scoreVM = scoreVM
        self.interactive = interactive
        self.currentHoleNumber = currentHoleNumber
        self.onParChange = onParChange
        self.onScoreTap = onScoreTap
        self.onScoreLongPress = onScoreLongPress
        self.frontLabel = frontLabel
        self.backLabel = backLabel
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 16) {
            // 전반 (1-9홀)
            if !scoreVM.outHoles.isEmpty {
                scoreSectionBlock(
                    title: frontLabel ?? "전반",
                    holes: scoreVM.outHoles,
                    parTotal: scoreVM.outParTotal,
                    totalFunc: { scoreVM.outTotal(for: $0) }
                )
            }

            // 후반 (10-18홀) — 9홀이면 자동 숨김
            if !scoreVM.inHoles.isEmpty {
                scoreSectionBlock(
                    title: backLabel ?? "후반",
                    holes: scoreVM.inHoles,
                    parTotal: scoreVM.inParTotal,
                    totalFunc: { scoreVM.inTotal(for: $0) }
                )
            }

            // 합계 행
            if !scoreVM.players.isEmpty {
                totalRowBlock()
                    .padding(.horizontal, 4)
            }
        }
        .padding(.top, 16)
        .padding(.horizontal, 4)
    }

    // MARK: Section Block

    private func scoreSectionBlock(
        title: String,
        holes: [Int],
        parTotal: Int,
        totalFunc: @escaping (UUID) -> Int
    ) -> some View {
        VStack(spacing: 0) {
            // 헤더: 홀 번호 행
            HStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.springTextSecondary)
                    .frame(width: 44, alignment: .center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                ForEach(holes, id: \.self) { h in
                    Text("\(h)")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.springTextSecondary)
                        .frame(maxWidth: .infinity)
                }
                Text("합")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.springTextSecondary)
                    .frame(width: 34)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 4)
            .background(Color.springBorder.opacity(0.3))

            // Par 행
            HStack(spacing: 2) {
                Text("Par")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.springTextSecondary)
                    .frame(width: 44, alignment: .center)
                ForEach(holes, id: \.self) { h in
                    parCellView(holeNumber: h, par: scoreVM.parByHole[h] ?? 4)
                }
                Text("\(parTotal)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.springTextSecondary)
                    .frame(width: 34)
            }
            .padding(.vertical, 3)
            .padding(.horizontal, 4)
            .background(Color.springSurfaceElevated)

            // 플레이어별 점수 행
            ForEach(scoreVM.players) { player in
                playerRowView(
                    player: player,
                    holes: holes,
                    sectionTotal: totalFunc(player.id),
                    sectionParTotal: parTotal
                )
            }
        }
        .background(Color.springSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.04), radius: 1, x: 0, y: 0)
    }

    // MARK: Par Cell

    @ViewBuilder
    private func parCellView(holeNumber: Int, par: Int) -> some View {
        if interactive {
            Menu {
                ForEach([3, 4, 5], id: \.self) { p in
                    Button("Par \(p)") {
                        onParChange?(holeNumber, p)
                    }
                }
            } label: {
                parCellLabel(par: par)
            }
            .accessibilityLabel("\(holeNumber)번 홀 Par, 현재 \(par). 탭하여 변경.")
        } else {
            parCellLabel(par: par)
                .accessibilityLabel("\(holeNumber)번 홀 Par \(par)")
        }
    }

    private func parCellLabel(par: Int) -> some View {
        Text("\(par)")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(parColor(par))
            .frame(maxWidth: .infinity)
            .frame(height: 22)
            .contentShape(Rectangle())
    }

    /// par 값에 따른 색상 (3=그린, 4=기본, 5=파랑)
    private func parColor(_ par: Int) -> Color {
        switch par {
        case 3: return Color.springGreenPrimary
        case 5: return Color(red: 0.08, green: 0.40, blue: 0.75)
        default: return Color.springTextSecondary
        }
    }

    // MARK: Player Row

    private func playerRowView(
        player: Player,
        holes: [Int],
        sectionTotal: Int,
        sectionParTotal: Int
    ) -> some View {
        let (_, parity) = ScoreCardViewModel.formatScoreVsPar(score: sectionTotal, par: sectionParTotal)

        return HStack(spacing: 2) {
            Text(playerShortName(player.name))
                .font(.system(size: 12, weight: player.isOwner ? .semibold : .regular))
                .foregroundStyle(player.isOwner ? Color.springGreenPrimary : Color.springTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 44, alignment: .center)

            ForEach(holes, id: \.self) { h in
                let count = scoreVM.count(holeNumber: h, playerId: player.id)
                let cat = scoreVM.scoreCategory(holeNumber: h, playerId: player.id)
                let isCurrent = h == currentHoleNumber
                let par = scoreVM.parByHole[h] ?? 4

                ScoreCell(
                    count: count,
                    category: cat,
                    isCurrentHole: isCurrent,
                    holeNumber: h,
                    playerName: player.name,
                    par: par,
                    onTap: {
                        if interactive {
                            onScoreTap?(h, player.id)
                        }
                    },
                    onLongPress: {
                        if interactive {
                            onScoreLongPress?(h, player.id)
                        }
                    }
                )
            }

            // 구간 합계 셀 — 친 타수 + par-diff 두 줄
            VStack(spacing: 0) {
                if sectionTotal > 0 {
                    Text("\(sectionTotal)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.springTextPrimary)
                    Text(parDiffBadge(score: sectionTotal, par: sectionParTotal))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(parDiffColor(parity: parity))
                } else {
                    Text("-")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.springTextSecondary)
                }
            }
            .frame(width: 34)
            .accessibilityLabel(ScoreCardViewModel.formatScoreVsPar(score: sectionTotal, par: sectionParTotal).text)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 4)
        .background(player.isOwner && interactive ? Color.springGreenAccent.opacity(0.08) : Color.clear)
    }

    // MARK: Total Row

    private func totalRowBlock() -> some View {
        let totalPar = scoreVM.totalPar
        return VStack(spacing: 0) {
            HStack {
                Text("합계")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.springTextPrimary)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)

            HStack(spacing: 8) {
                ForEach(scoreVM.players) { player in
                    let total = scoreVM.totalByPlayer[player.id] ?? 0
                    let (_, parity) = ScoreCardViewModel.formatScoreVsPar(score: total, par: totalPar)
                    VStack(spacing: 2) {
                        Text(player.name)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.springTextSecondary)
                            .lineLimit(1)
                        if total > 0 {
                            Text("\(total)")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(Color.springTextPrimary)
                                .monospacedDigit()
                            Text(parDiffBadge(score: total, par: totalPar))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(parDiffColor(parity: parity))
                        } else {
                            Text("-")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(Color.springTextSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
        .background(Color.springSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.04), radius: 1, x: 0, y: 0)
    }

    // MARK: Helpers

    private func parDiffBadge(score: Int, par: Int) -> String {
        guard score > 0, par > 0 else { return "" }
        let diff = score - par
        if diff == 0 { return "(E)" }
        if diff > 0 { return "(+\(diff))" }
        return "(\(diff))"
    }

    private func parDiffColor(parity: Int) -> Color {
        if parity < 0 { return Color(red: 0.13, green: 0.60, blue: 0.28) }
        if parity == 0 { return Color.springTextSecondary }
        return Color(red: 0.85, green: 0.35, blue: 0.10)
    }

    private func playerShortName(_ name: String) -> String {
        if name.hasPrefix("동반자"), name.count <= 5 {
            let suffix = name.dropFirst(3)
            return "동\(suffix)"
        }
        return name
    }
}

import SwiftUI
import Shared

// MARK: - ActiveRoundView
// iphone-2.3b: 라운드 진행 — ScoreCell.split9x2 (12-SCREENS D-1)
// 4인 × 18홀 그리드, 현재 홀 하이라이트, 셀 탭 +1 / 길게 누르기 -1
// F4 + F5 iPhone 구현

struct ActiveRoundView: View {
    @Bindable var roundVM: RoundViewModel
    @State private var showFinishConfirm = false
    @State private var showPenaltySheet = false
    @State private var bannerMessage: String?

    private var holeVM: HoleViewModel? { roundVM.holeViewModel }
    private var scoreVM: ScoreCardViewModel? { roundVM.scoreCardViewModel }
    private var playerVM: PlayerListViewModel? { roundVM.playerListViewModel }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.springSurface.ignoresSafeArea()

                VStack(spacing: 0) {
                    // 오프라인 배너
                    if let msg = bannerMessage {
                        BannerNotice(message: msg, severity: .warning, dismissAction: {
                            bannerMessage = nil
                        })
                    }

                    // 라운드 헤더 + HoleProgress
                    roundHeader

                    // 스코어카드 (split9x2)
                    if let scoreVM = scoreVM {
                        scoreCardGrid(scoreVM: scoreVM)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showPenaltySheet = true
                    } label: {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(Color.springTextSecondary)
                    }
                    .accessibilityLabel("벌타 입력")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("종료") {
                        showFinishConfirm = true
                    }
                    .foregroundStyle(.red)
                }
            }
            .confirmationDialog("라운드를 종료하시겠어요?", isPresented: $showFinishConfirm, titleVisibility: .visible) {
                Button("종료", role: .destructive) {
                    roundVM.finishRound()
                    Task { await HapticEngine.shared.play(.roundEnd) }
                }
                Button("취소", role: .cancel) {}
            }
            .sheet(isPresented: $showPenaltySheet) {
                penaltySheet
            }
        }
    }

    // MARK: Round Header

    private var roundHeader: some View {
        VStack(spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(roundVM.currentRound?.courseName ?? "")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.springTextPrimary)
                    if let subLabel = roundVM.currentRound?.displaySubLabel {
                        Text(subLabel)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.springTextSecondary)
                    }
                }
                Spacer()
                // 현재 홀 표시 + 플레이어 칩
                if let holeVM = holeVM {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("\(holeVM.currentHoleNumber)번 홀")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.springGreenPrimary)
                        Text("\(holeVM.currentHoleNumber) / \(holeVM.totalHoles)")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.springTextSecondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            // HoleProgress 도트
            if let holeVM = holeVM {
                HoleProgress(currentHole: holeVM.currentHoleNumber, totalHoles: holeVM.totalHoles)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
        }
        .background(Color.springSurfaceElevated)
        .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
    }

    // MARK: Score Card Grid (split9x2)

    private func scoreCardGrid(scoreVM: ScoreCardViewModel) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                // OUT 구간 (1-9홀) — 전반 코스 라벨 사용
                if !scoreVM.outHoles.isEmpty {
                    let outLabel = roundVM.currentRound?.frontCourseName ?? "OUT"
                    scoreSection(
                        title: outLabel,
                        holes: scoreVM.outHoles,
                        scoreVM: scoreVM,
                        parTotal: scoreVM.outParTotal,
                        totalFunc: scoreVM.outTotal
                    )
                }

                // IN 구간 (10-18홀) — 후반 코스 라벨 사용. 9홀이면 inHoles 비어있어 자동 숨김.
                if !scoreVM.inHoles.isEmpty {
                    let inLabel = roundVM.currentRound?.backCourseName ?? "IN"
                    scoreSection(
                        title: inLabel,
                        holes: scoreVM.inHoles,
                        scoreVM: scoreVM,
                        parTotal: scoreVM.inParTotal,
                        totalFunc: scoreVM.inTotal
                    )
                }

                // 합계
                if !scoreVM.players.isEmpty {
                    totalRow(scoreVM: scoreVM)
                        .padding(.horizontal, 4)
                }

                Spacer(minLength: 20)
            }
            .padding(.top, 16)
            .padding(.horizontal, 4)
        }
    }

    private func scoreSection(
        title: String,
        holes: [Int],
        scoreVM: ScoreCardViewModel,
        parTotal: Int,
        totalFunc: @escaping (UUID) -> Int
    ) -> some View {
        VStack(spacing: 0) {
            // 섹션 헤더: 홀 번호 행
            HStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.springTextSecondary)
                    .frame(width: 28, alignment: .center)
                ForEach(holes, id: \.self) { h in
                    Text("\(h)")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.springTextSecondary)
                        .frame(maxWidth: .infinity)
                }
                Text("합")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.springTextSecondary)
                    .frame(width: 28)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 4)
            .background(Color.springBorder.opacity(0.3))

            // Par 행
            HStack(spacing: 2) {
                Text("Par")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.springTextSecondary)
                    .frame(width: 28, alignment: .center)
                ForEach(holes, id: \.self) { h in
                    Text("\(scoreVM.parByHole[h] ?? 4)")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.springTextSecondary)
                        .frame(maxWidth: .infinity)
                }
                Text("\(parTotal)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.springTextSecondary)
                    .frame(width: 28)
            }
            .padding(.vertical, 3)
            .padding(.horizontal, 4)
            .background(Color.springSurfaceElevated)

            // 플레이어별 점수 행
            ForEach(scoreVM.players) { player in
                playerRow(
                    player: player,
                    holes: holes,
                    scoreVM: scoreVM,
                    sectionTotal: totalFunc(player.id)
                )
            }
        }
        .background(Color.springSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.04), radius: 1, x: 0, y: 0)
    }

    private func playerRow(
        player: Player,
        holes: [Int],
        scoreVM: ScoreCardViewModel,
        sectionTotal: Int
    ) -> some View {
        let isActive = roundVM.playerListViewModel?.activePlayer?.id == player.id
        let currentHole = roundVM.holeViewModel?.currentHoleNumber

        return HStack(spacing: 2) {
            // 플레이어 이름 (PlayerChip 읽기전용)
            Text(player.name)
                .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                .foregroundStyle(isActive ? Color.springGreenPrimary : Color.springTextPrimary)
                .lineLimit(1)
                .frame(width: 28, alignment: .center)

            // 각 홀 셀 (ScoreCell 컴포넌트 사용)
            ForEach(holes, id: \.self) { h in
                let count = scoreVM.count(holeNumber: h, playerId: player.id)
                let cat = scoreVM.scoreCategory(holeNumber: h, playerId: player.id)
                let isCurrent = h == currentHole
                let par = scoreVM.parByHole[h] ?? 4

                ScoreCell(
                    count: count,
                    category: cat,
                    isCurrentHole: isCurrent,
                    holeNumber: h,
                    playerName: player.name,
                    par: par,
                    onTap: {
                        roundVM.increment(holeNumber: h, playerId: player.id)
                        roundVM.holeViewModel?.goToHole(index: h - 1)
                        Task { await HapticEngine.shared.play(.shotIncrement) }
                    },
                    onLongPress: {
                        roundVM.decrement(holeNumber: h, playerId: player.id)
                        Task { await HapticEngine.shared.play(.shotDecrement) }
                    }
                )
            }

            // 구간 합계
            Text(sectionTotal > 0 ? "\(sectionTotal)" : "-")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.springTextPrimary)
                .frame(width: 28)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 4)
        .background(isActive ? Color.springGreenAccent.opacity(0.08) : Color.clear)
    }

    private func totalRow(scoreVM: ScoreCardViewModel) -> some View {
        VStack(spacing: 0) {
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
                    VStack(spacing: 2) {
                        Text(player.name)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.springTextSecondary)
                            .lineLimit(1)
                        let total = scoreVM.totalByPlayer[player.id] ?? 0
                        Text(total > 0 ? "\(total)" : "-")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Color.springTextPrimary)
                        if total > 0, let vsPar = scoreVM.vsParByPlayer[player.id] {
                            Text(vsParText(vsPar))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(vsParColor(vsPar))
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

    // MARK: Penalty Sheet (iphone-2.4)

    private var penaltySheet: some View {
        NavigationStack {
            ZStack {
                Color.springSurface.ignoresSafeArea()

                VStack(spacing: 16) {
                    if let holeVM = holeVM,
                       let playerVM = playerVM,
                       let activePlayer = playerVM.activePlayer {

                        Text("\(holeVM.currentHoleNumber)번 홀 · \(activePlayer.name)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.springTextPrimary)
                            .padding(.top, 8)

                        VStack(spacing: 8) {
                            PenaltyButton(variant: .ob) {
                                roundVM.tapOB(holeNumber: holeVM.currentHoleNumber, playerId: activePlayer.id)
                                Task { await HapticEngine.shared.play(.penaltyOB) }
                                showPenaltySheet = false
                            }
                            PenaltyButton(variant: .hazard) {
                                roundVM.tapHazard(holeNumber: holeVM.currentHoleNumber, playerId: activePlayer.id)
                                Task { await HapticEngine.shared.play(.penaltyHazard) }
                                showPenaltySheet = false
                            }
                            PenaltyButton(variant: .ok) {
                                roundVM.tapOK(holeNumber: holeVM.currentHoleNumber, playerId: activePlayer.id)
                                Task { await HapticEngine.shared.play(.penaltyOK) }
                                showPenaltySheet = false
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    Spacer()
                }
            }
            .navigationTitle("벌타 입력")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { showPenaltySheet = false }
                }
            }
        }
        .presentationDetents([.fraction(0.4)])
    }

    // MARK: Helpers

    private func vsParText(_ vsPar: Int) -> String {
        if vsPar == 0 { return "E" }
        return vsPar > 0 ? "+\(vsPar)" : "\(vsPar)"
    }

    private func vsParColor(_ vsPar: Int) -> Color {
        if vsPar <= -2 { return Color.springGreenPrimary }
        if vsPar < 0  { return Color.springGreenSecondary }
        if vsPar == 0 { return Color.springTextSecondary }
        if vsPar == 1 { return Color(red: 0.85, green: 0.3, blue: 0.3) }
        return Color(red: 0.7, green: 0.1, blue: 0.1)
    }
}

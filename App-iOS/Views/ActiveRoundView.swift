import SwiftUI
import Shared

// MARK: - ActiveRoundView
// iphone-2.3b: 라운드 진행 — ScoreCell.split9x2 (12-SCREENS D-1)
// 4인 × 18홀 그리드, 현재 홀 하이라이트, 셀 탭 +1 / 길게 누르기 -1
// F4 + F5 iPhone 구현

struct ActiveRoundView: View {
    @Bindable var roundVM: RoundViewModel
    @State private var showFinishConfirm = false

    private var holeVM: HoleViewModel? { roundVM.holeViewModel }
    private var scoreVM: ScoreCardViewModel? { roundVM.scoreCardViewModel }
    private var playerVM: PlayerListViewModel? { roundVM.playerListViewModel }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.springSurface.ignoresSafeArea()

                VStack(spacing: 0) {
                    // 라운드 헤더
                    roundHeader

                    // 스코어카드 (split9x2)
                    if let scoreVM = scoreVM {
                        scoreCardGrid(scoreVM: scoreVM)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
                }
                Button("취소", role: .cancel) {}
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
                    if let subName = roundVM.currentRound?.courseSubName {
                        Text(subName)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.springTextSecondary)
                    }
                }
                Spacer()
                // 현재 홀 표시
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
            .padding(.vertical, 12)

            // 홀 진행 바 (HoleProgress)
            if let holeVM = holeVM {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Color.springBorder
                        Color.springGreenPrimary
                            .frame(width: geo.size.width * CGFloat(holeVM.currentHoleNumber) / CGFloat(holeVM.totalHoles))
                    }
                }
                .frame(height: 3)
            }
        }
        .background(Color.springSurfaceElevated)
        .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
    }

    // MARK: Score Card Grid (split9x2)

    private func scoreCardGrid(scoreVM: ScoreCardViewModel) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                // OUT 구간 (1-9홀)
                if !scoreVM.outHoles.isEmpty {
                    scoreSection(
                        title: "OUT",
                        holes: scoreVM.outHoles,
                        scoreVM: scoreVM,
                        parTotal: scoreVM.outParTotal,
                        totalFunc: scoreVM.outTotal
                    )
                }

                // IN 구간 (10-18홀)
                if !scoreVM.inHoles.isEmpty {
                    scoreSection(
                        title: "IN",
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
            // 플레이어 이름
            Text(player.name)
                .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                .foregroundStyle(isActive ? Color.springGreenPrimary : Color.springTextPrimary)
                .lineLimit(1)
                .frame(width: 28, alignment: .center)

            // 각 홀 셀
            ForEach(holes, id: \.self) { h in
                let count = scoreVM.count(holeNumber: h, playerId: player.id)
                let cat = scoreVM.scoreCategory(holeNumber: h, playerId: player.id)
                let isCurrent = h == currentHole

                ScoreCellView(
                    count: count,
                    category: cat,
                    isCurrentHole: isCurrent
                )
                .onTapGesture {
                    roundVM.increment(holeNumber: h, playerId: player.id)
                    roundVM.holeViewModel?.goToHole(index: h - 1)
                }
                .onLongPressGesture(minimumDuration: 0.4) {
                    roundVM.decrement(holeNumber: h, playerId: player.id)
                }
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

// MARK: - ScoreCellView
// ScoreCell.split9x2 변형 (12-SCREENS D-1, 11-COMPONENTS §6)

private struct ScoreCellView: View {
    let count: Int
    let category: ScoreCategory
    let isCurrentHole: Bool

    var body: some View {
        ZStack {
            // par 대비 색상 배경 (11-COMPONENTS §6)
            cellBackground

            Text(count > 0 ? "\(count)" : "")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(cellForeground)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 32)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isCurrentHole ? Color.springGreenPrimary : Color.clear, lineWidth: 1.5)
        )
    }

    @ViewBuilder
    private var cellBackground: some View {
        switch category {
        case .empty:
            Color.clear
        case .eagle:
            // 진한 그린 원형 (D-4: --green-primary 동그라미)
            Circle()
                .fill(Color.springGreenPrimary)
                .padding(2)
        case .birdie:
            // 연한 그린 원형
            Circle()
                .fill(Color.springGreenSecondary.opacity(0.5))
                .padding(2)
        case .par:
            Color.clear
        case .bogey:
            // 연한 적색 사각형 (D-4: --text-secondary 사각형)
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(red: 0.95, green: 0.87, blue: 0.87))
                .padding(2)
        case .doublePlus:
            // 진한 적색 사각형
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(red: 0.95, green: 0.78, blue: 0.78))
                .padding(2)
        }
    }

    private var cellForeground: Color {
        switch category {
        case .eagle: return Color.springTextPrimary
        case .birdie: return Color.springTextPrimary
        default: return Color.springTextPrimary
        }
    }
}

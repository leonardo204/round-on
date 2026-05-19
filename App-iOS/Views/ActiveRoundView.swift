import SwiftUI
import Shared

// MARK: - ActiveRoundView
// iphone-2.3b: 라운드 진행 — ScoreCell.split9x2 (12-SCREENS D-1)
// 4인 × 18홀 그리드, 현재 홀 하이라이트, 셀 탭 +1 / 길게 누르기 -1
// F4 + F5 iPhone 구현

struct ActiveRoundView: View {
    @Bindable var roundVM: RoundViewModel
    @State private var showFinishConfirm = false
    @State private var showDiscardConfirm = false
    @State private var showPenaltySheet = false
    @State private var bannerMessage: String?
    @State private var prefillToastMessage: String?

    // 10홀 진입 시 잠정 코스 확인 팝업
    @State private var showBackCoursePrompt = false
    @State private var backCoursePrompted = false
    // 코스 변경 sheet (후반 잠정 확인 → 수정 경로)
    @State private var showCourseChangeSheet = false

    @AppStorage(PenaltySettings.Key.activeRoundMode) private var activeMode: String = PenaltySettings.Default.activeRoundMode
    @AppStorage(PenaltySettings.Key.obDelta) private var obDelta: Int = PenaltySettings.Default.obDelta
    @AppStorage(PenaltySettings.Key.hazardDelta) private var hazardDelta: Int = PenaltySettings.Default.hazardDelta
    @AppStorage(PenaltySettings.Key.okDelta) private var okDelta: Int = PenaltySettings.Default.okDelta

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

                    // 모드 토글 (보기 / 입력)
                    modeToggle
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    // 모드 분기
                    if activeMode == "holeInput", let scoreVM = scoreVM, let holeVM = holeVM, let playerVM = playerVM {
                        holeInputView(scoreVM: scoreVM, holeVM: holeVM, playerVM: playerVM)
                    } else if let scoreVM = scoreVM {
                        scoreCardGrid(scoreVM: scoreVM)
                    }
                }

                // par prefill 토스트 (라운드 시작 직후 1.5초)
                if let msg = prefillToastMessage {
                    VStack {
                        Spacer()
                        Text(msg)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.springTextPrimary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.springSurfaceElevated)
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
                            .padding(.bottom, 40)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .animation(.easeInOut(duration: 0.25), value: prefillToastMessage)
                }
            }
            .onChange(of: roundVM.lastPrefillToastMessage) { _, newMsg in
                guard let msg = newMsg else { return }
                withAnimation { prefillToastMessage = msg }
                roundVM.lastPrefillToastMessage = nil
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    withAnimation { prefillToastMessage = nil }
                }
            }
            .onChange(of: holeVM?.currentHoleNumber) { _, newHole in
                // 10홀 첫 진입 시 잠정 코스 확인 팝업 (1회만)
                guard let hole = newHole, hole == 10,
                      roundVM.currentRound?.isBackTentative == true,
                      !backCoursePrompted else { return }
                showBackCoursePrompt = true
            }
            .alert("후반 코스 확인", isPresented: $showBackCoursePrompt) {
                Button("맞아요") {
                    roundVM.confirmBackCourse()
                    backCoursePrompted = true
                }
                Button("수정할게요") {
                    backCoursePrompted = true
                    showCourseChangeSheet = true
                }
            } message: {
                if let back = roundVM.currentRound?.backCourseName {
                    Text("후반 코스가 '\(back)'(으)로 설정되어 있어요. 이 코스가 맞나요?")
                } else {
                    Text("후반 코스를 확인해주세요.")
                }
            }
            .sheet(isPresented: $showCourseChangeSheet) {
                backCourseChangeSheet
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showPenaltySheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.bubble.fill")
                                .font(.system(size: 13))
                            Text("벌타")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundStyle(Color.springGreenPrimary)
                    }
                    .accessibilityLabel("벌타 입력 — OB, 해저드, OK 컨시드")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("종료") {
                        showFinishConfirm = true
                    }
                    .foregroundStyle(.red)
                }
            }
            .confirmationDialog(
                "라운드를 종료할까요?",
                isPresented: $showFinishConfirm,
                titleVisibility: .visible
            ) {
                Button("저장하고 종료") {
                    roundVM.finishRound()
                    Task { await HapticEngine.shared.play(.roundEnd) }
                }
                Button("라운드 폐기", role: .destructive) {
                    showDiscardConfirm = true
                }
                Button("취소", role: .cancel) { }
            } message: {
                Text("저장하면 기록이 보관되고, 폐기하면 라운드와 스코어가 영구 삭제됩니다.")
            }
            .confirmationDialog(
                "정말 폐기할까요?",
                isPresented: $showDiscardConfirm,
                titleVisibility: .visible
            ) {
                Button("폐기", role: .destructive) {
                    roundVM.discardRound()
                    Task { await HapticEngine.shared.play(.roundEnd) }
                }
                Button("취소", role: .cancel) { }
            } message: {
                Text("이 라운드와 모든 스코어가 영구 삭제됩니다. 되돌릴 수 없습니다.")
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
                    // 후반 잠정 badge 또는 일반 서브라벨
                    if roundVM.currentRound?.isBackTentative == true,
                       let backName = roundVM.currentRound?.backCourseName {
                        HStack(spacing: 4) {
                            if let front = roundVM.currentRound?.frontCourseName {
                                Text(front)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.springTextSecondary)
                                Text("/")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.springTextSecondary)
                            }
                            Text("잠정: \(backName)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    } else if let subLabel = roundVM.currentRound?.displaySubLabel {
                        Text(subLabel)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.springTextSecondary)
                    }
                }
                Spacer()
                // 코스 변경 menu (CourseParsCatalog 등록 골프장만 활성)
                if let courseId = roundVM.currentRound?.courseId {
                    let subs = CourseParsCatalog.subCourseNames(for: courseId)
                    if subs.count >= 2 {
                        Menu {
                            Section("전반 코스 변경") {
                                ForEach(subs, id: \.self) { name in
                                    Button(name) {
                                        roundVM.changeSubCourse(half: .front, to: name)
                                    }
                                }
                            }
                            if roundVM.currentRound?.holeList.count == 18 {
                                Section("후반 코스 변경") {
                                    ForEach(subs, id: \.self) { name in
                                        Button(name) {
                                            roundVM.changeSubCourse(half: .back, to: name)
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "square.and.pencil")
                                    .font(.system(size: 12))
                                Text("코스 수정")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundStyle(Color.springGreenPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .overlay(
                                Capsule().stroke(Color.springGreenPrimary.opacity(0.6), lineWidth: 1)
                            )
                        }
                        .accessibilityLabel("코스 수정")
                    }
                }
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
                // 전반 (1-9홀) — 코스 라벨이 있으면 그것 우선, 없으면 "전반"
                if !scoreVM.outHoles.isEmpty {
                    let outLabel = roundVM.currentRound?.frontCourseName ?? "전반"
                    scoreSection(
                        title: outLabel,
                        holes: scoreVM.outHoles,
                        scoreVM: scoreVM,
                        parTotal: scoreVM.outParTotal,
                        totalFunc: scoreVM.outTotal
                    )
                }

                // 후반 (10-18홀) — 코스 라벨이 있으면 그것 우선, 없으면 "후반". 9홀이면 자동 숨김.
                if !scoreVM.inHoles.isEmpty {
                    let inLabel = roundVM.currentRound?.backCourseName ?? "후반"
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
                    .frame(width: 28)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 4)
            .background(Color.springBorder.opacity(0.3))

            // Par 행 — 각 셀 long press(또는 tap)로 3/4/5 선택
            HStack(spacing: 2) {
                Text("Par")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.springTextSecondary)
                    .frame(width: 44, alignment: .center)
                ForEach(holes, id: \.self) { h in
                    parCell(holeNumber: h, par: scoreVM.parByHole[h] ?? 4)
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
            // 플레이어 이름 — 동반자명 잘림 방지 위해 폭 확대 + 약어 처리
            Text(playerShortName(player.name))
                .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                .foregroundStyle(isActive ? Color.springGreenPrimary : Color.springTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 44, alignment: .center)

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
                        let ok = roundVM.increment(holeNumber: h, playerId: player.id)
                        roundVM.holeViewModel?.goToHole(index: h - 1)
                        if ok {
                            Task { await HapticEngine.shared.play(.shotIncrement) }
                        } else {
                            bannerMessage = "double par(\(par * 2)) 이상은 입력할 수 없어요."
                            Task { await HapticEngine.shared.play(.penaltyOB) }
                        }
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

    // MARK: Back Course Change Sheet (잠정 코스 수정용)

    @ViewBuilder
    private var backCourseChangeSheet: some View {
        if let round = roundVM.currentRound {
            let courseId = round.courseId
            let subs = CourseParsCatalog.subCourseNames(for: courseId)
            NavigationStack {
                List {
                    Section("후반 코스 선택") {
                        ForEach(subs, id: \.self) { name in
                            let isCurrent = round.backCourseName == name
                            Button {
                                roundVM.changeSubCourse(half: .back, to: name)
                                showCourseChangeSheet = false
                            } label: {
                                HStack {
                                    Text(name)
                                        .foregroundStyle(isCurrent ? Color.springGreenPrimary : Color.springTextPrimary)
                                    Spacer()
                                    if isCurrent {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Color.springGreenPrimary)
                                    }
                                }
                            }
                        }
                    }
                }
                .navigationTitle("후반 코스 수정")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("취소") { showCourseChangeSheet = false }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    // MARK: Mode toggle (보기 / 입력)

    private var modeToggle: some View {
        Picker("모드", selection: $activeMode) {
            Text("📋 보기").tag("scoreboard")
            Text("⊕ 입력").tag("holeInput")
        }
        .pickerStyle(.segmented)
    }

    // MARK: Hole Input Mode (옵션 B 다듬은 버전)

    private func holeInputView(scoreVM: ScoreCardViewModel, holeVM: HoleViewModel, playerVM: PlayerListViewModel) -> some View {
        let activePlayer = playerVM.activePlayer ?? scoreVM.players.first
        let currentHole = holeVM.currentHoleNumber
        let par = scoreVM.parByHole[currentHole] ?? 4
        let count = activePlayer.map { scoreVM.count(holeNumber: currentHole, playerId: $0.id) } ?? 0

        return VStack(spacing: 0) {
            // 홀 헤더
            holeHeader(currentHole: currentHole, totalHoles: holeVM.totalHoles, par: par)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 12)

            // 동반자 4인 탭
            playerTabs(scoreVM: scoreVM, playerVM: playerVM, currentHole: currentHole)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

            // 메인 입력 카드
            if let player = activePlayer {
                inputMainCard(player: player, count: count, par: par, currentHole: currentHole)
                    .padding(.horizontal, 16)
            }

            Spacer(minLength: 0)

            // 하단 홀 네비
            holeNavBar(holeVM: holeVM)
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
        }
    }

    private func holeHeader(currentHole: Int, totalHoles: Int, par: Int) -> some View {
        HStack(alignment: .firstTextBaseline) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(currentHole)")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(Color.springGreenPrimary)
                Text("번 홀")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.springTextSecondary)
                Text("· \(currentHole) / \(totalHoles)")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.springTextSecondary)
            }
            Spacer()
            Menu {
                ForEach([3, 4, 5], id: \.self) { p in
                    Button("Par \(p)") {
                        roundVM.setPar(holeNumber: currentHole, par: p)
                        Task { await HapticEngine.shared.play(.shotIncrement) }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Par \(par)")
                        .font(.system(size: 13, weight: .semibold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9))
                }
                .foregroundStyle(Color.springGreenPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.springGreenPrimary.opacity(0.10), in: Capsule())
            }
        }
    }

    private func playerTabs(scoreVM: ScoreCardViewModel, playerVM: PlayerListViewModel, currentHole: Int) -> some View {
        HStack(spacing: 6) {
            ForEach(scoreVM.players) { player in
                let isActive = playerVM.activePlayer?.id == player.id
                let score = scoreVM.count(holeNumber: currentHole, playerId: player.id)
                Button {
                    playerVM.activate(player: player)
                } label: {
                    VStack(spacing: 2) {
                        Text(playerShortName(player.name))
                            .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(score > 0 ? "\(score)" : "−")
                            .font(.system(size: 14, weight: .bold))
                            .monospacedDigit()
                    }
                    .foregroundStyle(isActive ? Color.white : Color.springTextSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(isActive ? Color.springGreenPrimary : Color(.systemFill),
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .shadow(color: isActive ? Color.springGreenPrimary.opacity(0.25) : .clear, radius: 4, y: 2)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func inputMainCard(player: Player, count: Int, par: Int, currentHole: Int) -> some View {
        VStack(spacing: 12) {
            // - 숫자 + 행
            HStack(spacing: 12) {
                counterButton(symbol: "−", style: .minus) {
                    roundVM.decrement(holeNumber: currentHole, playerId: player.id)
                    Task { await HapticEngine.shared.play(.shotDecrement) }
                }

                VStack(spacing: 4) {
                    Text(count > 0 ? "\(count)" : "0")
                        .font(.system(size: 92, weight: .heavy))
                        .foregroundStyle(Color.springTextPrimary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(parDiffCaption(count: count, par: par))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.springTextSecondary)
                }
                .frame(maxWidth: .infinity)

                counterButton(symbol: "+", style: .plus) {
                    let ok = roundVM.increment(holeNumber: currentHole, playerId: player.id)
                    if ok {
                        Task { await HapticEngine.shared.play(.shotIncrement) }
                    } else {
                        bannerMessage = "double par(\(par * 2)) 이상은 입력할 수 없어요."
                        Task { await HapticEngine.shared.play(.penaltyOB) }
                    }
                }
            }

            // 벌타 3종
            HStack(spacing: 8) {
                penaltyBigButton(label: "OB", icon: "flag", delta: obDelta, tint: Color(red: 0.76, green: 0.15, blue: 0.15)) {
                    let ok = roundVM.tapOB(holeNumber: currentHole, playerId: player.id)
                    handlePenaltyResult(ok: ok, par: par, haptic: .penaltyOB)
                }
                penaltyBigButton(label: "해저드", icon: "drop.fill", delta: hazardDelta, tint: Color(red: 0.08, green: 0.40, blue: 0.75)) {
                    let ok = roundVM.tapHazard(holeNumber: currentHole, playerId: player.id)
                    handlePenaltyResult(ok: ok, par: par, haptic: .penaltyHazard)
                }
                penaltyBigButton(label: "컨시드", icon: "checkmark.circle.fill", delta: okDelta, tint: Color.springGreenPrimary) {
                    let ok = roundVM.tapOK(holeNumber: currentHole, playerId: player.id)
                    handlePenaltyResult(ok: ok, par: par, haptic: .penaltyOK)
                }
            }
        }
        .padding(20)
        .background(Color.springSurfaceElevated, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    private enum CounterStyle { case minus, plus }

    private func counterButton(symbol: String, style: CounterStyle, action: @escaping () -> Void) -> some View {
        let bgColor: Color = (style == .plus) ? Color.springGreenPrimary : Color(.systemFill)
        let fgColor: Color = (style == .plus) ? .white : Color.springTextPrimary
        return Button(action: action) {
            Text(symbol)
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(fgColor)
                .frame(width: 76, height: 76)
                .background(bgColor, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: style == .plus ? Color.springGreenPrimary.opacity(0.3) : .clear, radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(style == .plus ? "타수 +1" : "타수 −1")
    }

    private func penaltyBigButton(label: String, icon: String, delta: Int, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                Text("+\(delta)")
                    .font(.system(size: 11, weight: .medium))
                    .opacity(0.75)
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label) +\(delta)")
    }

    private func holeNavBar(holeVM: HoleViewModel) -> some View {
        let isFirst = holeVM.currentHoleNumber <= 1
        let isLast = holeVM.currentHoleNumber >= holeVM.totalHoles
        return HStack {
            Button {
                holeVM.previousHole()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("\(max(1, holeVM.currentHoleNumber - 1))번 홀")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isFirst ? Color.springTextSecondary : Color.springTextPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.springSurfaceElevated, in: RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isFirst)
            .buttonStyle(.plain)

            Spacer()

            Button {
                holeVM.nextHole()
            } label: {
                HStack(spacing: 4) {
                    Text("\(min(holeVM.totalHoles, holeVM.currentHoleNumber + 1))번 홀")
                    Image(systemName: "chevron.right")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isLast ? Color.springTextSecondary : Color.springGreenPrimary,
                            in: RoundedRectangle(cornerRadius: 12))
                .shadow(color: isLast ? .clear : Color.springGreenPrimary.opacity(0.3), radius: 6, y: 2)
            }
            .disabled(isLast)
            .buttonStyle(.plain)
        }
    }

    private func parDiffCaption(count: Int, par: Int) -> String {
        guard count > 0 else { return "Par \(par)" }
        let diff = count - par
        if diff == 0 { return "Par \(par) · E" }
        if diff > 0 { return "Par \(par) · +\(diff)" }
        return "Par \(par) · \(diff)"
    }

    private func handlePenaltyResult(ok: Bool, par: Int, haptic: HapticEngine.Event) {
        if ok {
            Task { await HapticEngine.shared.play(haptic) }
        } else {
            bannerMessage = "double par(\(par * 2)) 초과 — 더 추가할 수 없어요."
            Task { await HapticEngine.shared.play(.penaltyOB) }
        }
    }

    // MARK: Helpers

    /// Par 셀: tap → menu(3/4/5)로 즉시 변경
    private func parCell(holeNumber: Int, par: Int) -> some View {
        Menu {
            ForEach([3, 4, 5], id: \.self) { p in
                Button("Par \(p)") {
                    roundVM.setPar(holeNumber: holeNumber, par: p)
                    Task { await HapticEngine.shared.play(.shotIncrement) }
                }
            }
        } label: {
            Text("\(par)")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.springTextSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 22)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("\(holeNumber)번 홀 Par, 현재 \(par). 탭하여 변경.")
    }

    /// 동반자 이름이 길면 약어로 표시 — "동반자1" → "동1", "동반자2" → "동2"
    private func playerShortName(_ name: String) -> String {
        if name.hasPrefix("동반자"), name.count <= 5 {
            let suffix = name.dropFirst(3)
            return "동\(suffix)"
        }
        return name
    }
}

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
    /// double par 차단 등 일회성 알림 토스트 (1.5초 자동 사라짐)
    @State private var blockToast: String?
    /// 홀 완료 멘트 (3초 자동 사라짐)
    @State private var holeResultMessage: String?
    /// 잠금 해제 확인 alert — 해제할 홀 번호
    @State private var unlockHoleNumber: Int?

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

                // 차단 알림 토스트 (double par 초과 등, 1.5초 자동 사라짐)
                if let msg = blockToast {
                    VStack {
                        Spacer()
                        Text(msg)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color(red: 0.6, green: 0.3, blue: 0.1).opacity(0.92))
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
                            .padding(.bottom, prefillToastMessage != nil ? 84 : 40)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .animation(.easeInOut(duration: 0.25), value: blockToast)
                }

                // 홀 결과 멘트 banner (상단, 3초 자동 사라짐)
                if let msg = holeResultMessage {
                    VStack {
                        Text(msg)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.springTextPrimary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.springSurfaceElevated)
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)
                            .padding(.top, 8)
                        Spacer()
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .animation(.easeInOut(duration: 0.25), value: holeResultMessage)
                }
            }
            .onChange(of: roundVM.lastHoleMessage) { _, newMsg in
                guard let msg = newMsg else {
                    withAnimation { holeResultMessage = nil }
                    return
                }
                withAnimation { holeResultMessage = msg }
            }
            .alert("이전 홀 수정", isPresented: Binding(
                get: { unlockHoleNumber != nil },
                set: { if !$0 { unlockHoleNumber = nil } }
            )) {
                Button("수정") {
                    if let h = unlockHoleNumber {
                        roundVM.unlockHole(h)
                    }
                    unlockHoleNumber = nil
                }
                Button("취소", role: .cancel) {
                    unlockHoleNumber = nil
                }
            } message: {
                if let h = unlockHoleNumber {
                    Text("\(h)번 홀 잠금을 해제하면 다시 수정할 수 있어요.")
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

    // MARK: Score Card Grid (split9x2) — HoleScoreGrid 위임

    private func scoreCardGrid(scoreVM: ScoreCardViewModel) -> some View {
        ScrollView {
            HoleScoreGrid(
                scoreVM: scoreVM,
                interactive: true,
                currentHoleNumber: roundVM.holeViewModel?.currentHoleNumber,
                onParChange: { holeNumber, newPar in
                    // 잠긴 홀 par 변경 차단
                    let isLocked = roundVM.currentRound?.holeList.first(where: { $0.holeNumber == holeNumber })?.isLocked ?? false
                    guard !isLocked else {
                        unlockHoleNumber = holeNumber
                        return
                    }
                    roundVM.setPar(holeNumber: holeNumber, par: newPar)
                    Task { await HapticEngine.shared.play(.shotIncrement) }
                },
                onScoreTap: { holeNumber, playerId in
                    let isLocked = roundVM.currentRound?.holeList.first(where: { $0.holeNumber == holeNumber })?.isLocked ?? false
                    if isLocked {
                        unlockHoleNumber = holeNumber
                        return
                    }
                    let ok = roundVM.increment(holeNumber: holeNumber, playerId: playerId)
                    roundVM.holeViewModel?.goToHole(index: holeNumber - 1)
                    if ok {
                        Task { await HapticEngine.shared.play(.shotIncrement) }
                    } else {
                        showBlockToast("더 추가할 수 없어요 (double par)")
                        Task { await HapticEngine.shared.play(.penaltyOB) }
                    }
                },
                onScoreLongPress: { holeNumber, playerId in
                    let isLocked = roundVM.currentRound?.holeList.first(where: { $0.holeNumber == holeNumber })?.isLocked ?? false
                    if isLocked {
                        unlockHoleNumber = holeNumber
                        return
                    }
                    roundVM.decrement(holeNumber: holeNumber, playerId: playerId)
                    Task { await HapticEngine.shared.play(.shotDecrement) }
                },
                frontLabel: roundVM.currentRound?.frontCourseName,
                backLabel: roundVM.currentRound?.backCourseName
            )
            Spacer(minLength: 20)
        }
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

                        // 2x2 그리드 레이아웃 (OB/해저드/컨시드/더블파)
                        VStack(spacing: 8) {
                            HStack(spacing: 8) {
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
                            }
                            HStack(spacing: 8) {
                                PenaltyButton(variant: .ok) {
                                    roundVM.tapOK(holeNumber: holeVM.currentHoleNumber, playerId: activePlayer.id)
                                    Task { await HapticEngine.shared.play(.penaltyOK) }
                                    showPenaltySheet = false
                                }
                                PenaltyButton(variant: .doublePar) {
                                    roundVM.setToDoublePar(holeNumber: holeVM.currentHoleNumber, playerId: activePlayer.id)
                                    Task { await HapticEngine.shared.play(.penaltyOB) }
                                    showPenaltySheet = false
                                }
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
        .presentationDetents([.fraction(0.48)])
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
        let isCurrentHoleLocked = roundVM.currentRound?.holeList.first(where: { $0.holeNumber == currentHole })?.isLocked ?? false

        return VStack(spacing: 0) {
            // 홀 헤더 + 잠금 배지
            HStack(spacing: 8) {
                holeHeader(currentHole: currentHole, totalHoles: holeVM.totalHoles, par: par)
                if isCurrentHoleLocked {
                    Button {
                        unlockHoleNumber = currentHole
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 11))
                            Text("잠김")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(Color.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.orange.opacity(0.15), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 12)

            // 동반자 4인 탭
            playerTabs(scoreVM: scoreVM, playerVM: playerVM, currentHole: currentHole)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

            // 메인 입력 카드
            if let player = activePlayer {
                inputMainCard(player: player, count: count, par: par, currentHole: currentHole, isLocked: isCurrentHoleLocked)
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

    private func inputMainCard(player: Player, count: Int, par: Int, currentHole: Int, isLocked: Bool = false) -> some View {
        VStack(spacing: 12) {
            // - 숫자 + 행
            HStack(spacing: 12) {
                counterButton(symbol: "−", style: .minus) {
                    if isLocked { unlockHoleNumber = currentHole; return }
                    roundVM.decrement(holeNumber: currentHole, playerId: player.id)
                    Task { await HapticEngine.shared.play(.shotDecrement) }
                }
                .disabled(isLocked)

                VStack(spacing: 4) {
                    Text(count > 0 ? "\(count)" : "0")
                        .font(.system(size: 92, weight: .heavy))
                        .foregroundStyle(isLocked ? Color.springTextSecondary : Color.springTextPrimary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(parDiffCaption(count: count, par: par))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.springTextSecondary)
                }
                .frame(maxWidth: .infinity)

                counterButton(symbol: "+", style: .plus) {
                    if isLocked { unlockHoleNumber = currentHole; return }
                    let ok = roundVM.increment(holeNumber: currentHole, playerId: player.id)
                    if ok {
                        Task { await HapticEngine.shared.play(.shotIncrement) }
                    } else {
                        showBlockToast("더 추가할 수 없어요 (double par)")
                        Task { await HapticEngine.shared.play(.penaltyOB) }
                    }
                }
                .disabled(isLocked)
            }

            // 벌타 2x2 그리드 (OB / 해저드 / 컨시드 / 더블파)
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    penaltyBigButton(label: "OB", icon: "exclamationmark.triangle.fill", delta: obDelta, tint: Color(red: 0.76, green: 0.15, blue: 0.15)) {
                        if isLocked { unlockHoleNumber = currentHole; return }
                        let ok = roundVM.tapOB(holeNumber: currentHole, playerId: player.id)
                        handlePenaltyResult(ok: ok, par: par, haptic: .penaltyOB)
                    }
                    .disabled(isLocked)
                    penaltyBigButton(label: "해저드", icon: "water.waves", delta: hazardDelta, tint: Color(red: 0.08, green: 0.40, blue: 0.75)) {
                        if isLocked { unlockHoleNumber = currentHole; return }
                        let ok = roundVM.tapHazard(holeNumber: currentHole, playerId: player.id)
                        handlePenaltyResult(ok: ok, par: par, haptic: .penaltyHazard)
                    }
                    .disabled(isLocked)
                }
                HStack(spacing: 8) {
                    penaltyBigButton(label: "컨시드", icon: "checkmark.circle.fill", delta: okDelta, tint: Color.springGreenPrimary) {
                        if isLocked { unlockHoleNumber = currentHole; return }
                        let ok = roundVM.tapOK(holeNumber: currentHole, playerId: player.id)
                        handlePenaltyResult(ok: ok, par: par, haptic: .penaltyOK)
                    }
                    .disabled(isLocked)
                    doubleParBigButton(par: par) {
                        if isLocked { unlockHoleNumber = currentHole; return }
                        roundVM.setToDoublePar(holeNumber: currentHole, playerId: player.id)
                        Task { await HapticEngine.shared.play(.penaltyOB) }
                    }
                    .disabled(isLocked)
                }
            }
        }
        .padding(20)
        .background(Color.springSurfaceElevated, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        .overlay(alignment: .topLeading) {
            if isLocked {
                // 잠긴 홀 dim 오버레이
                Color.black.opacity(0.04)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .allowsHitTesting(false)
            }
        }
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

    private func doubleParBigButton(par: Int, action: @escaping () -> Void) -> some View {
        let tint = Color(red: 0.62, green: 0.40, blue: 0.12)
        return Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: "2.square.fill")
                    .font(.system(size: 18))
                Text("더블파")
                    .font(.system(size: 13, weight: .semibold))
                Text("par×2 (\(par * 2))")
                    .font(.system(size: 11, weight: .medium))
                    .opacity(0.75)
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("더블파 par\(par)의 2배 \(par * 2)로 설정")
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

            if isLast {
                // 마지막 홀에서 종료 버튼 노출
                Button {
                    showFinishConfirm = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "flag.checkered")
                        Text("종료")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.red, in: RoundedRectangle(cornerRadius: 12))
                    .shadow(color: Color.red.opacity(0.3), radius: 6, y: 2)
                }
                .buttonStyle(.plain)
            } else {
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
                    .background(Color.springGreenPrimary, in: RoundedRectangle(cornerRadius: 12))
                    .shadow(color: Color.springGreenPrimary.opacity(0.3), radius: 6, y: 2)
                }
                .buttonStyle(.plain)
            }
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
            showBlockToast("더 추가할 수 없어요 (double par)")
            Task { await HapticEngine.shared.play(.penaltyOB) }
        }
    }

    private func showBlockToast(_ message: String) {
        withAnimation { blockToast = message }
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation { blockToast = nil }
        }
    }

    // MARK: Helpers

    /// 동반자 이름이 길면 약어로 표시 — "동반자1" → "동1", "동반자2" → "동2"
    private func playerShortName(_ name: String) -> String {
        if name.hasPrefix("동반자"), name.count <= 5 {
            let suffix = name.dropFirst(3)
            return "동\(suffix)"
        }
        return name
    }
}

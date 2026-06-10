import SwiftUI
import Shared

// MARK: - WatchHoleSwipeContainer
// Watch 메인: 세로 2페이지(위=홀 입력, 아래=컨트롤) — watchOS 10 운동 앱 구조.
//  · 위 페이지(verticalPage 0): 좌우 swipe로 홀 이동 + 각 페이지는 '나'(owner) 전용 입력 UI
//  · 아래 페이지(verticalPage 1): 라운드 종료 + 워크아웃 멈춤/재개 컨트롤
// 어느 홀에서든 아래로 스와이프하면 컨트롤 즉시 도달 (좌측 단일 컨트롤 페이지 폐기).
// 동반자 입력은 iPhone에서만 가능.
// 12-SCREENS watch-3.2 (세로 페이징)

struct WatchHoleSwipeContainer: View {

    @Bindable var roundVM: RoundViewModel
    @State private var holeMessageVisible: Bool = false

    /// 세로 외곽 TabView 선택 상태. 0 = 홀 입력(위), 1 = 컨트롤(아래).
    @State private var verticalPage: Int = 0

    var body: some View {
        guard let holeVM = roundVM.holeViewModel else {
            return AnyView(Text("라운드 없음").foregroundStyle(.secondary))
        }

        // 가로(홀) selection 바인딩 — currentHoleIndex가 private(set)이므로
        // get은 현재 홀, set은 goToHole + 햅틱으로 복원(직전 작업 이전 패턴).
        // iPhone 원격 홀 변경은 get이 currentHoleIndex를 반영하므로 자연 동기화.
        let holeSelection = Binding<Int>(
            get: { holeVM.currentHoleIndex },
            set: { newIndex in
                let prevHole = holeVM.currentHoleIndex
                holeVM.goToHole(index: newIndex)
                if newIndex != prevHole {
                    Task { await HapticEngine.shared.play(.holeManualChange) }
                }
            }
        )

        return AnyView(
            TabView(selection: $verticalPage) {
                // 위 페이지(tag 0): 기존 가로 홀 스와이프 + 홀 결과 멘트 오버레이
                ZStack(alignment: .top) {
                    TabView(selection: holeSelection) {
                        ForEach(0..<holeVM.totalHoles, id: \.self) { holeIdx in
                            holePage(holeNumber: holeIdx + 1, holeVM: holeVM)
                                .tag(holeIdx)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .automatic))

                    // 하단 중앙 힌트 — 위 페이지(verticalPage 0)에서만 표시. "↓ 컨트롤" 미니멀.
                    // 가로 페이지 dot과 겹치지 않도록 dot 위쪽에 배치(비대화형).
                    if verticalPage == 0 {
                        VStack {
                            Spacer()
                            HStack(spacing: 2) {
                                Image(systemName: "chevron.compact.down")
                                    .font(.system(size: 10, weight: .semibold))
                                Text("컨트롤")
                                    .font(.system(size: 9))
                            }
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 12)
                        }
                        .allowsHitTesting(false)
                        .transition(.opacity)
                        .zIndex(2)
                    }

                    // 홀 결과 멘트 — 3초 자동 사라짐
                    if holeMessageVisible, let msg = roundVM.lastHoleMessage {
                        Text(msg)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 10))
                            .padding(.top, 4)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                            .zIndex(1)
                    }
                }
                .tag(0)

                // 아래 페이지(tag 1): 컨트롤 (종료 + 워크아웃 멈춤/재개)
                WatchRoundControlPage(roundVM: roundVM)
                    .tag(1)
            }
            .tabViewStyle(.verticalPage)
            .onChange(of: roundVM.lastHoleMessage) { _, newMsg in
                if newMsg != nil {
                    withAnimation(.easeIn(duration: 0.2)) { holeMessageVisible = true }
                } else {
                    withAnimation(.easeOut(duration: 0.3)) { holeMessageVisible = false }
                }
            }
        )
    }

    // MARK: - Owner 전용 홀 페이지

    private func holePage(holeNumber: Int, holeVM: HoleViewModel) -> some View {
        Group {
            if let scoreVM = roundVM.scoreCardViewModel,
               let owner = scoreVM.players.first(where: { $0.isOwner }) {
                ownerHoleContent(
                    holeNumber: holeNumber,
                    totalHoles: holeVM.totalHoles,
                    owner: owner,
                    scoreVM: scoreVM
                )
            } else {
                Text("플레이어 없음")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func ownerHoleContent(
        holeNumber: Int,
        totalHoles: Int,
        owner: Player,
        scoreVM: ScoreCardViewModel
    ) -> some View {
        OwnerHoleContentView(
            holeNumber: holeNumber,
            totalHoles: totalHoles,
            owner: owner,
            scoreVM: scoreVM,
            roundVM: roundVM
        )
    }
}

// MARK: - OwnerHoleContentView (코스 picker sheet 지원)

private struct OwnerHoleContentView: View {
    let holeNumber: Int
    let totalHoles: Int
    let owner: Player
    let scoreVM: ScoreCardViewModel
    @Bindable var roundVM: RoundViewModel

    @State private var showCoursePicker: Bool = false
    @State private var showUnlockAlert: Bool = false

    var body: some View {
        let count = scoreVM.count(holeNumber: holeNumber, playerId: owner.id)
        let par = scoreVM.parByHole[holeNumber] ?? 4
        let isLocked = roundVM.currentRound?.holeList.first(where: { $0.holeNumber == holeNumber })?.isLocked ?? false

        return VStack(spacing: 6) {
            // 헤더: 홀 번호 + Par badge (탭 cycle) + 진행 N/총홀 + 잠금 아이콘
            HStack(spacing: 6) {
                Text("\(holeNumber)번")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)

                if isLocked {
                    // 잠긴 홀: Par 탭 대신 자물쇠 아이콘 표시
                    Button {
                        showUnlockAlert = true
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10))
                            Text("잠김")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(Color.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.20), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("잠긴 홀. 탭하여 잠금 해제")
                } else {
                    Button {
                        let next: Int = (par == 3 ? 4 : (par == 4 ? 5 : 3))
                        roundVM.setPar(holeNumber: holeNumber, par: next)
                        Task { await HapticEngine.shared.play(.shotIncrement) }
                    } label: {
                        Text("Par \(par)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.18), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Par \(par). 탭하여 \(par == 3 ? 4 : (par == 4 ? 5 : 3))로 변경")
                }

                // 코스 수정 버튼 — 잠긴 홀에서는 숨김
                if !isLocked, let round = roundVM.currentRound {
                    let subs = CourseParsCatalog.subCourseNames(for: round.courseId)
                    if subs.count >= 2 {
                        let isBack = holeNumber > 9
                        let cur = isBack ? round.backCourseName : round.frontCourseName
                        let isTentative = isBack && round.isBackTentative
                        Button {
                            showCoursePicker = true
                        } label: {
                            Text(isTentative ? "잠정: \(cur ?? "-")" : (cur ?? "코스 수정"))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(isTentative ? Color.orange : .white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(isTentative ? Color.orange.opacity(0.25) : Color.green, in: Capsule())
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(isTentative ? "잠정 코스 수정. 현재: \(cur ?? "미선택")" : "코스 수정. 현재: \(cur ?? "미선택")")
                        .sheet(isPresented: $showCoursePicker) {
                            CoursePickerSheet(
                                round: round,
                                subs: subs,
                                currentHoleNumber: holeNumber,
                                roundVM: roundVM,
                                isPresented: $showCoursePicker
                            )
                        }
                    }
                }

                Spacer()

                Text("\(holeNumber)/\(totalHoles)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 6)
            .padding(.top, 2)

            // 메인: 좌[−] / 숫자 / 우[＋] — 잠긴 홀은 버튼 비활성 + 회색 처리
            HStack(spacing: 6) {
                counterButton(symbol: "−", isPrimary: false, disabled: isLocked) {
                    roundVM.decrement(holeNumber: holeNumber, playerId: owner.id)
                    Task { await HapticEngine.shared.play(.shotDecrement) }
                }
                VStack(spacing: 2) {
                    Text(count > 0 ? "\(count)" : "0")
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(isLocked ? .secondary : .primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(parDiffCaption(count: count, par: par))
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                counterButton(symbol: "+", isPrimary: true, disabled: isLocked) {
                    roundVM.increment(holeNumber: holeNumber, playerId: owner.id)
                    Task { await HapticEngine.shared.play(.shotIncrement) }
                }
            }
            .padding(.horizontal, 4)

            // 벌타 3종 — 잠긴 홀은 비활성
            HStack(spacing: 4) {
                WatchPenaltyButton(variant: .ob) {
                    if !isLocked {
                        roundVM.tapOB(holeNumber: holeNumber, playerId: owner.id)
                        Task { await HapticEngine.shared.play(.penaltyOB) }
                    }
                }
                .disabled(isLocked)
                WatchPenaltyButton(variant: .hazard) {
                    if !isLocked {
                        roundVM.tapHazard(holeNumber: holeNumber, playerId: owner.id)
                        Task { await HapticEngine.shared.play(.penaltyHazard) }
                    }
                }
                .disabled(isLocked)
                WatchPenaltyButton(variant: .ok) {
                    if !isLocked {
                        roundVM.tapOK(holeNumber: holeNumber, playerId: owner.id)
                        Task { await HapticEngine.shared.play(.penaltyOK) }
                    }
                }
                .disabled(isLocked)
            }
            .padding(.horizontal, 2)

            // 하단: '나' 이름
            Text(owner.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isLocked ? .secondary : Color.green)
                .lineLimit(1)
                .padding(.bottom, 2)
        }
        .alert("이전 홀을 수정하시겠어요?", isPresented: $showUnlockAlert) {
            Button("수정") {
                roundVM.unlockHole(holeNumber)
            }
            Button("취소", role: .cancel) { }
        } message: {
            Text("\(holeNumber)번 홀 잠금을 해제하면 다시 수정할 수 있어요.")
        }
        .onLongPressGesture(minimumDuration: 0.6) {
            if isLocked { showUnlockAlert = true }
        }
    }

    // MARK: - Buttons / helpers

    private func counterButton(symbol: String, isPrimary: Bool, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(symbol)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(disabled ? Color.gray.opacity(0.5) : (isPrimary ? .white : .primary))
                .frame(width: 40, height: 40)
                .background(
                    disabled ? Color.gray.opacity(0.15) : (isPrimary ? Color.green : Color.gray.opacity(0.25)),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .accessibilityLabel(isPrimary ? "타수 +1" : "타수 −1")
    }

    private func parDiffCaption(count: Int, par: Int) -> String {
        guard count > 0 else { return "Par \(par)" }
        let diff = count - par
        if diff == 0 { return "Par \(par) · E" }
        if diff > 0 { return "Par \(par) · +\(diff)" }
        return "Par \(par) · \(diff)"
    }
}

// MARK: - WatchRoundControlPage (운동 앱 스타일 하단 컨트롤 페이지)
// 어느 홀에서든 아래로 스와이프 시 노출. ① 라운드 종료 ② 워크아웃 멈춤/재개.

private struct WatchRoundControlPage: View {

    @Bindable var roundVM: RoundViewModel

    /// 워크아웃 상태(isActive/isPaused) 관찰 → 멈춤↔재개 라벨 토글
    @ObservedObject private var workout = WatchWorkoutManager.shared

    @State private var showEndConfirm = false

    var body: some View {
        VStack(spacing: 14) {
            Text("컨트롤")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 18) {
                // ① 라운드 종료
                controlButton(
                    icon: "flag.checkered",
                    label: "종료",
                    tint: .red
                ) {
                    showEndConfirm = true
                }

                // ② 워크아웃 멈춤/재개 — 세션 활성일 때만
                if workout.isActive {
                    if workout.isPaused {
                        controlButton(
                            icon: "play.fill",
                            label: "재개",
                            tint: .green
                        ) {
                            workout.resumeWorkout()
                            Task { await HapticEngine.shared.play(.shotIncrement) }
                        }
                    } else {
                        controlButton(
                            icon: "pause.fill",
                            label: "멈춤",
                            tint: .yellow
                        ) {
                            workout.pauseWorkout()
                            Task { await HapticEngine.shared.play(.shotDecrement) }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .confirmationDialog("라운드를 종료할까요?", isPresented: $showEndConfirm) {
            Button("종료", role: .destructive) {
                roundVM.finishRound()
                // 방어 3 동일 패턴: onChange(isRoundActive)에만 의존하지 않고
                // 명시적으로 always-on 세션 종료. endWorkout의 isActive 가드가 중복 흡수.
                Task {
                    await WatchWorkoutManager.shared.endWorkout()
                    await HapticEngine.shared.play(.roundEnd)
                }
            }
            Button("취소", role: .cancel) {}
        }
    }

    /// 운동 앱 스타일: 큰 원형 아이콘 + 아래 작은 라벨. 터치 타깃 ≥ 44pt.
    private func controlButton(
        icon: String,
        label: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 4) {
            Button(action: action) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 52, height: 52)
                    .background(tint.opacity(0.18), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(label)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - CoursePickerSheet (Watch 코스 수정)

private struct CoursePickerSheet: View {
    let round: Round
    let subs: [String]
    let currentHoleNumber: Int
    @Bindable var roundVM: RoundViewModel
    @Binding var isPresented: Bool

    var body: some View {
        let totalHoles = round.holeList.count
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                Text("코스 수정")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)

                // 전반 섹션
                Text("전반")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                ForEach(subs, id: \.self) { name in
                    let isCurrent = round.frontCourseName == name
                    Button {
                        roundVM.changeSubCourse(half: .front, to: name)
                        Task { await HapticEngine.shared.play(.holeManualChange) }
                        isPresented = false
                    } label: {
                        HStack {
                            Text(name)
                                .font(.system(size: 13))
                                .foregroundStyle(isCurrent ? Color.green : .primary)
                            Spacer()
                            if isCurrent {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.green)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }

                // 후반 섹션 (18홀일 때만)
                if totalHoles == 18 {
                    Divider().padding(.vertical, 4)
                    Text("후반")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    ForEach(subs, id: \.self) { name in
                        let isCurrent = round.backCourseName == name
                        Button {
                            roundVM.changeSubCourse(half: .back, to: name)
                            Task { await HapticEngine.shared.play(.holeManualChange) }
                            isPresented = false
                        } label: {
                            HStack {
                                Text(name)
                                    .font(.system(size: 13))
                                    .foregroundStyle(isCurrent ? Color.green : .primary)
                                Spacer()
                                if isCurrent {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(Color.green)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
    }
}

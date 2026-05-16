import SwiftUI
import Shared

// MARK: - WatchHoleSwipeContainer
// Watch 메인: 좌우 swipe로 홀 이동 + 각 페이지는 '나'(owner) 전용 입력 UI
// 동반자 입력은 iPhone에서만 가능 (verticalPage 폐기)
// 12-SCREENS watch-3.2 (단순화)

struct WatchHoleSwipeContainer: View {

    @Bindable var roundVM: RoundViewModel

    var body: some View {
        guard let holeVM = roundVM.holeViewModel else {
            return AnyView(Text("라운드 없음").foregroundStyle(.secondary))
        }

        return AnyView(
            TabView(selection: Binding(
                get: { holeVM.currentHoleIndex },
                set: { idx in
                    let prev = holeVM.currentHoleIndex
                    holeVM.goToHole(index: idx)
                    if idx != prev {
                        Task { await HapticEngine.shared.play(.holeManualChange) }
                    }
                }
            )) {
                ForEach(0..<holeVM.totalHoles, id: \.self) { holeIdx in
                    holePage(holeNumber: holeIdx + 1, holeVM: holeVM)
                        .tag(holeIdx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
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
        let count = scoreVM.count(holeNumber: holeNumber, playerId: owner.id)
        let par = scoreVM.parByHole[holeNumber] ?? 4

        return VStack(spacing: 6) {
            // 헤더: 홀 번호 + Par badge (탭 cycle) + 진행 N/총홀
            HStack(spacing: 6) {
                Text("\(holeNumber)번")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)

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

                Spacer()

                Text("\(holeNumber)/\(totalHoles)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 6)
            .padding(.top, 2)

            // 메인: 좌[−] / 숫자 / 우[＋]
            HStack(spacing: 6) {
                counterButton(symbol: "−", isPrimary: false) {
                    roundVM.decrement(holeNumber: holeNumber, playerId: owner.id)
                    Task { await HapticEngine.shared.play(.shotDecrement) }
                }
                VStack(spacing: 2) {
                    Text(count > 0 ? "\(count)" : "0")
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(parDiffCaption(count: count, par: par))
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                counterButton(symbol: "+", isPrimary: true) {
                    roundVM.increment(holeNumber: holeNumber, playerId: owner.id)
                    Task { await HapticEngine.shared.play(.shotIncrement) }
                }
            }
            .padding(.horizontal, 4)

            // 벌타 3종
            HStack(spacing: 4) {
                WatchPenaltyButton(variant: .ob) {
                    roundVM.tapOB(holeNumber: holeNumber, playerId: owner.id)
                    Task { await HapticEngine.shared.play(.penaltyOB) }
                }
                WatchPenaltyButton(variant: .hazard) {
                    roundVM.tapHazard(holeNumber: holeNumber, playerId: owner.id)
                    Task { await HapticEngine.shared.play(.penaltyHazard) }
                }
                WatchPenaltyButton(variant: .ok) {
                    roundVM.tapOK(holeNumber: holeNumber, playerId: owner.id)
                    Task { await HapticEngine.shared.play(.penaltyOK) }
                }
            }
            .padding(.horizontal, 2)

            // 하단: '나' 이름
            Text(owner.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.green)
                .lineLimit(1)
                .padding(.bottom, 2)
        }
    }

    // MARK: - Buttons / helpers

    private func counterButton(symbol: String, isPrimary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(symbol)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(isPrimary ? .white : .primary)
                .frame(width: 40, height: 40)
                .background(
                    isPrimary ? Color.green : Color.gray.opacity(0.25),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
        }
        .buttonStyle(.plain)
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

import SwiftUI
import Shared

// MARK: - WatchScoreInputView
// watch-3.1 메인 타수 입력 화면 (12-SCREENS watch-3.1)
// ShotButton 중앙 + 홀 번호 상단 + 플레이어 이름 하단

struct WatchScoreInputView: View {

    // MARK: Props

    @Bindable var roundVM: RoundViewModel

    // MARK: Body

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 4) {
                // 상단: 홀 정보
                holeHeader

                Spacer()

                // 중앙: 좌 [−] / 가운데 큰 숫자 (보기 전용) / 우 [＋]
                // Watch는 '나'(isOwner)의 타수만 입력 가능. 동반자 점수는 iPhone에서 입력.
                if let holeVM = roundVM.holeViewModel,
                   let scoreVM = roundVM.scoreCardViewModel,
                   let owner = scoreVM.players.first(where: { $0.isOwner }) {

                    let count = scoreVM.count(holeNumber: holeVM.currentHoleNumber, playerId: owner.id)
                    let par = scoreVM.parByHole[holeVM.currentHoleNumber] ?? 4

                    HStack(spacing: 6) {
                        watchCounterButton(symbol: "−", isPrimary: false) {
                            roundVM.decrement(holeNumber: holeVM.currentHoleNumber, playerId: owner.id)
                            Task { await HapticEngine.shared.play(.shotDecrement) }
                        }

                        VStack(spacing: 2) {
                            Text(count > 0 ? "\(count)" : "0")
                                .font(.system(size: 44, weight: .heavy, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                            Text(parDiffCaption(count: count, par: par))
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)

                        watchCounterButton(symbol: "+", isPrimary: true) {
                            roundVM.increment(holeNumber: holeVM.currentHoleNumber, playerId: owner.id)
                            Task { await HapticEngine.shared.play(.shotIncrement) }
                        }
                    }
                    .padding(.horizontal, 4)
                } else {
                    Text("라운드 없음")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // 하단: 활성 플레이어
                playerFooter
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    // MARK: Sub Views

    private var holeHeader: some View {
        HStack(spacing: 6) {
            if let holeVM = roundVM.holeViewModel,
               let scoreVM = roundVM.scoreCardViewModel {
                Text("\(holeVM.currentHoleNumber)번")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)

                // Par 표시 + 탭 시 3→4→5→3 cycle (watchOS Menu 미지원이라 cycle 방식)
                let par = scoreVM.parByHole[holeVM.currentHoleNumber] ?? 4
                Button {
                    let next: Int = (par == 3 ? 4 : (par == 4 ? 5 : 3))
                    roundVM.setPar(holeNumber: holeVM.currentHoleNumber, par: next)
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

                Text("\(holeVM.currentHoleNumber)/\(holeVM.totalHoles)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
    }

    private var playerFooter: some View {
        Group {
            if let scoreVM = roundVM.scoreCardViewModel,
               let owner = scoreVM.players.first(where: { $0.isOwner }) {
                Text(owner.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.green)
                    .lineLimit(1)
                    .padding(.bottom, 4)
            }
        }
    }

    // MARK: Counter button + helpers

    private func watchCounterButton(symbol: String, isPrimary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(symbol)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(isPrimary ? .white : .primary)
                .frame(width: 44, height: 44)
                .background(
                    isPrimary ? Color.green : Color.gray.opacity(0.25),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPrimary ? "타수 +1" : "타수 -1")
    }

    private func parDiffCaption(count: Int, par: Int) -> String {
        guard count > 0 else { return "Par \(par)" }
        let diff = count - par
        if diff == 0 { return "Par \(par) · E" }
        if diff > 0 { return "Par \(par) · +\(diff)" }
        return "Par \(par) · \(diff)"
    }
}

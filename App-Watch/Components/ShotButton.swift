import SwiftUI
import Shared

// MARK: - ShotButton (Watch)
// F4 핵심 — "0에서 시작, 샷마다 +1" 카운터 큰 버튼 (11-COMPONENTS §7)
// 96×96pt 큰 탭 + Digital Crown +1/-1 (.digitalCrownRotation)

struct ShotButton: View {

    // MARK: Props (단방향 데이터 흐름)

    let count: Int
    let par: Int
    let onIncrement: () -> Void
    let onDecrement: () -> Void

    // MARK: Private State

    /// Crown 회전 누적값 (0 기준 상대적 이동)
    @State private var crownValue: Double = 0.0
    /// Crown 이전 정수값 (increment/decrement 트리거 기준)
    @State private var lastCrownInt: Int = 0

    // MARK: VoiceOver Announce Debounce (14-ACCESSIBILITY §4)
    @State private var announceTask: Task<Void, Never>? = nil

    // MARK: Body

    var body: some View {
        VStack(spacing: 4) {
            // 타수 숫자 (--score-watch 56pt/600)
            Text("\(count)")
                .font(.system(size: 56, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText())

            // par 대비 표시
            let parDiff = ParDiff.from(count: count, par: par)
            if count > 0 {
                Text(parDiffLabel(parDiff))
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 96, height: 96)
        .background(Color.green.opacity(0.15), in: Circle())
        .contentShape(Circle())
        // 탭: +1
        .onTapGesture {
            onIncrement()
            Task { await HapticEngine.shared.play(.shotIncrement) }
        }
        // Digital Crown: ±1 (11-COMPONENTS §7, 14-ACCESSIBILITY §4)
        .focusable()
        .digitalCrownRotation(
            $crownValue,
            from: -999,
            through: 999,
            by: 1.0,
            sensitivity: .low,
            isContinuous: false,
            isHapticFeedbackEnabled: true   // 시스템 기본 Crown 햅틱 활용 (13-HAPTICS §9)
        )
        .onChange(of: crownValue) { _, newVal in
            let newInt = Int(newVal.rounded())
            let delta = newInt - lastCrownInt
            lastCrownInt = newInt

            if delta > 0 {
                for _ in 0..<delta { onIncrement() }
            } else if delta < 0 {
                for _ in 0..<abs(delta) { onDecrement() }
            }

            // VoiceOver announce debounce 300ms (14-ACCESSIBILITY §4)
            scheduleAnnounce()
        }
        // VoiceOver (14-ACCESSIBILITY §2)
        .accessibilityLabel("타수 카운트")
        .accessibilityHint("탭하여 +1, Digital Crown으로 조절")
        .accessibilityValue(voiceOverValue)
        .accessibilityAddTraits(.isAdjustable)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onIncrement()
            case .decrement: onDecrement()
            @unknown default: break
            }
        }
    }

    // MARK: - Helpers

    private func parDiffLabel(_ diff: ParDiff) -> String {
        switch diff {
        case .eagle:    return "이글 ◎"
        case .birdie:   return "버디 ●"
        case .par:      return "파"
        case .bogey:    return "보기 ■"
        case .doublePlus: return "더블+ ▣"
        case .notEntered: return ""
        }
    }

    private var voiceOverValue: String {
        let diff = ParDiff.from(count: count, par: par)
        return "\(count)타, \(diff.voiceOverTerm)"
    }

    /// Crown 회전 후 300ms 디바운스 announce (14-ACCESSIBILITY §4)
    private func scheduleAnnounce() {
        announceTask?.cancel()
        announceTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            let value = voiceOverValue
#if os(watchOS)
            // watchOS: UIAccessibility 대신 접근성 announce 없음 — 값 변경으로 자동 발화
#endif
            _ = value   // VoiceOver는 accessibilityValue 변경 시 자동 발화
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    ShotButton(count: 4, par: 4, onIncrement: {}, onDecrement: {})
}
#endif

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
        contentStack
            .frame(width: 96, height: 96)
            .background(Color.green.opacity(0.15), in: Circle())
            .contentShape(Circle())
            .onTapGesture(perform: handleTap)
            .focusable()
            .digitalCrownRotation(
                $crownValue,
                from: -999,
                through: 999,
                by: 1.0,
                sensitivity: .low,
                isContinuous: false,
                isHapticFeedbackEnabled: true
            )
            .onChange(of: crownValue) { _, newVal in
                handleCrownChange(newVal)
            }
            .modifier(AccessibilityModifier(
                value: voiceOverValue,
                onIncrement: onIncrement,
                onDecrement: onDecrement
            ))
    }

    // MARK: - Subviews

    @ViewBuilder
    private var contentStack: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 56, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText())

            parDiffText
        }
    }

    @ViewBuilder
    private var parDiffText: some View {
        if count > 0 {
            let parDiff = ParDiff.from(count: count, par: par)
            Text(parDiffLabel(parDiff))
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Actions

    private func handleTap() {
        onIncrement()
        Task { await HapticEngine.shared.play(.shotIncrement) }
    }

    private func handleCrownChange(_ newVal: Double) {
        let newInt = Int(newVal.rounded())
        let delta = newInt - lastCrownInt
        lastCrownInt = newInt

        if delta > 0 {
            for _ in 0..<delta { onIncrement() }
        } else if delta < 0 {
            for _ in 0..<abs(delta) { onDecrement() }
        }

        scheduleAnnounce()
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

// MARK: - AccessibilityModifier
// VoiceOver 4-tuple + Adjustable 액션 (14-ACCESSIBILITY §2/§4)
// body 표현식 분리용 — 컴파일러 타입 추론 부담 완화

private struct AccessibilityModifier: ViewModifier {
    let value: String
    let onIncrement: () -> Void
    let onDecrement: () -> Void

    func body(content: Content) -> some View {
        content
            .accessibilityLabel("타수 카운트")
            .accessibilityHint("탭하여 +1, Digital Crown으로 조절")
            .accessibilityValue(value)
            // accessibilityAdjustableAction만 있어도 SwiftUI가 isAdjustable trait 자동 부여
            // (watchOS는 AccessibilityTraits.isAdjustable 미노출 — 명시 traits add 회피)
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: onIncrement()
                case .decrement: onDecrement()
                @unknown default: break
                }
            }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    ShotButton(count: 4, par: 4, onIncrement: {}, onDecrement: {})
}
#endif

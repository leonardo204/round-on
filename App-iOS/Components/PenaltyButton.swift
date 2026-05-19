import SwiftUI
import Shared

// MARK: - PenaltyButton (iOS)
// F4 벌타 입력 버튼 (11-COMPONENTS §6, 12-SCREENS iphone-2.4)
// 3 변형: .ob (+2) / .hazard (+1 벌타) / .ok (+1 컨시드)

public struct PenaltyButton: View {

    // MARK: Variant

    public enum Variant {
        case ob        // OB: +2 (빨간색 경고)
        case hazard    // 해저드: +1
        case ok        // OK / 컨시드: +1
        case doublePar // 더블파: par×2 강제 설정
    }

    // MARK: Props

    public let variant: Variant
    public let onTap: () -> Void

    // MARK: Init

    public init(variant: Variant, onTap: @escaping () -> Void) {
        self.variant = variant
        self.onTap = onTap
    }

    // MARK: Body

    public var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .medium))
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                Text(deltaLabel)
                    .font(.system(size: 12, weight: .regular))
                    .opacity(0.75)
            }
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        // 14-ACCESSIBILITY §2 VoiceOver
        .accessibilityLabel("\(label) \(deltaLabel)")
        .accessibilityHint(accessibilityHint)
    }

    // MARK: Styling

    private var iconName: String {
        switch variant {
        case .ob:        return "exclamationmark.triangle.fill"
        case .hazard:    return "water.waves"
        case .ok:        return "checkmark.circle.fill"
        case .doublePar: return "2.square.fill"
        }
    }

    private var label: String {
        switch variant {
        case .ob:        return "OB"
        case .hazard:    return "해저드"
        case .ok:        return "OK"
        case .doublePar: return "더블파"
        }
    }

    private var deltaLabel: String {
        switch variant {
        case .ob:        return "+2"
        case .hazard:    return "+1"
        case .ok:        return "+1"
        case .doublePar: return "par×2"
        }
    }

    private var foregroundColor: Color {
        switch variant {
        case .ob:        return Color.springTextPrimary
        case .hazard:    return Color.springTextPrimary
        case .ok:        return Color.springTextPrimary
        case .doublePar: return Color.springTextPrimary
        }
    }

    private var backgroundColor: Color {
        switch variant {
        case .ob:        return Color(red: 0.95, green: 0.82, blue: 0.82) // 연한 빨간색
        case .hazard:    return Color(red: 0.82, green: 0.90, blue: 0.95) // 연한 파란색
        case .ok:        return Color.springGreenSecondary.opacity(0.4)    // 연한 그린
        case .doublePar: return Color(red: 0.85, green: 0.72, blue: 0.55) // 연한 오렌지-베이지
        }
    }

    private var accessibilityHint: String {
        switch variant {
        case .ob:        return "OB 적용, 타수 2 증가"
        case .hazard:    return "해저드 적용, 타수 1 증가"
        case .ok:        return "OK 컨시드 적용, 타수 1 증가"
        case .doublePar: return "더블파 적용, par의 2배로 타수 강제 설정"
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    VStack(spacing: 8) {
        PenaltyButton(variant: .ob, onTap: {})
        PenaltyButton(variant: .hazard, onTap: {})
        PenaltyButton(variant: .ok, onTap: {})
        PenaltyButton(variant: .doublePar, onTap: {})
    }
    .padding()
}
#endif

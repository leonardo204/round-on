import SwiftUI
import Shared

// MARK: - PenaltyButton (Watch)
// F4 벌타 입력 (11-COMPONENTS §6, watch-3.3)
// Watch 화면 크기에 맞춘 컴팩트 버튼

struct WatchPenaltyButton: View {

    // MARK: Variant

    enum Variant {
        case ob      // OB +2
        case hazard  // 해저드 +1
        case ok      // OK +1
    }

    // MARK: Props

    let variant: Variant
    let onTap: () -> Void

    // MARK: Body

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .medium))
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                Text(deltaLabel)
                    .font(.system(size: 11))
                    .opacity(0.7)
            }
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label) \(deltaLabel)")
    }

    // MARK: Styling

    private var iconName: String {
        switch variant {
        case .ob:     return "exclamationmark.triangle.fill"
        case .hazard: return "water.waves"
        case .ok:     return "checkmark.circle.fill"
        }
    }

    private var label: String {
        switch variant {
        case .ob:     return "OB"
        case .hazard: return "해저드"
        case .ok:     return "OK"
        }
    }

    private var deltaLabel: String {
        switch variant {
        case .ob:     return "+2"
        case .hazard: return "+1"
        case .ok:     return "+1"
        }
    }

    private var foregroundColor: Color {
        Color.primary
    }

    private var backgroundColor: Color {
        switch variant {
        case .ob:     return Color(red: 0.8, green: 0.3, blue: 0.3).opacity(0.3)
        case .hazard: return Color(red: 0.3, green: 0.5, blue: 0.8).opacity(0.3)
        case .ok:     return Color.green.opacity(0.3)
        }
    }
}

import SwiftUI

// MARK: - BannerNotice
// 시스템 안내 배너 (11-COMPONENTS §9, 20-ARCHITECTURE §7)
// 오프라인, 공유 만료, 권한 거부 등 일시 상태 안내
// 플랫폼: iOS/watchOS 공통

public struct BannerNotice: View {

    // MARK: Severity

    public enum Severity {
        case info       // 파란색
        case warning    // 노란색
        case error      // 빨간색
        case success    // 초록색
    }

    // MARK: Props

    public let message: String
    public let severity: Severity
    public let dismissAction: (() -> Void)?

    // MARK: Init

    public init(message: String, severity: Severity = .info, dismissAction: (() -> Void)? = nil) {
        self.message = message
        self.severity = severity
        self.dismissAction = dismissAction
    }

    // MARK: Body

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(iconColor)

            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(textColor)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let dismiss = dismissAction {
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(textColor.opacity(0.7))
                }
                .accessibilityLabel("알림 닫기")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(backgroundColor)
        // 14-ACCESSIBILITY §2
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(message)
        .accessibilityAddTraits(.isStaticText)
    }

    // MARK: Styling

    private var iconName: String {
        switch severity {
        case .info:    return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error:   return "xmark.circle.fill"
        case .success: return "checkmark.circle.fill"
        }
    }

    private var iconColor: Color {
        switch severity {
        case .info:    return Color(red: 0.2, green: 0.5, blue: 0.9)
        case .warning: return Color(red: 0.9, green: 0.7, blue: 0.1)
        case .error:   return Color(red: 0.85, green: 0.2, blue: 0.2)
        case .success: return Color.springGreenPrimary
        }
    }

    private var textColor: Color { Color.springTextPrimary }

    private var backgroundColor: Color {
        switch severity {
        case .info:    return Color(red: 0.9, green: 0.95, blue: 1.0)
        case .warning: return Color(red: 1.0, green: 0.97, blue: 0.88)
        case .error:   return Color(red: 1.0, green: 0.92, blue: 0.92)
        case .success: return Color.springGreenSecondary.opacity(0.25)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    VStack(spacing: 0) {
        BannerNotice(message: "오프라인 상태입니다. 공유 기능을 사용할 수 없어요.", severity: .warning, dismissAction: {})
        BannerNotice(message: "공유 링크가 만료되었어요. 재공유해 주세요.", severity: .error, dismissAction: {})
        BannerNotice(message: "공유 링크가 생성되었어요.", severity: .success)
    }
}
#endif

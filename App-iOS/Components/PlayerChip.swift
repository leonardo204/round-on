import SwiftUI
import Shared

// MARK: - PlayerChip
// 동반자 칩 (11-COMPONENTS §2, 12-SCREENS 플레이어 행)
// readonly: 이름만 표시 / editable: 삭제 버튼 포함
// 플랫폼: iOS (공통 로직이나 iOS 전용 사용)

public struct PlayerChip: View {

    // MARK: Variant

    public enum Variant {
        case readonly    // 읽기 전용 (스코어카드 행 레이블)
        case editable    // 삭제 가능 (플레이어 편집 목록)
        case active      // 현재 활성 플레이어 강조
    }

    // MARK: Props

    public let player: Player
    public let variant: Variant
    public let onDelete: (() -> Void)?

    // MARK: Init

    public init(player: Player, variant: Variant = .readonly, onDelete: (() -> Void)? = nil) {
        self.player = player
        self.variant = variant
        self.onDelete = onDelete
    }

    // MARK: Body

    public var body: some View {
        HStack(spacing: 4) {
            // 아바타 이니셜
            Text(initial)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(variant == .active ? Color.springTextPrimary : Color.springTextSecondary)
                .frame(width: 22, height: 22)
                .background(variant == .active ? Color.springGreenPrimary : Color.springGreenAccent.opacity(0.3))
                .clipShape(Circle())

            Text(player.name)
                .font(.system(size: 13, weight: variant == .active ? .semibold : .regular))
                .foregroundStyle(variant == .active ? Color.springGreenPrimary : Color.springTextPrimary)
                .lineLimit(1)

            if variant == .editable, let onDelete = onDelete {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.springTextSecondary)
                }
                .accessibilityLabel("\(player.name) 삭제")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(chipBackground)
        .clipShape(Capsule())
        // 14-ACCESSIBILITY §2
        .accessibilityElement(children: variant == .editable ? .contain : .ignore)
        .accessibilityLabel(variant == .editable ? player.name : player.name)
        .accessibilityAddTraits(variant == .active ? .isSelected : [])
    }

    // MARK: Helpers

    private var initial: String {
        String(player.name.prefix(1))
    }

    private var chipBackground: Color {
        switch variant {
        case .readonly: return Color.springBorder.opacity(0.3)
        case .editable: return Color.springSurfaceElevated
        case .active:   return Color.springGreenAccent.opacity(0.15)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    VStack(spacing: 8) {
        PlayerChip(player: Player(name: "나", isOwner: true), variant: .active)
        PlayerChip(player: Player(name: "동반자1"), variant: .readonly)
        PlayerChip(player: Player(name: "홍길동"), variant: .editable, onDelete: {})
    }
    .padding()
}
#endif

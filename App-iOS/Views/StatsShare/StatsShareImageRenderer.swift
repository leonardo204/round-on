import SwiftUI
import UIKit
import Shared

/// 1080×1080 시그니처 카드 PNG 렌더러.
/// ImageRenderer는 @MainActor 격리 필요 — 항상 메인 스레드에서 호출.
@MainActor
public enum StatsShareImageRenderer {

    /// 1080×1080 PNG UIImage. scale=1 강제. nil 반환 시 렌더 실패.
    public static func renderSignatureCard(
        signature: StatsSignature,
        cardKind: StatsSignatureCardKind,
        dateISO: String
    ) -> UIImage? {
        let view = StatsSignatureCardView(
            signature: signature,
            cardKind: cardKind,
            dateISO: dateISO
        )
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1.0   // 1080×1080 정확히
        renderer.proposedSize = ProposedViewSize(width: 1080, height: 1080)
        return renderer.uiImage
    }

    /// PNG Data. 800KB 한도 권장 (카톡 첨부).
    public static func renderSignatureCardPNG(
        signature: StatsSignature,
        cardKind: StatsSignatureCardKind,
        dateISO: String
    ) -> Data? {
        guard let img = renderSignatureCard(
            signature: signature,
            cardKind: cardKind,
            dateISO: dateISO
        ) else {
            return nil
        }
        return img.pngData()
    }
}

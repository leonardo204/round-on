import Foundation

// MARK: - StatsShareOgImage
// 통계 공유 og:image(카톡 미리보기 카드) 업로드 페이로드 인코딩.
// Worker 계약(POST /api/share/stats): top-level `ogImage`에 1080×1080 PNG를 순수 base64로.
// og는 부가 기능이다 — 여기서 skip이 나와도 공유 생성은 반드시 그대로 진행한다.

public enum StatsShareOgImage {

    /// Worker의 MAX_OG_BASE64_LENGTH와 동일해야 하는 base64 문자열 상한.
    /// 초과분은 서버가 어차피 og를 생략하므로 아예 전송하지 않는다.
    public static let maxBase64Length = 1_572_864

    public enum SkipReason: String, Sendable {
        /// PIN 공유는 서버가 og를 저장하지 않는다(미리보기로 스코어 노출 방지) — 전송해도 버려진다
        case pinProtected
        /// 카드 렌더 실패 또는 빈 PNG
        case renderFailed
        /// base64 상한 초과
        case tooLarge
    }

    public enum EncodeResult: Sendable, Equatable {
        case encoded(String)
        case skipped(SkipReason)

        /// 요청 body에 실을 값. skip이면 nil이고, 이때 `ogImage` 키 자체가 빠진다.
        public var base64: String? {
            if case .encoded(let value) = self { return value }
            return nil
        }
    }

    /// PNG Data → 업로드용 base64.
    /// 미전송 사유를 호출부가 로깅할 수 있도록 result로 돌려준다.
    public static func encode(pngData: Data?, hasPin: Bool) -> EncodeResult {
        if hasPin { return .skipped(.pinProtected) }

        guard let pngData, !pngData.isEmpty else { return .skipped(.renderFailed) }

        // data URI prefix("data:image/png;base64,")를 붙이면 서버가 거부한다
        let base64 = pngData.base64EncodedString()
        guard base64.count <= maxBase64Length else { return .skipped(.tooLarge) }

        return .encoded(base64)
    }
}

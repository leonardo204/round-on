import Foundation

// MARK: - ImportGate
// 사진 선택 → 분석 실행 사이의 게이트(동의·할당량) 판정과 보류 항목 보관을 담당하는 순수 상태 머신.
//
// 게이트에 걸린 항목을 보관해두는 이유:
//   동의 팝업 / 할당량 소진(광고 충전) 후 사용자가 원래 하려던 분석을 재개해야 한다.
//   보관하지 않으면 사용자는 사진 선택 화면으로 되돌아간다.
//
// PhotosUI·광고 SDK 의존이 없어 단위 테스트가 가능하다. 프로덕션의 Item은 PhotosPickerItem.
// (PhotosPickerItem은 공개 이니셜라이저가 없어 테스트에서 생성할 수 없으므로 Item을 제네릭으로 둔다)

struct ImportGate<Item> {

    /// 신규 선택에 대한 게이트 판정
    enum Decision: Equatable {
        case needsConsent    // 동의 미수락 → 동의 팝업
        case quotaExhausted  // 할당량 소진 → AIAnalysisView 유도
        case proceed         // 통과 → OCR 실행
    }

    /// 보류 항목 재개 판정
    enum ResumeDecision {
        case proceed(item: Item, ownerName: String?)
        case needsConsent    // 재개 시점에 동의가 철회됨 → 전송 금지
        case quotaExhausted  // 충전되지 않음 → 재개 금지 (게이트 재진입 무한루프 방지)
        case noPending       // 보류 항목 없음
    }

    /// 게이트에 걸려 보류 중인 항목 (재개 시 사용)
    private(set) var pendingItem: Item?
    private(set) var pendingOwnerName: String?

    /// 게이트 통과 여부를 판정한다. 통과하지 못하면 항목을 보관해 재개에 대비한다.
    mutating func evaluate(
        item: Item,
        ownerName: String?,
        isConsentAccepted: Bool,
        canAnalyze: Bool
    ) -> Decision {
        if !isConsentAccepted {
            hold(item: item, ownerName: ownerName)
            return .needsConsent
        }
        if !canAnalyze {
            hold(item: item, ownerName: ownerName)
            return .quotaExhausted
        }
        clear()
        return .proceed
    }

    /// 보류 항목으로 재개할 수 있는지 판정한다.
    /// 동의·할당량을 재확인하는 이유: 사용자가 팝업/광고 화면에서 동의를 철회하거나
    /// 보상 전에 광고를 닫아 충전되지 않았을 수 있다.
    /// 통과(.proceed) 시에만 보관을 비운다 — 미통과 시 보관을 유지해 재동의·재충전 후 재개할 수 있게 한다.
    mutating func resume(isConsentAccepted: Bool, canAnalyze: Bool) -> ResumeDecision {
        guard let item = pendingItem else { return .noPending }
        if !isConsentAccepted { return .needsConsent }
        if !canAnalyze { return .quotaExhausted }
        let ownerName = pendingOwnerName
        clear()
        return .proceed(item: item, ownerName: ownerName)
    }

    /// 게이트 판정 없이 보류 항목을 꺼낸다.
    /// 동의 거부 → Vision 온디바이스 폴백 전용 (외부 전송이 없어 동의·할당량 무관).
    mutating func takePending() -> (item: Item, ownerName: String?)? {
        guard let item = pendingItem else { return nil }
        let ownerName = pendingOwnerName
        clear()
        return (item, ownerName)
    }

    /// 보류 항목 폐기 (취소 등)
    mutating func clear() {
        pendingItem = nil
        pendingOwnerName = nil
    }

    private mutating func hold(item: Item, ownerName: String?) {
        pendingItem = item
        pendingOwnerName = ownerName
    }
}

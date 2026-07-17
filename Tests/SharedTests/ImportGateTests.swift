import XCTest
import SwiftUI
import PhotosUI
@testable import Shared

// NOTE: ImportGate.swift는 project.yml에서 SharedTests 타겟 소스로 포함되므로 직접 호출해 검증한다.
// 프로덕션과 동일하게 ImportGate<PhotosPickerItem>으로 인스턴스화한다.
// (PhotosPickerItem은 itemIdentifier 이니셜라이저가 공개되어 있어 테스트에서 생성 가능)

// MARK: - ImportGateTests
// 동의·할당량 게이트 판정 + 보류 항목 보관/재개 검증.
// 실측 버그: 할당량 소진 시 선택한 사진을 보관하지 않아 광고 충전 후 분석이 재개되지 않았다.

final class ImportGateTests: XCTestCase {

    private func makeItem(_ identifier: String) -> PhotosPickerItem {
        PhotosPickerItem(itemIdentifier: identifier)
    }

    // MARK: evaluate — 게이트 판정 + 보류 보관

    func test_evaluate_quotaExhausted_holdsPendingItem() {
        // 실측 버그: 할당량 소진 분기가 item을 보관하지 않고 return → 충전 후 재개할 대상이 사라졌다.
        var gate = ImportGate<PhotosPickerItem>()
        let item = makeItem("asset-1")

        let decision = gate.evaluate(item: item, ownerName: "이영섭", isConsentAccepted: true, canAnalyze: false)

        XCTAssertEqual(decision, .quotaExhausted)
        XCTAssertEqual(gate.pendingItem, item, "할당량 소진 시 선택한 사진을 보관해야 충전 후 재개할 수 있음")
        XCTAssertEqual(gate.pendingOwnerName, "이영섭", "ownerName도 함께 보관되어야 함")
    }

    func test_evaluate_needsConsent_holdsPendingItem() {
        var gate = ImportGate<PhotosPickerItem>()
        let item = makeItem("asset-1")

        let decision = gate.evaluate(item: item, ownerName: "이영섭", isConsentAccepted: false, canAnalyze: true)

        XCTAssertEqual(decision, .needsConsent)
        XCTAssertEqual(gate.pendingItem, item, "동의 대기 중에도 항목을 보관해야 수락 후 재개 가능")
    }

    func test_evaluate_consentCheckedBeforeQuota() {
        // 미동의 + 할당량 소진이 겹치면 동의가 우선 — 동의 없이 할당량 팝업으로 유도하지 않는다.
        var gate = ImportGate<PhotosPickerItem>()

        let decision = gate.evaluate(item: makeItem("asset-1"), ownerName: nil, isConsentAccepted: false, canAnalyze: false)

        XCTAssertEqual(decision, .needsConsent)
    }

    func test_evaluate_proceed_clearsPending() {
        // 게이트를 통과하면 곧바로 실행되므로 보류가 남아 있으면 안 된다 (재개 시 중복 실행 방지)
        var gate = ImportGate<PhotosPickerItem>()
        _ = gate.evaluate(item: makeItem("stale"), ownerName: nil, isConsentAccepted: true, canAnalyze: false)

        let decision = gate.evaluate(item: makeItem("asset-2"), ownerName: nil, isConsentAccepted: true, canAnalyze: true)

        XCTAssertEqual(decision, .proceed)
        XCTAssertNil(gate.pendingItem, "통과 시 이전 보류 항목이 남아 있으면 안 됨")
    }

    // MARK: resume — 충전/동의 후 재개

    func test_resume_afterRefill_proceedsWithPendingItem() {
        // 광고 시청 → 충전(canAnalyze true) → 원래 사진으로 재개
        var gate = ImportGate<PhotosPickerItem>()
        let item = makeItem("asset-1")
        _ = gate.evaluate(item: item, ownerName: "이영섭", isConsentAccepted: true, canAnalyze: false)

        guard case .proceed(let resumed, let ownerName) = gate.resume(isConsentAccepted: true, canAnalyze: true) else {
            return XCTFail("충전 후에는 보류 항목으로 재개되어야 함")
        }
        XCTAssertEqual(resumed, item, "원래 선택한 사진으로 재개되어야 함")
        XCTAssertEqual(ownerName, "이영섭")
        XCTAssertNil(gate.pendingItem, "재개 후에는 보류를 비워 중복 실행을 막아야 함")
    }

    func test_resume_quotaStillZero_doesNotProceed() {
        // 무한루프 방지: 보상 전 광고를 닫으면(.dismissed) 잔여가 0 그대로다.
        // 재개하면 할당량 게이트에 다시 걸려 AIAnalysisView 시트가 무한 재오픈된다.
        var gate = ImportGate<PhotosPickerItem>()
        let item = makeItem("asset-1")
        _ = gate.evaluate(item: item, ownerName: nil, isConsentAccepted: true, canAnalyze: false)

        switch gate.resume(isConsentAccepted: true, canAnalyze: false) {
        case .quotaExhausted:
            break
        default:
            XCTFail("충전되지 않았으면 재개하지 않아야 함 (시트 재오픈 무한루프 방지)")
        }
        XCTAssertEqual(gate.pendingItem, item, "재개하지 않았으므로 보류는 유지되어 재충전 후 재개 가능해야 함")
    }

    func test_resume_consentRevoked_doesNotProceed() {
        // 개인정보 정책: AIAnalysisView 안에서 동의를 철회하고 나올 수 있다.
        // 미동의 상태로 재개하면 Gemini에 사진이 전송되어 정책 위반.
        var gate = ImportGate<PhotosPickerItem>()
        let item = makeItem("asset-1")
        _ = gate.evaluate(item: item, ownerName: nil, isConsentAccepted: true, canAnalyze: false)

        switch gate.resume(isConsentAccepted: false, canAnalyze: true) {
        case .needsConsent:
            break
        default:
            XCTFail("동의 철회 상태에서는 재개(사진 전송)하지 않아야 함")
        }
        XCTAssertEqual(gate.pendingItem, item, "재동의 후 재개할 수 있도록 보류가 유지되어야 함")
    }

    func test_resume_noPending_returnsNoPending() {
        var gate = ImportGate<PhotosPickerItem>()

        switch gate.resume(isConsentAccepted: true, canAnalyze: true) {
        case .noPending:
            break
        default:
            XCTFail("보류 항목이 없으면 .noPending이어야 함")
        }
    }

    func test_resume_twice_doesNotRunAgain() {
        // 재개 후 보류가 비워져 두 번째 호출은 아무 것도 하지 않아야 한다.
        var gate = ImportGate<PhotosPickerItem>()
        _ = gate.evaluate(item: makeItem("asset-1"), ownerName: nil, isConsentAccepted: true, canAnalyze: false)
        _ = gate.resume(isConsentAccepted: true, canAnalyze: true)

        switch gate.resume(isConsentAccepted: true, canAnalyze: true) {
        case .noPending:
            break
        default:
            XCTFail("이미 재개했으면 중복 재개되지 않아야 함")
        }
    }

    // MARK: takePending — Vision 온디바이스 폴백

    func test_takePending_ignoresConsentAndQuota() {
        // 동의 거부 → Vision 폴백은 외부 전송이 없어 동의·할당량과 무관하게 진행된다.
        var gate = ImportGate<PhotosPickerItem>()
        let item = makeItem("asset-1")
        _ = gate.evaluate(item: item, ownerName: "이영섭", isConsentAccepted: false, canAnalyze: false)

        let pending = gate.takePending()

        XCTAssertEqual(pending?.item, item)
        XCTAssertEqual(pending?.ownerName, "이영섭")
        XCTAssertNil(gate.pendingItem, "꺼낸 뒤에는 보류가 비워져야 함")
    }

    func test_clear_dropsPending() {
        var gate = ImportGate<PhotosPickerItem>()
        _ = gate.evaluate(item: makeItem("asset-1"), ownerName: nil, isConsentAccepted: false, canAnalyze: true)

        gate.clear()

        XCTAssertNil(gate.pendingItem, "취소 시 보류 항목이 폐기되어야 함")
    }

    // MARK: 재선택 시 onChange 발화 여부 (ImportLandingView 선택값 리셋 불필요 근거)

    func test_photosPickerItem_sameAssetIsNotEqual_soOnChangeFiresOnReselect() {
        // ImportLandingView.onChange(of: pickerItem)은 값이 변할 때만 발화한다.
        // PhotosPickerItem의 ==는 asset 식별자만 비교하지 않고 내부 NSItemProvider(참조)까지 포함하므로
        // 같은 사진을 다시 골라도 매번 다른 값이 되어 onChange가 정상 발화한다.
        // → 같은 사진 재선택이 막히는 데드엔드는 없고, 선택값을 nil로 리셋할 필요가 없다.
        // 이 전제가 깨지면(식별자 기준 동등성으로 변경) 재선택 데드엔드가 생기므로 여기서 실패로 알린다.
        XCTAssertNotEqual(makeItem("asset-1"), makeItem("asset-1"),
                          "같은 asset이어도 인스턴스마다 값이 달라야 재선택 시 onChange가 발화함")
        XCTAssertNotEqual(makeItem("asset-1"), makeItem("asset-2"))
    }
}

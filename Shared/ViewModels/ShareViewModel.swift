import Foundation
import Observation
import SwiftData

// MARK: - ShareViewModel
// F6 공유 상태 관리 (22-STATE §3)
// 공유 옵션 + 링크 생성/업데이트/삭제 오케스트레이션
// 실제 API 호출(ShareAPIClient)은 App-iOS 레이어(ShareSheetView)에서 수행

@Observable
@MainActor
public final class ShareViewModel {

    // MARK: State

    /// 공유 시트 표시 여부
    public var isPresented: Bool = false

    /// 이름 공개 여부 (real / anonymous)
    public var nameVisibility: NameVisibility = .real

    /// 접근 제어 (public / pin)
    public var accessControl: AccessControl = .public

    /// PIN 입력값 (4자리)
    public var pinInput: String = ""

    /// 현재 라운드
    public var round: Round?

    /// 로딩 상태 (공유 링크 생성 중)
    public var isLoading: Bool = false

    /// 에러 메시지
    public var errorMessage: String?

    /// 공유 완료 후 UIActivityViewController에 전달할 URL
    public var shareURL: URL?

    /// 업데이트 모드 여부 (Round.sharedShortId 존재 시)
    public var isUpdateMode: Bool { round?.sharedShortId != nil }

    // MARK: Init

    public init(round: Round? = nil) {
        self.round = round
        if let options = round?.sharedOptions {
            self.nameVisibility = options.nameVisibility
            self.accessControl = options.accessControl
        }
    }

    // MARK: Validation

    public var isPinValid: Bool {
        guard case .pin = accessControl else { return true }
        return pinInput.count == 4 && pinInput.allSatisfy(\.isNumber)
    }

    public var canShare: Bool {
        isPinValid && !isLoading
    }

    // MARK: Public API

    /// accessControl에 현재 PIN 적용
    public func applyPin() {
        if pinInput.count == 4 {
            accessControl = .pin(pinInput)
        }
    }

    /// 공유 옵션 저장 (Round.sharedOptions 갱신)
    public func currentOptions() -> ShareOptions {
        let ac: AccessControl
        if case .pin = accessControl, isPinValid {
            ac = .pin(pinInput)
        } else if case .pin = accessControl, !pinInput.isEmpty {
            ac = .pin(pinInput)
        } else {
            ac = accessControl
        }
        return ShareOptions(nameVisibility: nameVisibility, accessControl: ac)
    }

    /// viewer 만료 여부 감지 + Round 필드 nil 처리 (C4)
    public func checkExpiration() {
        guard let round = round,
              let expiresAt = round.sharedExpiresAt,
              expiresAt < .now else { return }
        clearShareFields(in: round)
    }

    // MARK: Private

    private func clearShareFields(in round: Round) {
        round.sharedShortId = nil
        round.sharedURL = nil
        // swiftlint:disable:next deprecated_usage
        round.sharedEditToken = nil  // deprecated 필드 nil 처리 (마이그레이션 완료 표시)
        round.sharedExpiresAt = nil
        round.sharedOptions = nil
    }
}

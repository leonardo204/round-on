import Foundation

/// AdMob 광고 단위 ID 설정
/// - DEBUG: Google 공식 테스트 유닛 (계정 정지 방지)
/// - RELEASE: 라운드온 실 광고 단위
enum AdConfig {
    /// AdMob App ID (GADApplicationIdentifier, Info.plist에도 동일 값 기재)
    static let appID = "ca-app-pub-4410880415888380~3919343525"

    // interstitialUnitID 제거됨 — 보상형(Rewarded) 모델로 전환 (2026-05-29)

    /// 보상형 광고 (Rewarded) 단위 ID
    /// - DEBUG: Google 공식 테스트 보상형 유닛
    /// - RELEASE: 라운드온 보상형 광고 단위
    static var rewardedUnitID: String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/1712485313" // Google 테스트 보상형
        #else
        return "ca-app-pub-4410880415888380/1020197539" // 라운드온 보상형 단위
        #endif
    }
}

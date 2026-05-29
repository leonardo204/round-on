import GoogleMobileAds
import os.log

private let logger = Logger(subsystem: "kr.zerolive.golf.roundon", category: "RewardedAd")

// MARK: - RewardedAdManager
//
// 무료 분석 할당량(3회) + 보상형 광고로 충전하는 Wander 방식.
//
// 흐름:
//   1. 앱 시작 시 preload — loadAd()
//   2. Gemini 분석 성공마다 consume() → remaining -= 1
//   3. remaining == 0 → AIAnalysisView에서 [광고 보고 충전] 탭
//   4. presentAd(from:) → 보상 콜백 → refill() (remaining = 3)
//   5. 광고 닫힘 / 실패 → 다음 광고 preload
//
// UserDefaults 키: "gemini_free_analysis_remaining"

@MainActor
final class RewardedAdManager: NSObject, ObservableObject {
    static let shared = RewardedAdManager()

    // MARK: Published

    @Published private(set) var isAdReady = false
    @Published private(set) var isShowingAd = false

    // MARK: Quota

    private let remainingKey = "gemini_free_analysis_remaining"
    private let defaultQuota = 3

    /// 남은 무료 분석 횟수
    var remaining: Int {
        get {
            let stored = UserDefaults.standard.object(forKey: remainingKey)
            // 최초 실행이면 기본값 3 설정 후 반환
            if stored == nil {
                UserDefaults.standard.set(defaultQuota, forKey: remainingKey)
                return defaultQuota
            }
            return UserDefaults.standard.integer(forKey: remainingKey)
        }
        set {
            let clamped = max(0, newValue)
            UserDefaults.standard.set(clamped, forKey: remainingKey)
            logger.info("[RewardedAd] 할당량 갱신: remaining=\(clamped)")
            objectWillChange.send()
        }
    }

    /// 분석 가능 여부
    var canAnalyze: Bool { remaining > 0 }

    /// 분석 성공 직후 호출 — remaining -= 1 (최소 0)
    func consume() {
        let before = remaining
        remaining = max(0, before - 1)
        logger.info("[RewardedAd] consume: \(before) → \(self.remaining)")
    }

    /// 보상 광고 완료 시 호출 — remaining = 3
    func refill() {
        remaining = defaultQuota
        logger.info("[RewardedAd] refill: remaining=\(self.remaining)")
    }

    // MARK: Ad State

    private var rewardedAd: GADRewardedAd?
    private var isLoadingAd = false
    private var rewardCompletion: ((Bool) -> Void)?

    // MARK: Init

    private override init() {
        super.init()

        // DEBUG: 테스트 기기 등록 (실기기에서 테스트 광고 보장, 계정 정지 방지)
        #if DEBUG
        GADMobileAds.sharedInstance().requestConfiguration.testDeviceIdentifiers =
            ["793cd1120d98071c65404554f1989384"]
        logger.debug("[RewardedAd] DEBUG 테스트 기기 등록 완료 (ID: 793cd...384)")
        #endif

        loadAd()
    }

    // MARK: - Load

    func loadAd() {
        guard !isLoadingAd, !isAdReady else { return }
        isLoadingAd = true
        logger.info("[RewardedAd] 광고 로드 시작 (unitID: \(AdConfig.rewardedUnitID))")

        GADRewardedAd.load(
            withAdUnitID: AdConfig.rewardedUnitID,
            request: GADRequest()
        ) { [weak self] ad, error in
            guard let self else { return }
            Task { @MainActor in
                self.isLoadingAd = false

                if let error {
                    logger.warning("[RewardedAd] 광고 로드 실패: \(error.localizedDescription)")
                    self.isAdReady = false
                    return
                }

                self.rewardedAd = ad
                self.rewardedAd?.fullScreenContentDelegate = self
                self.isAdReady = true
                logger.info("[RewardedAd] 광고 로드 완료")
            }
        }
    }

    // MARK: - Present

    /// 보상형 광고 표시
    /// - Returns: true = 보상 획득 완료, false = 광고 미로드 또는 실패
    func presentAd(from rootVC: UIViewController) async -> Bool {
        guard isAdReady, let ad = rewardedAd else {
            logger.warning("[RewardedAd] 로드된 광고 없음 — preload 요청")
            loadAd()
            return false
        }

        logger.info("[RewardedAd] 광고 표시 시작")
        isShowingAd = true

        return await withCheckedContinuation { continuation in
            rewardCompletion = { success in
                continuation.resume(returning: success)
            }
            ad.present(fromRootViewController: rootVC) { [weak self] in
                guard let self else { return }
                // 보상 지급 시점 — present 클로저 내부가 보상 완료 시점
                let reward = ad.adReward
                logger.info("[RewardedAd] 보상 획득: \(reward.amount) \(reward.type)")
                self.refill()
                self.rewardCompletion?(true)
                self.rewardCompletion = nil
            }
        }
    }

    // MARK: - Helpers

    /// 최상위 UIViewController 탐색
    static func getRootViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first,
              let rootVC = windowScene.windows.first?.rootViewController else {
            return nil
        }
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        return topVC
    }
}

// MARK: - GADFullScreenContentDelegate

extension RewardedAdManager: GADFullScreenContentDelegate {
    nonisolated func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        Task { @MainActor in
            logger.info("[RewardedAd] 광고 닫힘")
            isShowingAd = false
            isAdReady = false
            rewardedAd = nil
            // 보상 콜백이 아직 미처리된 경우(광고 일찍 닫음) → false 반환
            rewardCompletion?(false)
            rewardCompletion = nil
            // 다음 광고 preload
            loadAd()
        }
    }

    nonisolated func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in
            logger.warning("[RewardedAd] 광고 표시 실패: \(error.localizedDescription)")
            isShowingAd = false
            isAdReady = false
            rewardedAd = nil
            rewardCompletion?(false)
            rewardCompletion = nil
            loadAd()
        }
    }

    nonisolated func adWillPresentFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        Task { @MainActor in
            logger.info("[RewardedAd] 광고 전면 표시 진입")
        }
    }
}

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

    // MARK: Silent Retry (지수 백오프)
    //
    // 신규 앱은 광고 fill이 간헐적이라, 로드 실패 시 사용자에게 알리지 않고
    // 백그라운드에서 지수 백오프로 재시도하여 광고 확보 확률을 높인다.
    //   1차 실패 → 4초, 2차 → 8초, 3차 → 16초, 4차+ → 30초(상한)
    //   상한 도달 후에도 안 잡히면 60초 간격으로 조용히 재시도 유지.
    // 성공(isAdReady=true) 시 카운터/타이머 리셋.
    private var retryTask: Task<Void, Never>?
    private var retryCount = 0
    /// 백오프 상한(초) — 초기 재시도 구간의 최대 대기
    private let maxBackoffDelay: TimeInterval = 30
    /// 상한 도달 후 유지 재시도 간격(초)
    private let steadyRetryInterval: TimeInterval = 60

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
                    // 조용히(silent) 지수 백오프 재시도 스케줄
                    self.scheduleRetry()
                    return
                }

                self.rewardedAd = ad
                self.rewardedAd?.fullScreenContentDelegate = self
                self.isAdReady = true
                // 성공 → 재시도 카운터/타이머 리셋
                self.resetRetry()
                logger.info("[RewardedAd] 광고 로드 완료")
            }
        }
    }

    // MARK: - Silent Retry

    /// 로드 실패 시 지수 백오프로 다음 재시도를 스케줄한다(조용히, 알림 없음).
    /// 중복 스케줄 방지를 위해 기존 retryTask는 cancel 후 새로 시작한다.
    private func scheduleRetry() {
        // 이미 로드됐거나 로딩 중이면 재시도 불필요
        guard !isAdReady, !isLoadingAd else { return }

        retryTask?.cancel()

        let delay: TimeInterval
        if retryCount < 4 {
            // 4 → 8 → 16 → 30(상한) 순으로 증가
            delay = min(maxBackoffDelay, pow(2.0, Double(retryCount + 2)))
            retryCount += 1
        } else {
            // 상한 도달 후 — 일정 간격으로 조용히 유지 재시도
            delay = steadyRetryInterval
            retryCount += 1
        }

        logger.info("[RewardedAd] 재시도 스케줄: \(self.retryCount)차, \(delay, format: .fixed(precision: 0))초 후 (silent)")

        retryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard let self, !Task.isCancelled else { return }
            // sleep 동안 다른 경로로 로드됐을 수 있으니 guard로 한 번 더 차단
            guard !self.isAdReady, !self.isLoadingAd else {
                logger.info("[RewardedAd] 재시도 취소 — 이미 로드됨/로딩 중")
                return
            }
            logger.info("[RewardedAd] 재시도 실행: \(self.retryCount)차")
            self.loadAd()
        }
    }

    /// 광고 로드 성공 시 재시도 상태를 초기화한다.
    private func resetRetry() {
        retryTask?.cancel()
        retryTask = nil
        if retryCount != 0 {
            logger.info("[RewardedAd] 재시도 카운터 리셋 (이전 \(self.retryCount)차)")
        }
        retryCount = 0
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
            // 광고를 정상 표시/닫은 새 사이클 — 백오프 카운터 초기화 후 다음 광고 preload
            resetRetry()
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

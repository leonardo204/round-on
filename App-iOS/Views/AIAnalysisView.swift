import SwiftUI
import Shared
import os.log

// MARK: - AIAnalysisView
// AI 분석 팝업 — 남은 무료 분석 횟수 + 보상형 광고 충전 + 개인정보 전송 정책 통합
// SettingsView "AI 분석" 행 탭 또는 할당량 소진 시 노출

struct AIAnalysisView: View {

    private static let logger = Logger(subsystem: "kr.zerolive.golf.roundon", category: "view")

    /// 충전 시도가 끝났을 때 호출 — 호출부가 원래 하려던 작업을 재개하는 데 사용한다.
    /// SettingsView처럼 단독 진입한 경우 nil (재개할 작업이 없어 부작용 없음).
    var onRefilled: ((RewardedAdManager.RefillOutcome) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var adManager = RewardedAdManager.shared

    // 개인정보 섹션
    private let privacyURLString = "https://golf.zerolive.co.kr/privacy"
    @State private var showPrivacySafari = false
    @State private var showRevokeAlert = false
    @State private var consentRefreshTick = false

    // 광고 관련
    @State private var isLoadingAd = false
    @State private var showFallbackGrantedAlert = false
    @State private var showAdUnavailableAlert = false

    var body: some View {
        NavigationStack {
            List {
                quotaSection
                privacySection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("AI 사용 설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            .sheet(isPresented: $showPrivacySafari) {
                if let url = URL(string: privacyURLString) {
                    SafariView(url: url)
                        .ignoresSafeArea()
                }
            }
            .alert("동의를 철회하시겠습니까?", isPresented: $showRevokeAlert) {
                Button("철회", role: .destructive) {
                    ConsentManager.shared.revoke()
                    consentRefreshTick.toggle()
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("철회하면 이후 사진 전송이 중단되고 기기 내 인식으로 처리됩니다.")
            }
            .alert("1회 충전했어요", isPresented: $showFallbackGrantedAlert) {
                Button("확인", role: .cancel) {}
            } message: {
                Text("지금은 광고를 불러올 수 없어 1회만 충전했어요. 이 1회를 사용한 뒤 다시 시도하면 광고로 더 충전할 수 있어요.")
            }
            .alert("지금은 광고를 불러올 수 없어요", isPresented: $showAdUnavailableAlert) {
                Button("확인", role: .cancel) {}
            } message: {
                Text("남은 무료 분석을 모두 사용한 뒤 다시 시도하면 광고로 충전할 수 있어요.")
            }
        }
    }

    // MARK: - 할당량 섹션

    private var quotaSection: some View {
        Section {
            VStack(spacing: 16) {
                // 남은 횟수 도트 표시
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { idx in
                        Circle()
                            .fill(idx < adManager.remaining
                                  ? Color.accentGreen
                                  : Color(.systemGray4))
                            .frame(width: 14, height: 14)
                    }
                    Spacer().frame(width: 8)
                    Text("\(adManager.remaining) / 3회")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(adManager.remaining > 0 ? Color.accentGreen : Color.secondary)
                }

                Text(adManager.remaining > 0
                     ? "AI 스코어카드 분석을 \(adManager.remaining)회 더 사용할 수 있어요."
                     : "무료 분석을 모두 사용했어요.\n아래 광고를 보고 3회를 다시 받아보세요.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                // 충전 버튼
                Button {
                    Task { await watchAdAndRefill() }
                } label: {
                    HStack(spacing: 8) {
                        if isLoadingAd {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        } else {
                            Image(systemName: "play.rectangle.fill")
                        }
                        Text(isLoadingAd ? "광고 불러오는 중..." : "광고 보고 3회 충전")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(adManager.remaining >= 3
                                ? Color(.systemGray4)
                                : Color.accentGreen)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(adManager.remaining >= 3 || isLoadingAd)
            }
            .padding(.vertical, 8)
        } header: {
            Text("남은 무료 분석")
        } footer: {
            Text("분석 1회 사용 시 남은 횟수가 줄어듭니다. 소진 후 광고(약 30초)를 시청하면 3회가 다시 충전됩니다. 광고를 불러올 수 없을 때는 1회만 충전됩니다.")
        }
    }

    // MARK: - 개인정보 섹션

    private var privacySection: some View {
        Section {
            // 동의 상태
            privacyInfoRow(title: "동의 상태", detail: consentStatusText)

            // 전송 데이터
            privacyInfoRow(title: "전송 데이터", detail: "스코어카드 사진(분석 시), 촬영일")

            // 수신자
            privacyInfoRow(title: "수신자", detail: "Google LLC (Gemini API)")

            // 목적
            privacyInfoRow(title: "목적", detail: "스코어카드 자동 인식 · 분석 후 별도 저장 안 함")

            // 동의 시점
            privacyInfoRow(title: "동의 시점", detail: "스코어카드 최초 분석 시 명시 동의, 동의 전에는 전송하지 않음")

            // 처리방침 보기
            Button {
                showPrivacySafari = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 15))
                        .foregroundStyle(.tint)
                        .frame(width: 24)
                    Text("개인정보 처리방침 보기")
                        .font(.body)
                        .foregroundStyle(.tint)
                    Spacer()
                    Image(systemName: "safari")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(.tertiaryLabel))
                }
                .padding(.vertical, 4)
            }

            // 동의 철회 (동의 상태일 때만 노출)
            if ConsentManager.shared.isAccepted || consentRefreshTick {
                if ConsentManager.shared.isAccepted {
                    Button(role: .destructive) {
                        showRevokeAlert = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "hand.raised")
                                .font(.system(size: 15))
                                .frame(width: 24)
                            Text("데이터 전송 동의 철회")
                                .font(.body)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        } header: {
            Text("개인정보 및 데이터 전송")
        } footer: {
            Text("Gemini AI를 이용한 스코어카드 분석 기능에만 적용됩니다. 동의 철회 시 이후 사진은 기기 내 인식으로만 처리됩니다.")
        }
    }

    // MARK: - 광고 시청 + 충전

    private func watchAdAndRefill() async {
        guard let rootVC = RewardedAdManager.getRootViewController() else { return }
        isLoadingAd = true
        defer { isLoadingAd = false }
        let outcome = await adManager.requestRefill(from: rootVC)
        switch outcome {
        case .rewarded:
            Self.logger.info("[AIAnalysis] 충전 결과: rewarded(광고 보상 3회)")
        case .fallbackGranted:
            Self.logger.info("[AIAnalysis] 충전 결과: fallbackGranted(광고 미가용 + 잔여 0 → 1회 폴백)")
            showFallbackGrantedAlert = true
        case .adUnavailable:
            Self.logger.info("[AIAnalysis] 충전 결과: adUnavailable(광고 미가용 + 잔여 있음 → 안내만)")
            showAdUnavailableAlert = true
        case .dismissed:
            Self.logger.info("[AIAnalysis] 충전 결과: dismissed(보상 전 닫음)")
        }
        // 충전 결과를 호출부에 전달 — 재개 여부는 호출부가 outcome으로 판단한다
        onRefilled?(outcome)
    }

    // MARK: - Helpers

    private var consentStatusText: String {
        _ = consentRefreshTick
        if ConsentManager.shared.isAccepted {
            if let date = ConsentManager.shared.acceptedDate {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy.MM.dd"
                return "동의함 ✓ (\(formatter.string(from: date)))"
            }
            return "동의함 ✓"
        }
        return "미동의"
    }

    @ViewBuilder
    private func privacyInfoRow(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

#if DEBUG
#Preview {
    AIAnalysisView()
}
#endif

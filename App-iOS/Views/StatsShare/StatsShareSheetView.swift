import SwiftUI
import SafariServices
import SwiftData
import Shared

// MARK: - StatsShareSheetView
// 통계 시그니처 카드 공유 시트 (stats-share-v1)
// - 카드 종류 픽커 3종 (PR/HCP/TREND) — 픽토그램 아이콘
// - 카드 미리보기 (280pt 축소)
// - 닉네임 입력 (비워두면 자동 "익명") + PIN 토글
// - 공유 성공 시 StatsShareRecord SwiftData 저장 + 시트 자동 dismiss
// - URL row: 바로보기(safari) / 복사(doc.on.doc) / 공유(square.and.arrow.up)

struct StatsShareSheetView: View {

    // MARK: Props

    let initialCardKind: StatsSignatureCardKind
    let stats: RoundStatisticsResult
    let regionStats: [RegionStats]
    let roundLocations: [RoundLocation]
    let bestRound: BestRoundInfo?
    @Binding var isPresented: Bool

    // MARK: Environment

    @Environment(\.modelContext) private var modelContext

    // MARK: State

    @State private var vm: StatsShareViewModel
    @State private var renderedImage: UIImage?
    @State private var showShareSheet = false
    @State private var showSafari = false
    @State private var showCopyToast = false

    // MARK: Init

    init(
        initialCardKind: StatsSignatureCardKind,
        stats: RoundStatisticsResult,
        regionStats: [RegionStats],
        roundLocations: [RoundLocation] = [],
        bestRound: BestRoundInfo?,
        isPresented: Binding<Bool>
    ) {
        self.initialCardKind = initialCardKind
        self.stats = stats
        self.regionStats = regionStats
        self.roundLocations = roundLocations
        self.bestRound = bestRound
        self._isPresented = isPresented

        // ViewModel 초기화 — API 클로저는 뷰 레벨에서 바인딩
        let capturedStats = stats
        let capturedRegionStats = regionStats
        let capturedRoundLocations = roundLocations
        let capturedBestRound = bestRound

        self._vm = State(initialValue: StatsShareViewModel(
            initialCardKind: initialCardKind,
            initialDisplayName: "",
            payloadBuilder: { kind, displayName in
                StatsSharePayloadBuilder.build(
                    cardKind: kind,
                    stats: capturedStats,
                    regionStats: capturedRegionStats,
                    rawDisplayName: displayName,
                    bestRoundCourseName: capturedBestRound?.courseName,
                    bestRoundDate: capturedBestRound?.date,
                    bestRoundTotalScore: capturedBestRound?.totalScore,
                    bestRoundIsPR: capturedStats.isPersonalRecord,
                    roundLocations: capturedRoundLocations
                )
            },
            createStatsShare: {
                // 실제 API 호출 — 클로저가 나중에 교체됨. 기본값은 mock.
                throw ShareAPIError.networkError(URLError(.notConnectedToInternet))
            }
        ))
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color.paleSageBg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // ① 카드 종류 픽커
                        cardKindPickerSection

                        // ② 카드 미리보기
                        cardPreviewSection

                        // ③ URL 미리보기 (생성 후)
                        if case .success(let url, _) = vm.loadState {
                            urlPreviewSection(url: url)
                        }

                        // ④ 옵션 (닉네임 + PIN + 만료)
                        optionsSection

                        // ⑤ 에러
                        if case .failed(let msg) = vm.loadState {
                            BannerNotice(message: msg, severity: .error, dismissAction: {
                                vm.loadState = .idle
                            })
                        }

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }

                // 하단 CTA
                VStack {
                    Spacer()
                    ctaArea
                }
            }
            .navigationTitle("통계 공유")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("닫기") { isPresented = false }
                        .foregroundStyle(Color.inkSoft)
                }
            }
        }
        .task {
            // 카드 이미지 사전 렌더
            renderCard()
        }
        .onChange(of: vm.cardKind) { _, _ in
            renderCard()
        }
        .onChange(of: vm.loadState) { _, newState in
            if case .success = newState {
                renderCard()
            }
        }
    }

    // MARK: - ① 카드 종류 픽커

    private var cardKindPickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("카드 종류")

            HStack(spacing: 10) {
                ForEach(StatsSignatureCardKind.allCases, id: \.rawValue) { kind in
                    cardKindPill(kind)
                }
            }
        }
    }

    private func cardKindPill(_ kind: StatsSignatureCardKind) -> some View {
        let isSelected = vm.cardKind == kind
        return Button {
            vm.cardKind = kind
            if case .success = vm.loadState { vm.loadState = .idle }
        } label: {
            VStack(spacing: 6) {
                // 픽토그램 아이콘 (66pt)
                cardKindIcon(kind)
                    .frame(width: 66, height: 66)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? cardAccentColor(kind) : Color.cardBorder,
                                    lineWidth: isSelected ? 2 : 1)
                    )

                Text(cardKindLabel(kind))
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? cardAccentColor(kind) : Color.inkSoft)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func cardKindIcon(_ kind: StatsSignatureCardKind) -> some View {
        switch kind {
        case .pr:
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(Color.scoreBirdie.opacity(0.12))
                VStack(spacing: 2) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.scoreBirdie)
                    Text("PR")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(Color.scoreBirdie)
                }
            }
        case .hcp:
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(Color.houseGreen.opacity(0.10))
                VStack(spacing: 2) {
                    Image(systemName: "arrow.down.right.circle.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Color.houseGreen)
                    Text("HDCP")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(Color.houseGreen)
                }
            }
        case .trend:
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(Color.accentGreen.opacity(0.10))
                VStack(spacing: 2) {
                    Image(systemName: "chart.line.downtrend.xyaxis")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.accentGreen)
                    Text("흐름")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(Color.accentGreen)
                }
            }
        }
    }

    // MARK: - ② 카드 미리보기

    private var cardPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("미리보기")

            let payload = vm.currentPayload()
            StatsSignatureCardView(
                signature: payload.signature,
                cardKind: vm.cardKind,
                dateISO: payload.createdAtISO
            )
            .scaleEffect(0.26)
            .frame(width: 1080 * 0.26, height: 1080 * 0.26)
            .frame(maxWidth: .infinity)
            .background(Color.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.cardBorder, lineWidth: 1)
            )
        }
    }

    // MARK: - ③ URL 미리보기

    private func urlPreviewSection(url: URL) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("공유 링크")

            HStack(spacing: 8) {
                Text(url.absoluteString
                        .replacingOccurrences(of: "https://", with: ""))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color.accentGreen)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 6) {
                    // 바로보기 — safari
                    compactIconButton(icon: "safari", label: "바로보기") {
                        showSafari = true
                        AppLogger.share.info("[StatsShareSheet] 바로보기: \(url.absoluteString)")
                    }
                    // 복사 — doc.on.doc
                    compactIconButton(icon: "doc.on.doc", label: "복사") {
                        UIPasteboard.general.string = url.absoluteString
                        Task { await HapticEngine.shared.play(.shareSuccess) }
                        withAnimation { showCopyToast = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation { showCopyToast = false }
                        }
                        AppLogger.share.info("[StatsShareSheet] 링크 복사: \(url.absoluteString)")
                    }
                    // 공유 — square.and.arrow.up
                    compactIconButton(icon: "square.and.arrow.up", label: "공유") {
                        showSystemShare(url: url)
                        AppLogger.share.info("[StatsShareSheet] URL row 공유: \(url.absoluteString)")
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.accentGreen.opacity(0.30), lineWidth: 1)
            )
            .overlay(alignment: .bottom) {
                if showCopyToast {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.accentGreen)
                        Text("링크가 복사됐어요")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.inkPrimary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.cardSurface)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.10), radius: 6, x: 0, y: 2)
                    .offset(y: -50)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .sheet(isPresented: $showSafari) {
                SafariView(url: url)
                    .ignoresSafeArea()
            }

            Text("7일 후 자동 만료")
                .font(.system(size: 11))
                .foregroundStyle(Color.inkFaint)
        }
    }

    // MARK: - compactIconButton (라운드 공유와 동일 패턴)

    private func compactIconButton(
        icon: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundStyle(Color.accentGreen)
            .frame(width: 44, height: 38)
            .background(Color.accentGreen.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
        .accessibilityLabel(label)
    }

    // MARK: - ④ 옵션 섹션

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("옵션")

            VStack(spacing: 0) {
                // 닉네임 입력 (비워두면 자동 "익명")
                HStack {
                    Text("닉네임")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.inkPrimary)
                    Spacer()
                    TextField("이름 (비워두면 익명)", text: $vm.displayName)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.inkPrimary)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 160)
                        .submitLabel(.done)
                }
                .padding(16)

                Divider().padding(.leading, 16)

                // PIN 토글
                Toggle(isOn: $vm.usePin) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("PIN 보호")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.inkPrimary)
                        Text("4자리 PIN을 아는 사람만 열람 가능")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.inkSoft)
                    }
                }
                .tint(Color.accentGreen)
                .padding(16)

                // PIN 입력 (토글 ON 시)
                if vm.usePin {
                    Divider().padding(.leading, 16)

                    HStack {
                        Text("PIN")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.inkPrimary)
                        Spacer()
                        SecureField("4자리 숫자", text: $vm.pin)
                            .font(.system(size: 15))
                            .foregroundStyle(Color.inkPrimary)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                            .frame(width: 120)
                        if !vm.pin.isEmpty && !vm.isPinValid {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(.red)
                                .font(.system(size: 14))
                        }
                    }
                    .padding(16)
                }

                Divider().padding(.leading, 16)

                // 만료 안내 (고정)
                HStack {
                    Text("유효 기간")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.inkPrimary)
                    Spacer()
                    Text("7일")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.inkSoft)
                }
                .padding(16)
            }
            .background(Color.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.cardBorder, lineWidth: 1)
            )
        }
    }

    // MARK: - ⑤ CTA 영역

    @ViewBuilder
    private var ctaArea: some View {
        VStack(spacing: 0) {
            if case .success(let url, _) = vm.loadState {
                // 성공 상태: UIActivityViewController (PNG 이미지 + URL 동시 공유)
                Button {
                    showSystemShare(url: url)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 17, weight: .semibold))
                        Text("공유하기")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.accentGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
                .accessibilityLabel("통계 카드와 링크 공유")
            } else {
                // 초기/로딩 상태: 공유 링크 생성 CTA
                Button {
                    Task { await handleGenerateAndShare() }
                } label: {
                    Group {
                        if case .loading = vm.loadState {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("공유 링크 생성")
                                .font(.system(size: 17, weight: .semibold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(vm.canGenerate ? Color.accentGreen : Color.inkFaint)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
                .disabled(!vm.canGenerate)
            }
        }
        .background(
            LinearGradient(
                colors: [Color.paleSageBg.opacity(0), Color.paleSageBg],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Actions

    private func handleGenerateAndShare() async {
        // ShareAPIClient를 ViewModel에 실제 클로저로 교체한 후 호출
        // 이 뷰 레벨에서 ShareAPIClient 인스턴스를 직접 보유하고 클로저 재구성
        let client = ShareAPIClient()
        let payload = vm.currentPayload()
        let pinValue = vm.usePin ? vm.pin : nil
        let deviceToken = UUID().uuidString  // 익명 UUID (deviceToken rate limit용)

        // ViewModel 내부 apiClientClosure를 직접 대체하는 대신,
        // 여기서 직접 API 호출 후 loadState를 조작
        vm.loadState = .loading
        AppLogger.share.info("[StatsShareSheet] createStatsShare 시작 — cardKind=\(payload.cardKind.rawValue)")

        do {
            let resp = try await client.createStatsShare(
                payload: payload,
                pin: pinValue,
                deviceToken: deviceToken
            )
            // Keychain에 stats editToken 저장
            try? KeychainStore.shared.setStatsEditToken(resp.editToken, for: resp.shortId)

            if let url = URL(string: resp.url) {
                // SwiftData에 StatsShareRecord 저장 (기존 레코드 모두 제거 후 신규 저장)
                saveStatsShareRecord(resp: resp, cardKind: payload.cardKind)

                vm.loadState = .success(url: url, shortId: resp.shortId)
                renderCard()
                AppLogger.share.info("[StatsShareSheet] 성공 — url=\(resp.url)")
                Task { await HapticEngine.shared.play(.shareSuccess) }

                // 0.5초 후 시트 자동 닫힘 (영속 카드가 통계 화면에 즉시 표시됨)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isPresented = false
                }
            } else {
                vm.loadState = .failed("URL 생성 실패")
            }
        } catch {
            AppLogger.share.error("[StatsShareSheet] 오류: \(error.localizedDescription)")
            vm.loadState = .failed(error.localizedDescription)
            Task { await HapticEngine.shared.play(.shareError) }
        }
    }

    /// 기존 StatsShareRecord 모두 삭제 후 신규 저장 (사용자당 1건 유지)
    private func saveStatsShareRecord(resp: StatsShareCreateResponse, cardKind: StatsSignatureCardKind) {
        do {
            // 기존 레코드 모두 삭제
            let existing = try modelContext.fetch(FetchDescriptor<StatsShareRecord>())
            for record in existing {
                modelContext.delete(record)
            }
            // 신규 레코드 저장
            let record = StatsShareRecord(
                shortId: resp.shortId,
                url: resp.url,
                createdAt: .now,
                expiresAt: resp.expiresAt,
                cardKindRaw: cardKind.rawValue,
                displayName: vm.effectiveDisplayName
            )
            modelContext.insert(record)
            try modelContext.save()
            AppLogger.share.info("[StatsShareSheet] StatsShareRecord 저장 — shortId=\(resp.shortId)")
        } catch {
            AppLogger.share.error("[StatsShareSheet] StatsShareRecord 저장 실패: \(error)")
        }
    }

    private func renderCard() {
        let payload = vm.currentPayload()
        renderedImage = StatsShareImageRenderer.renderSignatureCard(
            signature: payload.signature,
            cardKind: vm.cardKind,
            dateISO: payload.createdAtISO
        )
    }

    /// 시스템 공유 시트 호출 — PNG 이미지 + URL 동시 첨부
    private func showSystemShare(url: URL) {
        var activityItems: [Any] = [url]
        if let image = renderedImage {
            // PNG 이미지를 URL 앞에 추가 (카드 이미지 + 링크 동시 공유)
            activityItems.insert(image, at: 0)
        }
        let vc = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        // 현재 Scene의 rootViewController 탐색
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            var presentingVC = rootVC
            while let presented = presentingVC.presentedViewController {
                presentingVC = presented
            }
            vc.popoverPresentationController?.sourceView = presentingVC.view
            presentingVC.present(vc, animated: true)
        }
        AppLogger.share.info("[StatsShareSheet] 시스템 공유 시트 호출 — url=\(url.absoluteString)")
    }

    // MARK: - Helpers

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.inkSoft)
            .textCase(.uppercase)
            .kerning(0.8)
            .padding(.leading, 4)
    }

    private func cardKindLabel(_ kind: StatsSignatureCardKind) -> String {
        switch kind {
        case .pr:    return "PR"
        case .hcp:   return "핸디캡"
        case .trend: return "흐름"
        }
    }

    private func cardAccentColor(_ kind: StatsSignatureCardKind) -> Color {
        switch kind {
        case .pr:    return Color.scoreBirdie
        case .hcp:   return Color.houseGreen
        case .trend: return Color.accentGreen
        }
    }
}

// MARK: - StatsSignatureCardKind + allCases

extension StatsSignatureCardKind: CaseIterable {
    public static var allCases: [StatsSignatureCardKind] = [.pr, .hcp, .trend]
}

// UIActivityViewController를 통한 PNG 이미지 + URL 동시 공유 (showSystemShare 참조)

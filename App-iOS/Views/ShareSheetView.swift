import SwiftUI
import Shared

// MARK: - ShareSheetView
// iphone-2.7: 공유 옵션 + 링크 생성 (12-SCREENS 2.7)
// 이름 공개 토글 + PIN 입력 + "공유 링크 생성" CTA
// B2: 링크 생성 성공 후 사진 자동 업로드
// C3: editToken은 Keychain을 통해 조회

struct ShareSheetView: View {

    // MARK: Props

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let round: Round
    @Bindable var shareVM: ShareViewModel
    let onShared: ((URL) -> Void)?

    // MARK: State

    @State private var showActivitySheet = false
    @State private var activityURL: URL?
    @State private var toastMessage: String?

    private let apiClient = ShareAPIClient()
    private let keychainStore = KeychainStore.shared

    // MARK: Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color.springSurface.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // 에러 배너
                        if let error = shareVM.errorMessage {
                            BannerNotice(message: error, severity: .error, dismissAction: {
                                shareVM.errorMessage = nil
                            })
                        }

                        // 이름 공개 토글
                        nameVisibilitySection

                        // PIN 설정
                        accessControlSection

                        // PIN 입력 (pin 선택 시)
                        if case .pin = shareVM.accessControl {
                            pinSection
                        }

                        // 현재 공유 링크 정보 (업데이트 모드)
                        if let url = round.sharedURL, round.sharedShortId != nil {
                            currentLinkSection(url: url)
                        }

                        Spacer(minLength: 80)
                    }
                    .padding(.top, 16)
                    .padding(.horizontal, 16)
                }

                // 하단 CTA
                VStack {
                    Spacer()
                    ctaButton
                }
            }
            .navigationTitle(shareVM.isUpdateMode ? "viewer 업데이트" : "공유하기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                }
            }
            .sheet(isPresented: $showActivitySheet) {
                if let url = activityURL {
                    ActivityShareSheet(url: url)
                        .presentationDetents([.medium, .large])
                }
            }
            .overlay(alignment: .bottom) {
                if let msg = toastMessage {
                    Text(msg)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(.black.opacity(0.85), in: Capsule())
                        .padding(.bottom, 100)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: toastMessage)
            .task {
                // C2: 앱 진입 시 기존 평문 editToken을 Keychain으로 마이그레이션
                keychainStore.migrateIfNeeded(round: round)
                do {
                    try modelContext.save()
                } catch {
                    AppLogger.share.error("[ShareSheet] editToken 마이그레이션 저장 실패: \(error.localizedDescription)")
                }
            }
        }
    }

    private func showToast(_ message: String) {
        toastMessage = message
        Task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            await MainActor.run {
                if toastMessage == message { toastMessage = nil }
            }
        }
    }

    // MARK: 이름 공개 섹션

    private var nameVisibilitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("이름 공개")

            VStack(spacing: 0) {
                Toggle(isOn: Binding(
                    get: { shareVM.nameVisibility == .real },
                    set: { shareVM.nameVisibility = $0 ? .real : .anonymous }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(shareVM.nameVisibility == .real ? "실명 공개" : "익명 (A/B/C/D)")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.springTextPrimary)
                        Text(shareVM.nameVisibility == .real
                            ? "플레이어 이름이 그대로 표시됩니다."
                            : "이름 대신 A, B, C, D로 표시됩니다.")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.springTextSecondary)
                    }
                }
                .tint(Color.springGreenPrimary)
                .padding(16)
            }
            .background(Color.springSurfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: 접근 제어 섹션

    private var accessControlSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("접근 제한")

            VStack(spacing: 8) {
                accessOption(
                    title: "전체 공개",
                    subtitle: "링크를 가진 누구나 볼 수 있어요.",
                    isSelected: {
                        if case .public = shareVM.accessControl { return true }
                        return false
                    }(),
                    action: { shareVM.accessControl = .public }
                )

                accessOption(
                    title: "PIN 보호",
                    subtitle: "4자리 PIN을 아는 사람만 볼 수 있어요.",
                    isSelected: {
                        if case .pin = shareVM.accessControl { return true }
                        return false
                    }(),
                    action: {
                        shareVM.accessControl = .pin(shareVM.pinInput)
                    }
                )
            }
        }
    }

    private func accessOption(title: String, subtitle: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.springTextPrimary)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.springTextSecondary)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.springGreenPrimary : Color.springBorder)
                    .font(.system(size: 20))
            }
            .padding(16)
            .background(Color.springSurfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: PIN 입력 섹션

    private var pinSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("PIN 설정")

            VStack(spacing: 8) {
                Text("4자리 숫자 PIN을 설정해 주세요.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.springTextSecondary)

                PinInputField(
                    pin: $shareVM.pinInput,
                    isError: !shareVM.isPinValid && !shareVM.pinInput.isEmpty
                )
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8)
            }
            .padding(16)
            .background(Color.springSurfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: 현재 링크 섹션

    private func currentLinkSection(url: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("현재 공유 링크")

            HStack(spacing: 10) {
                Text(url)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Color.springGreenPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                // 복사
                Button {
                    UIPasteboard.general.string = url
                    showToast("링크를 복사했어요")
                    AppLogger.share.info("[ShareSheet] 링크 복사: \(url)")
                    Task { await HapticEngine.shared.play(.shareSuccess) }
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.springGreenPrimary)
                        .frame(width: 36, height: 36)
                        .background(Color.springGreenSecondary.opacity(0.25), in: Circle())
                }
                .accessibilityLabel("링크 복사")

                // 공유 (UIActivityViewController)
                Button {
                    if let u = URL(string: url) {
                        AppLogger.share.info("[ShareSheet] 시스템 공유 시트 호출: \(url)")
                        showActivity(url: u)
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.springGreenPrimary, in: Circle())
                }
                .accessibilityLabel("공유")
            }
            .padding(16)
            .background(Color.springSurfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // 만료일
            if let expiresAt = round.sharedExpiresAt {
                Text("만료: \(formattedDate(expiresAt))")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.springTextSecondary)
            }

            // viewer 회수 버튼 (C3: Keychain에서 editToken 조회)
            if let shortId = round.sharedShortId,
               let editToken = keychainStore.editToken(for: shortId) {
                Button {
                    Task { await deleteShare(shortId: shortId, editToken: editToken) }
                } label: {
                    Text("viewer 회수")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color(red: 1.0, green: 0.92, blue: 0.92))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    // MARK: CTA 버튼

    private var ctaButton: some View {
        VStack(spacing: 0) {
            Button {
                Task { await performShare() }
            } label: {
                Group {
                    if shareVM.isLoading {
                        ProgressView()
                            .tint(Color.springTextPrimary)
                    } else {
                        Text(shareVM.isUpdateMode ? "viewer 업데이트" : "공유 링크 생성")
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
                .foregroundStyle(Color.springTextPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(shareVM.canShare ? Color.springGreenPrimary : Color.springBorder)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .disabled(!shareVM.canShare)
        }
        .background(
            LinearGradient(
                colors: [Color.springSurface.opacity(0), Color.springSurface],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: Helpers

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.springTextSecondary)
            .textCase(.uppercase)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")  // KST 강제 — 디바이스 timezone 무관
        return formatter.string(from: date)
    }

    // MARK: Share Actions

    private func performShare() async {
        AppLogger.share.info("[ShareSheet] performShare 진입 (mode=\(shareVM.isUpdateMode ? "update" : "create"))")
        guard shareVM.canShare else {
            AppLogger.share.error("[ShareSheet] canShare=false — 차단 (isLoading=\(shareVM.isLoading), pinValid=\(shareVM.isPinValid))")
            return
        }
        shareVM.errorMessage = nil
        shareVM.isLoading = true
        defer { shareVM.isLoading = false }

        let options = shareVM.currentOptions()
        AppLogger.share.debug("[ShareSheet] options: nameVisibility=\(String(describing: options.nameVisibility)), access=\(String(describing: options.accessControl))")
        // C3: Keychain 기반 deviceToken 생성 (shortId 없으면 신규 UUID)
        let deviceToken = UUID().uuidString

        do {
            if shareVM.isUpdateMode,
               let shortId = round.sharedShortId,
               let editToken = keychainStore.editToken(for: shortId) {
                AppLogger.share.info("[ShareSheet] update 모드 — shortId=\(shortId)")
                let payload = UpdateShareRequest(
                    round: RoundPayload(from: round, nameVisibility: options.nameVisibility),
                    options: ShareOptionsPayload(from: options)
                )
                let response = try await apiClient.updateShare(shortId: shortId, editToken: editToken, request: payload)
                round.sharedURL = response.url
                round.sharedExpiresAt = response.expiresAt
                round.sharedOptions = options
                do {
                    try modelContext.save()
                } catch {
                    AppLogger.share.error("[ShareSheet] modelContext.save 실패 (update): \(error.localizedDescription)")
                }

                if let url = URL(string: response.url) {
                    AppLogger.share.info("[ShareSheet] update 완료, viewer=\(url.absoluteString)")
                    showActivity(url: url)
                } else {
                    AppLogger.share.error("[ShareSheet] response.url 파싱 실패: \(response.url)")
                }
            } else {
                if shareVM.isUpdateMode {
                    AppLogger.share.warning("[ShareSheet] update 모드 진입 조건 실패 (shortId/editToken 누락) → 신규 생성으로 fallback")
                }
                AppLogger.share.info("[ShareSheet] create 모드 — deviceToken=\(deviceToken.prefix(8))…")
                let payload = CreateShareRequest(
                    deviceToken: deviceToken,
                    round: RoundPayload(from: round, nameVisibility: options.nameVisibility),
                    options: ShareOptionsPayload(from: options)
                )
                let response = try await apiClient.createShare(request: payload)

                do {
                    try keychainStore.setEditToken(response.editToken, for: response.shortId)
                    AppLogger.share.debug("[ShareSheet] editToken Keychain 저장 OK — shortId=\(response.shortId)")
                } catch {
                    AppLogger.share.error("[ShareSheet] Keychain 저장 실패: \(error.localizedDescription)")
                }

                round.sharedShortId = response.shortId
                round.sharedURL = response.url
                round.sharedExpiresAt = response.expiresAt
                round.sharedOptions = options
                round.sharedEditToken = nil  // C2: Deprecated 평문 필드 정리
                do {
                    try modelContext.save()
                } catch {
                    AppLogger.share.error("[ShareSheet] modelContext.save 실패 (create): \(error.localizedDescription)")
                }

                if let url = URL(string: response.url) {
                    AppLogger.share.info("[ShareSheet] create 완료, viewer=\(url.absoluteString)")
                    showActivity(url: url)
                    onShared?(url)
                } else {
                    AppLogger.share.error("[ShareSheet] response.url 파싱 실패: \(response.url)")
                }
                Task { await HapticEngine.shared.play(.shareSuccess) }
            }
        } catch let error as ShareAPIError {
            AppLogger.share.error("[ShareSheet] ShareAPIError: \(error.localizedDescription)")
            shareVM.errorMessage = error.localizedDescription
            Task { await HapticEngine.shared.play(.shareError) }
        } catch {
            AppLogger.share.error("[ShareSheet] 알 수 없는 오류: \(error.localizedDescription)")
            shareVM.errorMessage = "알 수 없는 오류가 발생했어요."
            Task { await HapticEngine.shared.play(.shareError) }
        }
    }

    // uploadPhotosIfNeeded는 2026-05-18 폐기 (사진 공유 기능 제거)

    private func deleteShare(shortId: String, editToken: String) async {
        AppLogger.share.info("[ShareSheet] deleteShare 진입 — shortId=\(shortId)")
        do {
            try await apiClient.deleteShare(shortId: shortId, editToken: editToken)
            // C2: Keychain에서도 삭제
            do {
                try keychainStore.deleteEditToken(for: shortId)
            } catch {
                AppLogger.share.warning("[ShareSheet] Keychain 삭제 실패 (이미 없을 수도): \(error.localizedDescription)")
            }
            round.sharedShortId = nil
            round.sharedURL = nil
            round.sharedEditToken = nil
            round.sharedExpiresAt = nil
            round.sharedOptions = nil
            do {
                try modelContext.save()
            } catch {
                AppLogger.share.error("[ShareSheet] deleteShare 후 modelContext.save 실패: \(error.localizedDescription)")
            }
            AppLogger.share.info("[ShareSheet] deleteShare 완료 — shortId=\(shortId)")
            dismiss()
        } catch let error as ShareAPIError {
            AppLogger.share.error("[ShareSheet] deleteShare ShareAPIError: \(error.localizedDescription)")
            shareVM.errorMessage = error.localizedDescription
        } catch {
            AppLogger.share.error("[ShareSheet] deleteShare 알 수 없는 오류: \(error.localizedDescription)")
            shareVM.errorMessage = "viewer 회수 중 오류가 발생했어요."
        }
    }

    private func showActivity(url: URL) {
        activityURL = url
        showActivitySheet = true
    }
}

// MARK: - ActivityShareSheet
// UIActivityViewController 래퍼

struct ActivityShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

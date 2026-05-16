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

    private let apiClient = ShareAPIClient()
    private let photoStore = PhotoStore()
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
            .task {
                // C2: 앱 진입 시 기존 평문 editToken을 Keychain으로 마이그레이션
                keychainStore.migrateIfNeeded(round: round)
                try? modelContext.save()
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

            HStack {
                Text(url)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Color.springGreenPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                Button {
                    UIPasteboard.general.string = url
                } label: {
                    Image(systemName: "doc.on.doc")
                        .foregroundStyle(Color.springGreenPrimary)
                }
                .accessibilityLabel("링크 복사")
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
            // 사진 업로드 진행 표시 (B2)
            if shareVM.isUploadingPhotos {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("사진 업로드 중 \(shareVM.photoUploadCurrent)/\(shareVM.photoUploadTotal)")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.springTextSecondary)
                }
                .padding(.bottom, 8)
            }

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
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: date)
    }

    // MARK: Share Actions

    private func performShare() async {
        guard shareVM.canShare else { return }
        shareVM.errorMessage = nil
        shareVM.isLoading = true
        defer { shareVM.isLoading = false }

        let options = shareVM.currentOptions()
        // C3: Keychain 기반 deviceToken 생성 (shortId 없으면 신규 UUID)
        let deviceToken = UUID().uuidString

        do {
            if shareVM.isUpdateMode,
               let shortId = round.sharedShortId,
               let editToken = keychainStore.editToken(for: shortId) {
                // 업데이트 모드 (C3: Keychain에서 editToken 조회)
                let payload = UpdateShareRequest(
                    round: RoundPayload(from: round, nameVisibility: options.nameVisibility),
                    options: ShareOptionsPayload(from: options)
                )
                let response = try await apiClient.updateShare(shortId: shortId, editToken: editToken, request: payload)
                round.sharedURL = response.url
                round.sharedExpiresAt = response.expiresAt
                round.sharedOptions = options
                try? modelContext.save()

                if let url = URL(string: response.url) {
                    showActivity(url: url)
                }
            } else {
                // 신규 생성
                let payload = CreateShareRequest(
                    deviceToken: deviceToken,
                    round: RoundPayload(from: round, nameVisibility: options.nameVisibility),
                    options: ShareOptionsPayload(from: options)
                )
                let response = try await apiClient.createShare(request: payload)

                // C2: editToken을 Keychain에 저장 (평문 필드 사용 안 함)
                try? keychainStore.setEditToken(response.editToken, for: response.shortId)

                round.sharedShortId = response.shortId
                round.sharedURL = response.url
                round.sharedExpiresAt = response.expiresAt
                round.sharedOptions = options
                // Deprecated 필드는 nil 유지 (Keychain으로 이관 완료)
                round.sharedEditToken = nil
                try? modelContext.save()

                if let url = URL(string: response.url) {
                    showActivity(url: url)
                    onShared?(url)
                }
                Task { await HapticEngine.shared.play(.shareSuccess) }

                // B2: 공유 링크 생성 성공 후 사진 자동 업로드
                await uploadPhotosIfNeeded(shortId: response.shortId, editToken: response.editToken)
            }
        } catch let error as ShareAPIError {
            shareVM.errorMessage = error.localizedDescription
            Task { await HapticEngine.shared.play(.shareError) }
        } catch {
            shareVM.errorMessage = "알 수 없는 오류가 발생했어요."
            Task { await HapticEngine.shared.play(.shareError) }
        }
    }

    /// B2: photos를 순회하며 업로드. 실패 사진은 skip + 배너 알림.
    private func uploadPhotosIfNeeded(shortId: String, editToken: String) async {
        let photos = round.photoList
        guard !photos.isEmpty else { return }

        shareVM.photoUploadTotal = photos.count
        shareVM.photoUploadCurrent = 0
        shareVM.isUploadingPhotos = true
        defer { shareVM.isUploadingPhotos = false }

        var failedCount = 0

        for photo in photos {
            guard let imageData = photoStore.jpegData(for: photo) else {
                failedCount += 1
                shareVM.photoUploadCurrent += 1
                continue
            }

            do {
                let response = try await apiClient.uploadPhoto(
                    shortId: shortId,
                    editToken: editToken,
                    imageData: imageData,
                    holeNumber: photo.holeNumber,
                    caption: photo.caption
                )
                // remoteURL 업데이트
                photo.remoteURL = response.remoteURL
                shareVM.photoUploadCurrent += 1
            } catch {
                failedCount += 1
                shareVM.photoUploadCurrent += 1
            }
        }

        try? modelContext.save()

        let successCount = photos.count - failedCount
        if failedCount > 0 && successCount > 0 {
            shareVM.errorMessage = "사진 \(successCount)장 업로드 완료. \(failedCount)장은 실패했어요."
        } else if failedCount == 0 {
            // 성공 토스트 (에러 아님 — 배너 severity .info)
            shareVM.errorMessage = nil
        } else {
            shareVM.errorMessage = "사진 업로드에 실패했어요."
        }
    }

    private func deleteShare(shortId: String, editToken: String) async {
        do {
            try await apiClient.deleteShare(shortId: shortId, editToken: editToken)
            // C2: Keychain에서도 삭제
            try? keychainStore.deleteEditToken(for: shortId)
            round.sharedShortId = nil
            round.sharedURL = nil
            round.sharedEditToken = nil
            round.sharedExpiresAt = nil
            round.sharedOptions = nil
            try? modelContext.save()
            dismiss()
        } catch let error as ShareAPIError {
            shareVM.errorMessage = error.localizedDescription
        } catch {
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

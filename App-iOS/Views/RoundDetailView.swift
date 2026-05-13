import SwiftUI
import SwiftData
import Shared

// MARK: - RoundDetailView
// iphone-2.8: 완료 라운드 사후 보기 (12-SCREENS 2.8)
// viewer URL 복사 + 만료 표시 + 재공유 진입
// B3: 이미 공유된 라운드에 사진 추가 시 uploadPhoto 자동 호출

struct RoundDetailView: View {

    // MARK: Props

    @Environment(\.modelContext) private var modelContext
    let round: Round

    // MARK: State

    @State private var scoreVM: ScoreCardViewModel
    @State private var shareVM: ShareViewModel
    @State private var showShare = false
    @State private var showPhotoAttach = false
    @State private var bannerMessage: String?
    @State private var bannerSeverity: BannerNotice.Severity = .info

    private let apiClient = ShareAPIClient()
    private let photoStore = PhotoStore()
    private let keychainStore = KeychainStore.shared

    // MARK: Init

    init(round: Round) {
        self.round = round
        _scoreVM = State(initialValue: ScoreCardViewModel(round: round))
        _shareVM = State(initialValue: ShareViewModel(round: round))
    }

    // MARK: Body

    var body: some View {
        ZStack {
            Color.springSurface.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // 배너
                    if let msg = bannerMessage {
                        BannerNotice(message: msg, severity: bannerSeverity, dismissAction: {
                            bannerMessage = nil
                        })
                    }

                    // 라운드 요약
                    summaryHeader

                    // 공유 링크 섹션
                    shareLinkSection

                    // 홀별 스코어 요약
                    scoreSection

                    // 사진
                    photoSection

                    Spacer(minLength: 80)
                }
                .padding(.top, 16)
            }

            // 공유 버튼 (하단 고정)
            VStack {
                Spacer()
                shareButton
            }
        }
        .navigationTitle(round.courseName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShare) {
            ShareSheetView(round: round, shareVM: shareVM, onShared: { url in
                bannerMessage = "공유 링크가 생성되었어요."
                bannerSeverity = .success
            })
        }
        .sheet(isPresented: $showPhotoAttach) {
            PhotoAttachView(round: round, onDismiss: {
                showPhotoAttach = false
                // B3: 이미 공유된 라운드면 새로 추가된 사진을 업로드
                if round.sharedShortId != nil {
                    Task { await uploadNewPhotosIfShared() }
                }
            })
        }
        .task {
            // C2: 기존 평문 editToken Keychain 마이그레이션
            keychainStore.migrateIfNeeded(round: round)
            try? modelContext.save()

            // C4: 만료 자동 감지
            let expired = round.sharedExpiresAt.map { $0 < .now } ?? false
            if expired {
                shareVM.checkExpiration()
                bannerMessage = "공유 링크가 만료되었어요. 재공유해 주세요."
                bannerSeverity = .error
                Task { await HapticEngine.shared.play(.viewerExpired) }
            }
        }
    }

    // MARK: Summary Header

    private var summaryHeader: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if let sub = round.courseSubName {
                        Text(sub)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.springTextSecondary)
                    }
                    Text(formattedDate(round.finishedAt ?? round.date))
                        .font(.system(size: 13))
                        .foregroundStyle(Color.springTextSecondary)
                    Text("\(round.holes.count)홀")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.springTextSecondary)
                }
                Spacer()
                // 완료 뱃지
                Text("완료")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.springGreenPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.springGreenSecondary.opacity(0.3))
                    .clipShape(Capsule())
            }
            .padding(16)
        }
        .background(Color.springSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
        .padding(.horizontal, 16)
    }

    // MARK: Share Link Section

    private var shareLinkSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("공유 링크")
            .padding(.horizontal, 16)

            if let url = round.sharedURL, round.sharedShortId != nil {
                VStack(spacing: 8) {
                    HStack {
                        Text(url)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(Color.springGreenPrimary)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Spacer()

                        // 복사 버튼
                        Button {
                            UIPasteboard.general.string = url
                            bannerMessage = "링크를 복사했어요."
                            bannerSeverity = .success
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
                        let expired = expiresAt < .now
                        HStack {
                            Image(systemName: expired ? "exclamationmark.circle" : "clock")
                                .font(.system(size: 12))
                                .foregroundStyle(expired ? .red : Color.springTextSecondary)
                            Text(expired
                                ? "만료됨 (\(formattedDate(expiresAt)))"
                                : "만료: \(formattedDate(expiresAt))")
                                .font(.system(size: 12))
                                .foregroundStyle(expired ? .red : Color.springTextSecondary)
                        }
                        .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, 16)
            } else {
                Text("아직 공유하지 않았어요.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.springTextSecondary)
                    .padding(.horizontal, 16)
            }
        }
    }

    // MARK: Score Section

    private var scoreSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("스코어")
            .padding(.horizontal, 16)

            VStack(spacing: 0) {
                ForEach(scoreVM.players) { player in
                    let total = scoreVM.totalByPlayer[player.id] ?? 0
                    let vsPar = scoreVM.vsParByPlayer[player.id] ?? 0

                    HStack {
                        PlayerChip(
                            player: player,
                            variant: player.isOwner ? .active : .readonly
                        )
                        .padding(.leading, 16)

                        Spacer()

                        Text(total > 0 ? "\(total)" : "-")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.springTextPrimary)

                        Text(vsParText(vsPar))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(vsParColor(vsPar))
                            .frame(width: 48)
                            .padding(.trailing, 16)
                    }
                    .padding(.vertical, 12)

                    if player.id != scoreVM.players.last?.id {
                        Divider().padding(.leading, 16)
                    }
                }
            }
            .background(Color.springSurfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
            .padding(.horizontal, 16)
        }
    }

    // MARK: Photo Section

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionLabel("사진")
                Spacer()
                Button {
                    showPhotoAttach = true
                } label: {
                    Label("추가", systemImage: "plus")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.springGreenPrimary)
                }
            }
            .padding(.horizontal, 16)

            if round.photos.isEmpty {
                Text("아직 사진이 없어요.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.springTextSecondary)
                    .padding(.horizontal, 16)
            } else {
                PhotoGalleryGrid(
                    photos: round.photos,
                    isEditable: false,
                    onDelete: nil
                )
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: Share Button

    private var shareButton: some View {
        Button {
            showShare = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: round.sharedShortId != nil ? "arrow.2.circlepath" : "square.and.arrow.up")
                Text(round.sharedShortId != nil ? "viewer 업데이트 / 회수" : "공유하기")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(Color.springTextPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color.springGreenPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .background(
            LinearGradient(
                colors: [Color.springSurface.opacity(0), Color.springSurface],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: B3: 이미 공유된 라운드에 사진 추가

    /// 이미 공유된 라운드에서 remoteURL이 없는 (아직 업로드 안 된) 사진을 업로드
    private func uploadNewPhotosIfShared() async {
        guard let shortId = round.sharedShortId,
              let editToken = keychainStore.editToken(for: shortId) else { return }

        // remoteURL 없는 = 아직 업로드 안 된 사진만 대상
        let pending = round.photos.filter { $0.remoteURL == nil }
        guard !pending.isEmpty else { return }

        var successCount = 0
        var failedCount = 0

        for photo in pending {
            guard let imageData = photoStore.jpegData(for: photo) else {
                failedCount += 1
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
                photo.remoteURL = response.remoteURL
                successCount += 1
            } catch {
                failedCount += 1
            }
        }

        try? modelContext.save()

        if successCount > 0 {
            bannerMessage = "사진 \(successCount)장을 viewer에 업로드했어요."
            bannerSeverity = .success
        }
        if failedCount > 0 {
            bannerMessage = (bannerMessage ?? "") + " \(failedCount)장 업로드 실패."
            bannerSeverity = failedCount == pending.count ? .error : .warning
        }
    }

    // MARK: Helpers

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.springTextSecondary)
            .textCase(.uppercase)
    }

    private func vsParText(_ vsPar: Int) -> String {
        if vsPar == 0 { return "E" }
        return vsPar > 0 ? "+\(vsPar)" : "\(vsPar)"
    }

    private func vsParColor(_ vsPar: Int) -> Color {
        if vsPar <= -2 { return Color.springGreenPrimary }
        if vsPar < 0  { return Color.springGreenSecondary }
        if vsPar == 0 { return Color.springTextSecondary }
        if vsPar == 1 { return Color(red: 0.85, green: 0.3, blue: 0.3) }
        return Color(red: 0.7, green: 0.1, blue: 0.1)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: date)
    }
}

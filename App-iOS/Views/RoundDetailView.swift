import SwiftUI
import SwiftData
import UIKit
import Shared

// MARK: - RoundDetailView
// iphone-2.8: 완료 라운드 사후 보기 (12-SCREENS 2.8)
// viewer URL 복사 + 만료 표시 + 재공유 진입
// 사진 기능은 2026-05-18 폐기 (개인정보보호, 비용 절감)

struct RoundDetailView: View {

    // MARK: Props

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let round: Round

    // MARK: State

    @State private var scoreVM: ScoreCardViewModel
    @State private var shareVM: ShareViewModel
    @State private var showShare = false
    @State private var showDeleteConfirm = false
    @State private var bannerMessage: String?
    @State private var bannerSeverity: BannerNotice.Severity = .info

    // F7 편집 모드
    @State private var isEditMode = false
    @State private var editRoundVM: RoundViewModel?

    private let apiClient = ShareAPIClient()
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isEditMode {
                    Button("저장") {
                        saveEdit()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.springGreenPrimary)
                } else {
                    Menu {
                        Button {
                            enterEditMode()
                        } label: {
                            Label("편집", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("라운드 삭제", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(Color.springGreenPrimary)
                    }
                    .accessibilityLabel("라운드 메뉴")
                }
            }
        }
        .confirmationDialog(
            "라운드를 삭제할까요?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) {
                deleteRound()
            }
            Button("취소", role: .cancel) { }
        } message: {
            Text("\(round.courseName) 라운드와 모든 스코어가 영구 삭제됩니다. 되돌릴 수 없습니다.")
        }
        .sheet(isPresented: $showShare) {
            ShareSheetView(round: round, shareVM: shareVM, onShared: { url in
                bannerMessage = "공유 링크가 생성되었어요."
                bannerSeverity = .success
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
                    if let sub = round.displaySubLabel {
                        Text(sub)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.springTextSecondary)
                    }
                    Text(formattedDate(round.finishedAt ?? round.date))
                        .font(.system(size: 13))
                        .foregroundStyle(Color.springTextSecondary)
                    Text("\(round.holeList.count)홀")
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
                    HStack(spacing: 10) {
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
                            AppLogger.share.info("[RoundDetail] 링크 복사: \(url)")
                            Task { await HapticEngine.shared.play(.shareSuccess) }
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.springGreenPrimary)
                                .frame(width: 36, height: 36)
                                .background(Color.springGreenSecondary.opacity(0.25), in: Circle())
                        }
                        .accessibilityLabel("링크 복사")

                        // 공유 버튼 (UIActivityViewController)
                        Button {
                            if let u = URL(string: url) {
                                AppLogger.share.info("[RoundDetail] 시스템 공유 시트 호출: \(url)")
                                presentActivitySheet(url: u)
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
                        let expired = expiresAt < .now
                        HStack {
                            Image(systemName: expired ? "exclamationmark.circle" : "clock")
                                .font(.system(size: 12))
                                .foregroundStyle(expired ? .red : Color.springTextSecondary)
                            Text(expired
                                ? "만료됨 (\(formattedExpiry(expiresAt)))"
                                : "만료: \(formattedExpiry(expiresAt))")
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
            HStack {
                sectionLabel("스코어")
                if isEditMode {
                    Spacer()
                    Text("탭+1 / 길게누르기-1")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.springTextSecondary)
                }
            }
            .padding(.horizontal, 16)

            VStack(spacing: 0) {
                ForEach(scoreVM.players) { player in
                    let total = scoreVM.totalByPlayer[player.id] ?? 0
                    let parTotal = scoreVM.totalPar
                    let (diffText, parity) = ScoreCardViewModel.formatScoreVsPar(score: total, par: parTotal)

                    HStack {
                        PlayerChip(
                            player: player,
                            variant: player.isOwner ? .active : .readonly
                        )
                        .padding(.leading, 16)

                        Spacer()

                        VStack(alignment: .trailing, spacing: 1) {
                            Text(total > 0 ? "\(total)" : "-")
                                .font(.system(size: 18, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(Color.springTextPrimary)
                            if total > 0 {
                                Text(diffText)
                                    .font(.system(size: 12, weight: .semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(parityColor(parity))
                            }
                        }
                        .frame(width: 70, alignment: .trailing)
                        .padding(.trailing, 16)
                    }
                    .padding(.vertical, 12)
                    // 편집 모드: 홀별 편집 영역 펼침
                    if isEditMode {
                        holeEditGrid(player: player)
                    }

                    if player.id != scoreVM.players.last?.id {
                        Divider().padding(.leading, 16)
                    }
                }
            }
            .background(Color.springSurfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
            .padding(.horizontal, 16)

            if isEditMode {
                Text("서브 코스: \(round.displaySubLabel ?? "기본")")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.springTextSecondary)
                    .padding(.horizontal, 20)
            }
        }
    }

    /// 편집 모드에서 특정 플레이어의 홀별 타수 그리드
    private func holeEditGrid(player: Player) -> some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 9),
            spacing: 4
        ) {
            ForEach(round.holeList.sorted { $0.holeNumber < $1.holeNumber }) { hole in
                let count = hole.count(for: player.id)
                VStack(spacing: 1) {
                    Text("\(hole.holeNumber)")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.springTextSecondary)
                    Text(count > 0 ? "\(count)" : "-")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.springTextPrimary)
                        .frame(width: 32, height: 32)
                        .background(count > 0 ? Color.springGreenSecondary.opacity(0.25) : Color.springSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .onTapGesture {
                            // 탭: +1
                            editIncrement(hole: hole, playerId: player.id)
                        }
                        .onLongPressGesture(minimumDuration: 0.4) {
                            // 길게 누르기: -1
                            editDecrement(hole: hole, playerId: player.id)
                        }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    // MARK: Photo Section

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

    // MARK: F7: 사후 편집 헬퍼

    private func enterEditMode() {
        // RoundViewModel을 편집 전용으로 초기화
        let vm = RoundViewModel(modelContext: modelContext)
        vm.editRound(round)
        editRoundVM = vm
        isEditMode = true
    }

    private func saveEdit() {
        do {
            try editRoundVM?.commitEdit()
            // ScoreCardViewModel 갱신
            scoreVM.refresh(from: round)
            bannerMessage = "수정 내용을 저장했어요."
            bannerSeverity = .success
        } catch {
            bannerMessage = "저장 중 오류가 발생했어요."
            bannerSeverity = .error
        }
        isEditMode = false
        editRoundVM = nil
    }

    private func editIncrement(hole: HoleScore, playerId: UUID) {
        let maxCount = 15
        let current = hole.count(for: playerId)
        guard current < maxCount else { return }
        if let idx = hole.counts.firstIndex(where: { $0.playerId == playerId }) {
            hole.counts[idx].value += 1
        } else {
            hole.counts.append(ScoreEntry(playerId: playerId, value: 1))
        }
        scoreVM.refresh(from: round)
    }

    private func editDecrement(hole: HoleScore, playerId: UUID) {
        let current = hole.count(for: playerId)
        guard current > 0 else { return }
        if let idx = hole.counts.firstIndex(where: { $0.playerId == playerId }) {
            hole.counts[idx].value = max(0, hole.counts[idx].value - 1)
        }
        scoreVM.refresh(from: round)
    }

    // MARK: 라운드 삭제

    private func deleteRound() {
        AppLogger.view.info("라운드 삭제: \(round.courseName) (id=\(round.id))")
        modelContext.delete(round)
        do {
            try modelContext.save()
        } catch {
            AppLogger.persistence.error("라운드 삭제 후 저장 실패: \(error)")
            bannerMessage = "삭제 중 오류가 발생했어요."
            bannerSeverity = .error
            return
        }
        dismiss()
    }

    // 사진 업로드 헬퍼는 2026-05-18 폐기 (사진 공유 기능 제거)

    /// UIActivityViewController를 keyWindow root에 띄움.
    private func presentActivitySheet(url: URL) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        guard let root = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?.rootViewController else {
            AppLogger.share.error("[RoundDetail] keyWindow rootViewController 없음 — 공유 시트 표시 실패")
            return
        }
        // 가장 위에 표시되는 modal 위에 present
        var top = root
        while let presented = top.presentedViewController { top = presented }
        // iPad: popover anchor
        if let pop = activityVC.popoverPresentationController {
            pop.sourceView = top.view
            pop.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 0, height: 0)
            pop.permittedArrowDirections = []
        }
        top.present(activityVC, animated: true)
    }

    // MARK: Helpers

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.springTextSecondary)
            .textCase(.uppercase)
    }

    /// ActiveRoundView/HomeView와 통일된 색상 분기.
    /// parity: -1=under(녹색) / 0=even(회색) / 1=over(오렌지-빨강)
    private func parityColor(_ parity: Int) -> Color {
        switch parity {
        case ..<0: return Color.springGreenPrimary
        case 0: return Color.springTextSecondary
        default: return Color(red: 0.86, green: 0.42, blue: 0.16)
        }
    }

    /// 날짜만 (라운드 일자 등): "2026. 5. 18."
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        return formatter.string(from: date)
    }

    /// 만료 시각용 (분 단위): "2026-05-25 11:35 KST"
    private func formattedExpiry(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm 'KST'"
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        return formatter.string(from: date)
    }
}

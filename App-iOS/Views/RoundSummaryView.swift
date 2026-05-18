import SwiftUI
import SwiftData
import Shared

// MARK: - RoundSummaryView
// iphone-2.6: 라운드 종료 직후 요약 화면 (12-SCREENS 2.6)
// 총 타수 hero + par 대비 + ScoreCell 읽기전용 + "공유하기" CTA

struct RoundSummaryView: View {

    // MARK: Props

    @Environment(\.modelContext) private var modelContext
    let round: Round
    let onDismiss: () -> Void  // 홈으로 돌아가기

    // MARK: State

    @State private var scoreVM: ScoreCardViewModel
    @State private var shareVM: ShareViewModel
    @State private var showShare = false
    @State private var bannerMessage: String?
    @State private var bannerSeverity: BannerNotice.Severity = .info

    // MARK: Init

    init(round: Round, onDismiss: @escaping () -> Void) {
        self.round = round
        self.onDismiss = onDismiss
        _scoreVM = State(initialValue: ScoreCardViewModel(round: round))
        _shareVM = State(initialValue: ShareViewModel(round: round))
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
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

                        // Hero: 총 타수 + 골프장명
                        heroSection

                        // 플레이어별 요약
                        playerSummarySection

                        Spacer(minLength: 40)
                    }
                    .padding(.top, 16)
                }

                // 하단 CTA
                VStack {
                    Spacer()
                    ctaButtons
                }
            }
            .navigationTitle("라운드 완료")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("홈으로") { onDismiss() }
                        .foregroundStyle(Color.springGreenPrimary)
                }
            }
            .sheet(isPresented: $showShare) {
                ShareSheetView(round: round, shareVM: shareVM, onShared: { url in
                    bannerMessage = "공유 링크가 생성되었어요."
                    bannerSeverity = .success
                })
            }
            .task {
                shareVM.checkExpiration()
            }
        }
    }

    // MARK: Hero Section

    private var heroSection: some View {
        VStack(spacing: 8) {
            Text(round.courseName)
                .font(.system(size: 16))
                .foregroundStyle(Color.springTextSecondary)

            if let sub = round.displaySubLabel {
                Text(sub)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.springTextSecondary)
            }

            // 총 타수 hero
            let ownerPlayer = scoreVM.players.first(where: { $0.isOwner }) ?? scoreVM.players.first
            if let owner = ownerPlayer {
                let total = scoreVM.totalByPlayer[owner.id] ?? 0
                let vsPar = scoreVM.vsParByPlayer[owner.id] ?? 0

                VStack(spacing: 4) {
                    Text("\(total)")
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.springTextPrimary)
                        .contentTransition(.numericText())

                    Text(vsParDisplayText(vsPar))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(vsParColor(vsPar))
                }
            }

            // 날짜
            Text(formattedDate(round.finishedAt ?? round.date))
                .font(.system(size: 13))
                .foregroundStyle(Color.springTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color.springSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        .padding(.horizontal, 16)
    }

    // MARK: Player Summary Section

    private var playerSummarySection: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack(spacing: 2) {
                Text("플레이어")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.springTextSecondary)
                    .frame(width: 60, alignment: .leading)
                    .padding(.leading, 12)
                Spacer()
                Text("합계")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.springTextSecondary)
                    .padding(.trailing, 12)
                Text("vs Par")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.springTextSecondary)
                    .frame(width: 60)
                    .padding(.trailing, 12)
            }
            .padding(.vertical, 8)
            .background(Color.springBorder.opacity(0.2))

            ForEach(scoreVM.players) { player in
                let total = scoreVM.totalByPlayer[player.id] ?? 0
                let vsPar = scoreVM.vsParByPlayer[player.id] ?? 0

                HStack {
                    // PlayerChip 읽기전용
                    PlayerChip(
                        player: player,
                        variant: player.isOwner ? .active : .readonly
                    )
                    .padding(.leading, 12)

                    Spacer()

                    Text(total > 0 ? "\(total)" : "-")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.springTextPrimary)
                        .padding(.trailing, 12)

                    Text(vsParDisplayText(vsPar))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(vsParColor(vsPar))
                        .frame(width: 60)
                        .padding(.trailing, 12)
                }
                .padding(.vertical, 10)

                if player.id != scoreVM.players.last?.id {
                    Divider().padding(.leading, 12)
                }
            }
        }
        .background(Color.springSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
        .padding(.horizontal, 16)
    }

    // photoSection은 2026-05-18 폐기 (사진 공유 기능 제거)

    // MARK: CTA Buttons

    private var ctaButtons: some View {
        VStack(spacing: 8) {
            // 공유하기
            Button {
                showShare = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: round.sharedShortId != nil ? "arrow.2.circlepath" : "square.and.arrow.up")
                    Text(round.sharedShortId != nil ? "viewer 업데이트" : "공유하기")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundStyle(Color.springTextPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color.springGreenPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .accessibilityLabel(round.sharedShortId != nil ? "viewer 업데이트" : "공유하기")

            // 홈으로
            Button {
                onDismiss()
            } label: {
                Text("홈으로")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.springTextSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
        .background(
            LinearGradient(
                colors: [Color.springSurface.opacity(0), Color.springSurface],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: Helpers

    private func vsParDisplayText(_ vsPar: Int) -> String {
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
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: date)
    }

}

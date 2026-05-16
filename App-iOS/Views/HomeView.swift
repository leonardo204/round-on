import SwiftUI
import SwiftData
import Shared

// MARK: - HomeView
// iphone-2.1: 홈. 시안 = Ref-docs/design-mockup/2026-05-16_home_redesign.html
// 구성: Hero CTA 카드 + 이번 달 메트릭 2개 + 최근 라운드 insetGrouped 리스트
// Apple HIG 2024-2026 + 시스템 적응형 (라이트/다크 자동)
// 02-USER_FLOWS F-A

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \Round.startedAt, order: .reverse) private var rounds: [Round]
    @State private var showNewRound = false
    @State private var showStats = false
    @State private var selectedRound: Round?
    @Binding var roundViewModel: RoundViewModel?
    let onRoundFinished: ((Round) -> Void)?

    init(roundViewModel: Binding<RoundViewModel?>, onRoundFinished: ((Round) -> Void)? = nil) {
        self._roundViewModel = roundViewModel
        self.onRoundFinished = onRoundFinished
    }

    var body: some View {
        VStack(spacing: 0) {
            customHeader

            if rounds.isEmpty {
                emptyStateView
            } else {
                populatedScrollView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .tint(.accentGreen)
        .fullScreenCover(isPresented: $showNewRound) {
            NewRoundView(roundViewModel: $roundViewModel, isPresented: $showNewRound)
        }
        .fullScreenCover(isPresented: $showStats) {
            NavigationStack {
                StatsView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("닫기") { showStats = false }
                        }
                    }
            }
        }
        .fullScreenCover(item: $selectedRound) { round in
            NavigationStack {
                RoundDetailView(round: round)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("닫기") { selectedRound = nil }
                        }
                    }
            }
        }
        .onAppear {
            AppLogger.view.debug("HomeView 표시 (라운드 \(rounds.count)건)")
        }
    }

    // MARK: - Custom header (라운드온 + 액션 2개) — mockup 1:1 매칭

    private var customHeader: some View {
        HStack(alignment: .bottom) {
            Text("라운드온")
                .font(.system(size: 34, weight: .bold))
                .tracking(-0.4)
                .foregroundStyle(.primary)

            Spacer()

            HStack(spacing: 6) {
                Button {
                    showStats = true
                } label: {
                    navActionIcon("trending_up", label: "통계")
                }
                Button {
                    AppLogger.view.info("설정 버튼 탭 (placeholder)")
                } label: {
                    navActionIcon("settings", label: "설정")
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 12)
    }

    // MARK: - Nav action icon (36×36 원형 그레이 배경)

    private func navActionIcon(_ assetName: String, label: String) -> some View {
        ZStack {
            Circle()
                .fill(Color(.systemFill))
            Image(assetName, bundle: .sharedAssets)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .foregroundStyle(.tint)
        }
        .frame(width: 36, height: 36)
        .accessibilityLabel(label)
    }

    // MARK: - Populated (라운드 1건 이상)

    private var populatedScrollView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                heroCTA
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                if !finishedRounds.isEmpty {
                    sectionHeader("이번 달")
                    metricsGrid
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }

                sectionHeaderWithAction("최근 라운드", actionLabel: rounds.count > 5 ? "전체 보기" : nil) {
                    showStats = true
                }
                recentList
                    .padding(.horizontal, 16)
            }
            .padding(.bottom, 32)
        }
        .scrollContentBackground(.hidden)
    }

    // MARK: - Empty State (라운드 0건) — Apple HIG ContentUnavailableView 패턴

    private var emptyStateView: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            // 원형 아이콘 (110×110, 그라데이션 배경)
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: colorScheme == .dark
                                ? [Color.accentGreen.opacity(0.20), Color.accentGreen.opacity(0.08)]
                                : [Color.accentGreen.opacity(0.12), Color.accentGreen.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image("golf_course", bundle: .sharedAssets)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
            }
            .frame(width: 110, height: 110)
            .padding(.bottom, 28)

            // 타이틀
            Text("첫 라운드 시작하기")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.primary)
                .padding(.bottom, 10)

            // 설명
            Text("근처 골프장을 자동으로 찾아 드려요.\n한 번 탭하면 한 타가 기록됩니다.")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 260)
                .padding(.bottom, 32)

            // 알약 CTA
            Button {
                AppLogger.view.info("빈 상태 CTA 탭 → NewRoundView")
                showNewRound = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text("새 라운드 시작")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(
                    Capsule().fill(Color.accentGreen)
                )
                .shadow(
                    color: Color.accentGreen.opacity(colorScheme == .dark ? 0.4 : 0.4),
                    radius: colorScheme == .dark ? 20 : 16, x: 0, y: 4
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("새 라운드 시작")

            // GPS 권한 안내
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.system(size: 13))
                Text("GPS 권한이 필요해요")
                    .font(.system(size: 12))
            }
            .foregroundStyle(.tertiary)
            .padding(.top, 20)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }

    // MARK: - Hero CTA

    private var heroCTA: some View {
        Button {
            AppLogger.view.info("Hero CTA 탭 → NewRoundView")
            showNewRound = true
        } label: {
            ZStack(alignment: .leading) {
                heroGradient

                Image(systemName: "figure.golf")
                    .font(.system(size: 130, weight: .light))
                    .foregroundStyle(.white.opacity(0.10))
                    .rotationEffect(.degrees(-15))
                    .offset(x: 220, y: 20)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .clipped()
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 6) {
                    Text("바로 시작")
                        .font(.caption.weight(.semibold))
                        .tracking(0.8)
                        .foregroundStyle(.white.opacity(0.85))

                    Text(heroTitle)
                        .font(.system(.title, design: .default, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(heroSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.top, 2)

                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text("새 라운드 시작")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(.white.opacity(0.22), in: Capsule())
                    .padding(.top, 14)
                }
                .padding(22)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .accentGreen.opacity(colorScheme == .dark ? 0.5 : 0.3),
                    radius: colorScheme == .dark ? 24 : 16, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(heroTitle). \(heroSubtitle). 새 라운드 시작")
        .accessibilityAddTraits(.isButton)
    }

    private var heroTitle: String {
        rounds.isEmpty
            ? "첫 라운드를\n시작해 볼까요?"
            : "오늘의 라운드를\n시작해 볼까요?"
    }

    private var heroSubtitle: String {
        "근처 골프장을 GPS로 자동 매칭해 드려요"
    }

    private var heroGradient: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color(red: 0.11, green: 0.37, blue: 0.13), Color(red: 0.18, green: 0.49, blue: 0.20)]
                : [Color(red: 0.18, green: 0.49, blue: 0.20), Color(red: 0.26, green: 0.63, blue: 0.28)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    // MARK: - Section headers

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.footnote.weight(.semibold))
                .tracking(0.5)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 8)
    }

    private func sectionHeaderWithAction(_ title: String, actionLabel: String?, action: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Spacer()
            if let actionLabel {
                Button(actionLabel, action: action)
                    .font(.subheadline)
                    .foregroundStyle(.tint)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 8)
    }

    // MARK: - Metrics (이번 달)

    private var metricsGrid: some View {
        HStack(spacing: 10) {
            metricCard(label: "라운드", value: "\(monthlyCount)", unit: "회")
            metricCard(label: "평균", value: averageScoreText, unit: "타")
        }
    }

    private func metricCard(label: String, value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(.title, design: .default, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                Text(unit)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Recent list

    private var recentList: some View {
        VStack(spacing: 0) {
            ForEach(Array(rounds.prefix(5).enumerated()), id: \.element.id) { idx, round in
                Button {
                    selectedRound = round
                } label: {
                    RoundRow(round: round)
                }
                .buttonStyle(.plain)

                if idx < min(rounds.count, 5) - 1 {
                    Divider()
                        .padding(.leading, 70)
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Empty hint (라운드 0건)

    private var emptyHint: some View {
        VStack(spacing: 8) {
            Text("아직 라운드 기록이 없어요")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("위의 \"새 라운드 시작\"을 눌러 첫 라운드를 진행해 보세요")
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 40)
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Derived data

    private var finishedRounds: [Round] {
        rounds.filter { $0.isFinished }
    }

    private var monthlyCount: Int {
        let cal = Calendar.current
        let now = Date()
        return finishedRounds.filter {
            cal.isDate($0.startedAt, equalTo: now, toGranularity: .month)
        }.count
    }

    private var averageScoreText: String {
        let scores = finishedRounds.compactMap { totalScore(of: $0) }
        guard !scores.isEmpty else { return "—" }
        let avg = Double(scores.reduce(0, +)) / Double(scores.count)
        return String(format: "%.0f", avg)
    }

    private func totalScore(of round: Round) -> Int? {
        guard let owner = round.playerList.first(where: { $0.isOwner }) else { return nil }
        let total = round.holeList.reduce(0) { acc, hole in
            acc + (hole.counts.first(where: { $0.playerId == owner.id })?.value ?? 0)
        }
        return total > 0 ? total : nil
    }
}

// MARK: - RoundRow (insetGrouped 스타일 한 행)

private struct RoundRow: View {
    let round: Round

    var body: some View {
        HStack(spacing: 14) {
            roundIcon

            VStack(alignment: .leading, spacing: 2) {
                Text(round.courseName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(metaText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            scoreView

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var roundIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.accentGreen.opacity(0.15))
            Image(systemName: round.isFinished ? "flag.fill" : "play.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.tint)
        }
        .frame(width: 38, height: 38)
    }

    private var metaText: String {
        var parts: [String] = []
        parts.append(formattedDate(round.startedAt))
        if let sub = round.displaySubLabel, !sub.isEmpty {
            parts.append(sub)
        }
        parts.append("\(round.holeList.count)홀")
        return parts.joined(separator: " · ")
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일"
        return f
    }()

    private func formattedDate(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }

    private var scoreView: some View {
        VStack(alignment: .trailing, spacing: 1) {
            if round.isFinished, let total = totalScore {
                Text("\(total)")
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                if let diff = parDiffText {
                    Text(diff.label)
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(diff.color)
                }
            } else {
                Text("진행 중")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.orange)
            }
        }
    }

    private var totalScore: Int? {
        guard let owner = round.playerList.first(where: { $0.isOwner }) else { return nil }
        let sum = round.holeList.reduce(0) { acc, hole in
            acc + (hole.counts.first(where: { $0.playerId == owner.id })?.value ?? 0)
        }
        return sum > 0 ? sum : nil
    }

    private var totalPar: Int {
        round.holeList.reduce(0) { $0 + $1.par }
    }

    private var parDiffText: (label: String, color: Color)? {
        guard let total = totalScore else { return nil }
        let par = totalPar
        guard par > 0 else { return nil }
        let diff = total - par
        let label: String
        if diff == 0 { label = "E" }
        else if diff > 0 { label = "+\(diff)" }
        else { label = "\(diff)" }
        return (label, parDiffColor(diff: diff))
    }

    private func parDiffColor(diff: Int) -> Color {
        switch diff {
        case ..<(-1): return Color(red: 0.31, green: 0.27, blue: 0.90)   // eagle 보라
        case -1: return .accentGreen                                       // birdie
        case 0: return .secondary                                          // par
        case 1...2: return .orange                                         // bogey
        default: return .red                                               // doublePlus
        }
    }
}

// MARK: - iOS 18+ containerBackground 가드

private extension View {
    @ViewBuilder
    func applyNavigationBackgroundIfAvailable() -> some View {
        if #available(iOS 18.0, *) {
            self.containerBackground(Color(red: 0.95, green: 0.95, blue: 0.97), for: .navigation)
        } else {
            self
        }
    }
}

// MARK: - Color accent (다크/라이트 자동 — 시스템 적응형)

extension Color {
    /// 라운드온 accent. 라이트=Spring 그린, 다크에서는 약간 밝게 자동 조정 (UIColor dynamic).
    static let accentGreen = Color(
        UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.40, green: 0.73, blue: 0.42, alpha: 1.0)   // #66BB6A
                : UIColor(red: 0.18, green: 0.49, blue: 0.20, alpha: 1.0)   // #2E7D32
        }
    )
}

#Preview("Light") {
    HomeView(roundViewModel: .constant(nil))
        .modelContainer(for: [Round.self, Player.self, HoleScore.self, RoundPhoto.self], inMemory: true)
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    HomeView(roundViewModel: .constant(nil))
        .modelContainer(for: [Round.self, Player.self, HoleScore.self, RoundPhoto.self], inMemory: true)
        .preferredColorScheme(.dark)
}

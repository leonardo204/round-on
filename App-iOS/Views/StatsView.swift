import SwiftUI
import SwiftData
import Shared

// MARK: - StatsView
// F9 라운드 통계 화면 (01-SPEC §F9)
// HomeView 우상단 통계 버튼 → NavigationLink push
// @Query로 SwiftData fetch + aggregateStatistics() 계산 (캐싱 없음)

struct StatsView: View {

    /// import된 라운드 포함 여부 토글. 기본 ON.
    @AppStorage("stats.includeImported") private var includeImported: Bool = true

    @Query(
        filter: #Predicate<Round> { $0.isFinished == true },
        sort: \Round.startedAt,
        order: .reverse
    ) private var finishedRounds: [Round]

    /// includeImported 토글에 따라 필터링된 라운드 배열
    private var displayedRounds: [Round] {
        includeImported ? finishedRounds : finishedRounds.filter { !$0.isImported }
    }

    // MARK: Body

    var body: some View {
        ZStack {
            Color.springSurface.ignoresSafeArea()

            if displayedRounds.isEmpty {
                emptyStateView
            } else {
                let stats = aggregateStatistics(rounds: displayedRounds)
                ScrollView {
                    VStack(spacing: 16) {
                        // import 라운드 포함/제외 토글
                        HStack {
                            Toggle(isOn: $includeImported) {
                                Text("가져온 라운드 포함")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.springTextSecondary)
                            }
                            .toggleStyle(SwitchToggleStyle(tint: Color.springGreenPrimary))
                        }
                        .padding(.horizontal, 4)

                        summarySection(stats: stats)
                        bestRoundSection(stats: stats)
                        recentSection(stats: stats)
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                }
            }
        }
        .navigationTitle("통계")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 56))
                .foregroundStyle(Color.springGreenPrimary)
                .padding(.bottom, 4)
            Text("아직 완료된 라운드가 없어요")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.springTextPrimary)
            Text("라운드를 마치면 통계가 쌓여요")
                .font(.system(size: 14))
                .foregroundStyle(Color.springTextSecondary)
        }
    }

    // MARK: 요약 섹션 (총 라운드 수 + 평균 타수 + par 대비 평균)

    private func summarySection(stats: RoundStatisticsResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("요약")

            HStack(spacing: 12) {
                statCard(
                    title: "총 라운드",
                    value: "\(stats.totalRounds)",
                    unit: "회",
                    systemImage: "flag.fill"
                )

                if let avg = stats.averageScore {
                    statCard(
                        title: "평균 타수",
                        value: String(format: "%.1f", avg),
                        unit: "타",
                        systemImage: "golf.tee"
                    )
                }

                if let vsPar = stats.averageVsPar {
                    let sign = vsPar >= 0 ? "+" : ""
                    statCard(
                        title: "Par 대비",
                        value: "\(sign)\(String(format: "%.1f", vsPar))",
                        unit: "",
                        systemImage: "arrow.up.arrow.down"
                    )
                }
            }
        }
    }

    private func statCard(title: String, value: String, unit: String, systemImage: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 20))
                .foregroundStyle(Color.springGreenPrimary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.springTextPrimary)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.springTextSecondary)
                }
            }
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(Color.springTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.springSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
    }

    // MARK: 베스트 라운드 섹션

    @ViewBuilder
    private func bestRoundSection(stats: RoundStatisticsResult) -> some View {
        if let best = stats.bestRound {
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("베스트 라운드")

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(best.courseName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.springTextPrimary)
                        Text(formattedDate(best.date))
                            .font(.system(size: 13))
                            .foregroundStyle(Color.springTextSecondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(best.totalScore)")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(Color.springGreenPrimary)
                        Text("타")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.springTextSecondary)
                    }
                }
                .padding(16)
                .background(Color.springSurfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
            }
        }
    }

    // MARK: 최근 5라운드 섹션

    @ViewBuilder
    private func recentSection(stats: RoundStatisticsResult) -> some View {
        if !stats.recentScores.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("최근 \(stats.recentScores.count)라운드")

                VStack(spacing: 0) {
                    let recentFinished = Array(displayedRounds.prefix(stats.recentScores.count).reversed())

                    ForEach(Array(zip(recentFinished, stats.recentScores)), id: \.0.id) { round, score in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(round.courseName)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(Color.springTextPrimary)
                                Text(formattedDate(round.finishedAt ?? round.date))
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.springTextSecondary)
                            }
                            Spacer()
                            Text("\(score)타")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.springTextPrimary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                        if round.id != recentFinished.last?.id {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
                .background(Color.springSurfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
            }
        }
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
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: date)
    }
}

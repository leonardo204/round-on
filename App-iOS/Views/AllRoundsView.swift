import SwiftUI
import SwiftData
import Shared

// MARK: - AllRoundsView
// iphone-2.9: 전체 라운드 히스토리 (HomeView 최근 3개 → 전체 보기 진입)

struct AllRoundsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Round.startedAt, order: .reverse) private var rounds: [Round]
    @State private var selectedRound: Round?
    /// nil = 전체, 특정 Int = 해당 년도만 표시
    @State private var filterYear: Int? = nil

    // MARK: - 년도 그룹 계산

    private var availableYears: [Int] {
        let calendar = Calendar.current
        let years = rounds.map { calendar.component(.year, from: $0.startedAt) }
        return Array(Set(years)).sorted(by: >)
    }

    private var filteredRounds: [Round] {
        guard let year = filterYear else { return rounds }
        let calendar = Calendar.current
        return rounds.filter { calendar.component(.year, from: $0.startedAt) == year }
    }

    private var groupedRounds: [(year: Int, rounds: [Round])] {
        let calendar = Calendar.current
        let dict = Dictionary(grouping: filteredRounds) { round in
            calendar.component(.year, from: round.startedAt)
        }
        return dict.keys.sorted(by: >).map { year in
            (year: year, rounds: dict[year]!.sorted { $0.startedAt > $1.startedAt })
        }
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            if rounds.isEmpty {
                emptyState
            } else if filteredRounds.isEmpty {
                emptyFilterState
            } else {
                roundList
            }
        }
        .navigationTitle("전체 라운드")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        filterYear = nil
                    } label: {
                        if filterYear == nil {
                            Label("전체", systemImage: "checkmark")
                        } else {
                            Text("전체")
                        }
                    }
                    Divider()
                    ForEach(availableYears, id: \.self) { year in
                        Button {
                            filterYear = year
                        } label: {
                            if filterYear == year {
                                Label("\(String(year))년", systemImage: "checkmark")
                            } else {
                                Text(verbatim: "\(String(year))년")
                            }
                        }
                    }
                } label: {
                    Label(filterYear.map { "\(String($0))년" } ?? "전체", systemImage: "calendar")
                        .font(.system(size: 15))
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
    }

    // MARK: - Round List

    private var roundList: some View {
        ScrollView {
            LazyVStack(spacing: 16, pinnedViews: .sectionHeaders) {
                ForEach(groupedRounds, id: \.year) { group in
                    Section {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(group.rounds.enumerated()), id: \.element.id) { idx, round in
                                Button {
                                    selectedRound = round
                                } label: {
                                    RoundRow(round: round)
                                }
                                .buttonStyle(.plain)

                                if idx < group.rounds.count - 1 {
                                    Divider()
                                        .padding(.leading, 70)
                                }
                            }
                        }
                        .background(Color(.secondarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.horizontal, 16)
                    } header: {
                        HStack {
                            Text(verbatim: "\(String(group.year))년")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 6)
                            Spacer()
                            Text("\(group.rounds.count)회")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 20)
                        }
                        .background(Color(.systemGroupedBackground))
                    }
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Empty States

    private var emptyFilterState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 52))
                .foregroundStyle(Color.accentGreen.opacity(0.5))
                .accessibilityHidden(true)

            Text(verbatim: "\(filterYear.map { "\(String($0))년" } ?? "")에는 라운드가 없어요")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.primary)

            Button("전체 보기") {
                filterYear = nil
            }
            .font(.system(size: 15))
            .foregroundStyle(Color.accentGreen)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 52))
                .foregroundStyle(Color.accentGreen.opacity(0.5))
                .accessibilityHidden(true)

            Text("라운드가 없어요")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.primary)

            Text("첫 라운드를 완료하면\n여기에 기록이 쌓여요.")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }
}

// MARK: - RoundRow (AllRoundsView 전용 — HomeView의 RoundRow와 동일 스타일)

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
        f.dateFormat = "M/d (E)"
        return f
    }()

    private func formattedDate(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }

    private var scoreView: some View {
        VStack(alignment: .trailing, spacing: 1) {
            if round.isFinished, let total = totalScore {
                let (_, parity) = ScoreCardViewModel.formatScoreVsPar(score: total, par: totalPar)
                Text("\(total)")
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                if let diff = parDiffText {
                    Text(diff.label)
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(parityColor(parity))
                }
            } else {
                Text("진행 중")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.orange)
            }
        }
    }

    private func parityColor(_ parity: Int) -> Color {
        switch parity {
        case ..<0: return Color.springGreenPrimary
        case 0: return Color.springTextSecondary
        default: return Color(red: 0.86, green: 0.42, blue: 0.16)
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
        return (label, Color.secondary)
    }
}

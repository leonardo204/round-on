import SwiftUI
import SwiftData
import Shared

// MARK: - HomeView
// iphone-2.1: 홈 (라운드 리스트) + "새 라운드" 진입점
// 02-USER_FLOWS F-A
// 라운드 카드 탭 → RoundDetailView push

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Round.startedAt, order: .reverse) private var rounds: [Round]
    @State private var showNewRound = false
    @Binding var roundViewModel: RoundViewModel?
    let onRoundFinished: ((Round) -> Void)?

    init(roundViewModel: Binding<RoundViewModel?>, onRoundFinished: ((Round) -> Void)? = nil) {
        self._roundViewModel = roundViewModel
        self.onRoundFinished = onRoundFinished
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color.springSurface.ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 12) {
                        if rounds.isEmpty {
                            emptyStateView
                        } else {
                            ForEach(rounds) { round in
                                // 완료 라운드 → RoundDetailView
                                NavigationLink {
                                    RoundDetailView(round: round)
                                } label: {
                                    RoundSummaryCard(round: round)
                                        .padding(.horizontal, 16)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 100)
                }

                // 새 라운드 CTA 버튼
                Button {
                    showNewRound = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "flag.fill")
                        Text("새 라운드 시작")
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
                .accessibilityLabel("새 라운드 시작")
            }
            .navigationTitle("라운드온")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        StatsView()
                    } label: {
                        Image(systemName: "chart.bar.fill")
                            .foregroundStyle(Color.springGreenPrimary)
                            .accessibilityLabel("통계")
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showNewRound) {
            NewRoundView(roundViewModel: $roundViewModel, isPresented: $showNewRound)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "flag.circle")
                .font(.system(size: 64))
                .foregroundStyle(Color.springGreenPrimary)
                .padding(.top, 60)

            VStack(spacing: 8) {
                Text("첫 라운드를 시작해보세요")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.springTextPrimary)
                Text("아래 버튼을 눌러 골프장을 선택하고\n동반자를 추가하세요")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.springTextSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

// MARK: - RoundSummaryCard

struct RoundSummaryCard: View {
    let round: Round

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(round.courseName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.springTextPrimary)
                    if let subName = round.courseSubName {
                        Text(subName)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.springTextSecondary)
                    }
                }
                Spacer()
                if round.isFinished {
                    Text("완료")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.springGreenPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.springGreenSecondary.opacity(0.3))
                        .clipShape(Capsule())
                } else {
                    Text("진행 중")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(Capsule())
                }
            }

            HStack {
                Text(formattedDate(round.date))
                    .font(.system(size: 13))
                    .foregroundStyle(Color.springTextSecondary)
                Spacer()
                Text("\(round.holes.count)홀")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.springTextSecondary)
            }

            // 공유 링크 있을 때 아이콘 표시
            if round.sharedShortId != nil {
                HStack(spacing: 4) {
                    Image(systemName: "link")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.springGreenPrimary)
                    Text("공유됨")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.springGreenPrimary)
                }
            }
        }
        .padding(16)
        .background(Color.springSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: date)
    }
}

#Preview {
    HomeView(roundViewModel: .constant(nil))
        .modelContainer(for: [Round.self, Player.self, HoleScore.self, RoundPhoto.self], inMemory: true)
}

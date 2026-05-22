import SwiftUI
import SwiftData
import Shared

// MARK: - CompanionMatchSheet
// 동반자 매칭 시트 — mockup §③
// 기존 라운드들의 Player.name에서 prefix 매칭 → 후보 표시
// 라운드 횟수 카운트 표시

struct CompanionMatchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Binding var draft: ScorecardImportDraft

    @Query(
        filter: #Predicate<Round> { $0.isFinished == true },
        sort: \Round.startedAt,
        order: .reverse
    ) private var allRounds: [Round]

    /// 이름 → 라운드 등장 횟수 캐시 (sheet 표시 시 1회 계산, N+1 방지)
    @State private var nameStats: [String: Int] = [:]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("스코어카드의 별명을 기존 동반자와 연결하거나 새로 추가하세요.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                }

                ForEach($draft.players) { $player in
                    if !player.isOwner {
                        companionSection(player: $player)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("동반자 매칭")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                buildNameStats()
            }
        }
        .presentationDetents([.large])
    }

    /// 이름 통계 캐시 1회 계산 (N+1 방지)
    private func buildNameStats() {
        var stats: [String: Int] = [:]
        for round in allRounds {
            for player in round.playerList where !player.isOwner {
                stats[player.name, default: 0] += 1
            }
        }
        nameStats = stats
    }

    // MARK: - Companion Section

    private func companionSection(player: Binding<ImportPlayer>) -> some View {
        let p = player.wrappedValue
        let candidates = findCandidates(for: p.rawLabel)
        let matchStatus: MatchStatus = {
            if let matched = p.matchedPlayerName {
                return candidates.count == 1 && candidates.first?.name == matched ? .auto : .manual
            }
            return candidates.isEmpty ? .unmatched : .needsSelection
        }()

        return Section {
            // 현재 별명 + 매칭 상태
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("카드 별명")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text(p.rawLabel)
                        .font(.system(size: 15, weight: .medium))
                }
                Spacer()
                matchChip(status: matchStatus)
            }
            .padding(.vertical, 4)

            // 자동 매칭 결과 표시
            if matchStatus == .auto, let matched = p.matchedPlayerName {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("→ \(matched)")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    let count = roundCount(for: matched)
                    if count > 0 {
                        Text("(\(count)회 라운드)")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }

            // 후보 버튼들
            if matchStatus != .auto {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(candidates, id: \.name) { candidate in
                            Button {
                                player.wrappedValue.matchedPlayerName = candidate.name
                            } label: {
                                HStack(spacing: 4) {
                                    Text(candidate.name)
                                        .font(.system(size: 14, weight: .semibold))
                                    if candidate.count > 0 {
                                        Text("(\(candidate.count)회)")
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    p.matchedPlayerName == candidate.name
                                        ? Color.accentColor.opacity(0.15)
                                        : Color(.systemGray6)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(
                                            p.matchedPlayerName == candidate.name
                                                ? Color.accentColor
                                                : Color.clear,
                                            lineWidth: 1
                                        )
                                )
                                .foregroundStyle(
                                    p.matchedPlayerName == candidate.name
                                        ? Color.accentColor
                                        : .primary
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }

                        // 새 동반자
                        Button {
                            player.wrappedValue.matchedPlayerName = nil
                        } label: {
                            Label("새 동반자", systemImage: "plus")
                                .font(.system(size: 13))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray6))
                                .foregroundStyle(.secondary)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Helpers

    private struct Candidate {
        let name: String
        let count: Int
    }

    private enum MatchStatus {
        case auto, manual, unmatched, needsSelection
    }

    private func findCandidates(for rawLabel: String) -> [Candidate] {
        // nameStats 캐시 사용 — 라운드 재순회 없음 (N+1 방지)
        // prefix 매칭: 마스킹("문**") → 첫 글자만, 일반 라벨 → 2글자 매칭 (S3)
        let hasMask = rawLabel.contains("*")
        let prefixLength = hasMask ? 1 : 2
        let prefix = String(rawLabel.prefix(prefixLength))
        return nameStats
            .filter { $0.key.hasPrefix(prefix) }
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { Candidate(name: $0.key, count: $0.value) }
    }

    private func roundCount(for name: String) -> Int {
        // nameStats 캐시에서 직접 조회 — 라운드 재순회 없음
        nameStats[name] ?? 0
    }

    private func matchChip(status: MatchStatus) -> some View {
        let (text, bg, fg): (String, Color, Color) = {
            switch status {
            case .auto: return ("자동 매칭", Color.green.opacity(0.12), .green)
            case .manual: return ("선택됨", Color.accentColor.opacity(0.12), .accentColor)
            case .unmatched: return ("미매칭", Color(.systemGray5), .secondary)
            case .needsSelection: return ("선택 필요", Color.orange.opacity(0.12), .orange)
            }
        }()
        return Text(text)
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(bg)
            .foregroundStyle(fg)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

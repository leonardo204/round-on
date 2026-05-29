import SwiftUI
import SwiftData
import Shared

// MARK: - ConflictResolutionSheet
// 스코어카드 import 시 같은 날·같은 코스 기존 라운드 충돌 감지 후 표시되는 커스텀 확인 시트
// 기존 .alert 대체 — 삭제 대상 라운드 정보(날짜/시간/클럽/배지/홀수)를 명확히 노출

struct ConflictResolutionSheet: View {

    // MARK: - 입력

    /// 충돌 감지된 기존 라운드 (삭제 대상 후보)
    let existingRound: Round

    /// 불러온 스코어카드 초안 (새로 저장될 항목)
    let draft: ScorecardImportDraft

    // MARK: - 액션 콜백

    /// "기존 기록을 대체" — 기존 삭제 + 새 저장
    let onReplace: () -> Void

    /// "새 기록으로 따로 저장" — 기존 유지 + 새 저장
    let onSaveAsNew: () -> Void

    /// "취소" — 아무것도 저장 안 함
    let onCancel: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 핸들 바
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color(.systemGray4))
                .frame(width: 40, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 20)

            // 헤더
            VStack(spacing: 6) {
                Text("같은 날 라운드가 있어요")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.primary)

                Text("불러온 스코어카드가 아래 기존 기록과 일치하는 것 같아요.\n어떻게 할까요?")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)

            // 기존 기록 카드 (삭제 대상)
            existingRoundCard
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

            // 새 스코어카드 카드
            newDraftCard
                .padding(.horizontal, 16)
                .padding(.bottom, 28)

            // 액션 버튼 3개
            VStack(spacing: 10) {
                Button(action: onReplace) {
                    Label("기존 기록을 대체", systemImage: "trash.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color.red)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button(action: onSaveAsNew) {
                    Label("새 기록으로 따로 저장", systemImage: "plus.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button(action: onCancel) {
                    Text("취소")
                        .font(.system(size: 16, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color(.systemGray5))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - 기존 기록 카드

    private var existingRoundCard: some View {
        VStack(spacing: 0) {
            // 카드 헤더
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                    Text("삭제 대상")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.red)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Spacer()

                // 약식/스코어카드 배지
                Text(existingRound.isImported ? "스코어카드" : "약식 기록")
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(existingRound.isImported ? Color.blue.opacity(0.12) : Color.orange.opacity(0.12))
                    .foregroundStyle(existingRound.isImported ? Color.blue : Color.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 10)

            Divider()
                .padding(.horizontal, 14)

            // 날짜
            infoRow(icon: "calendar", label: "날짜", value: formattedDate(existingRound.date))

            Divider().padding(.horizontal, 14)

            // 시간
            infoRow(icon: "clock", label: "시작", value: formattedTime(existingRound.startedAt))

            Divider().padding(.horizontal, 14)

            // 클럽 (코스명 + 서브코스)
            infoRow(icon: "mappin.and.ellipse", label: "클럽", value: existingCourseText)

            // 홀수 (있으면 표시)
            if let holeCount = existingHoleCount {
                Divider().padding(.horizontal, 14)
                infoRow(icon: "flag.fill", label: "홀수", value: "\(holeCount)홀")
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.red.opacity(0.4), lineWidth: 1.5)
        )
        .overlay(
            // 좌측 빨강 보더 강조
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.red)
                    .frame(width: 4)
                    .clipShape(
                        .rect(
                            topLeadingRadius: 14,
                            bottomLeadingRadius: 14,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: 0
                        )
                    )
                Spacer()
            }
        )
        .shadow(color: Color.red.opacity(0.08), radius: 6, x: 0, y: 2)
    }

    // MARK: - 새 스코어카드 카드

    private var newDraftCard: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                    Text("불러온 스코어카드")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 10)

            Divider().padding(.horizontal, 14)

            infoRow(icon: "calendar", label: "날짜", value: formattedDate(draft.resolvedDate))
            Divider().padding(.horizontal, 14)
            infoRow(icon: "mappin.and.ellipse", label: "클럽", value: draftCourseText)

            if let ownerScore = draftOwnerScore {
                Divider().padding(.horizontal, 14)
                infoRow(icon: "figure.golf", label: "내 스코어", value: ownerScore)
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
    }

    // MARK: - 공통 행 컴포넌트

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 18)

            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 58, alignment: .leading)

            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Computed: 기존 기록

    private var existingCourseText: String {
        var parts: [String] = [existingRound.courseName]
        if let front = existingRound.frontCourseName { parts.append(front) }
        if let back = existingRound.backCourseName { parts.append(back) }
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private var existingHoleCount: Int? {
        let count = existingRound.holeList.count
        return count > 0 ? count : nil
    }

    // MARK: - Computed: 새 스코어카드

    private var draftCourseText: String {
        let name = draft.clubName ?? "알 수 없는 클럽"
        let sections = draft.sections.map { $0.name }.joined(separator: "+")
        return sections.isEmpty ? name : "\(name) · \(sections)"
    }

    private var draftOwnerScore: String? {
        guard let owner = draft.players.first(where: { $0.isOwner }) else { return nil }
        let total = owner.totalAbsolute(sections: draft.sections)
        return "\(total)타"
    }

    // MARK: - 날짜 포매터

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy.MM.dd"
        f.locale = Locale(identifier: "ko_KR")
        return f.string(from: date)
    }

    private func formattedTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.locale = Locale(identifier: "ko_KR")
        return f.string(from: date)
    }
}

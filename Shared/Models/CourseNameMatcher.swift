import Foundation
import SwiftData

// MARK: - CourseNameMatcher
// 코스명 정규화 + 유사도 판정.
// OCR import 시 같은 날짜 + 유사 코스명 충돌 감지에 사용.
//
// 정규화 규칙:
//   1. trim → lowercased
//   2. 접미사 제거 (CC, GC, 컨트리클럽, 골프장, 골프클럽, 리조트, Resort, Country Club)
//   3. 공백 제거
//
// 유사도 판정:
//   normalize(a).contains(normalize(b)) || normalize(b).contains(normalize(a))
//   (단 둘 다 비어있지 않을 때만 true)

public enum CourseNameMatcher {

    // MARK: - 접미사 목록 (lowercased 로 비교)

    private static let suffixes: [String] = [
        "country club",
        "컨트리클럽",
        "골프클럽",
        "골프장",
        "resort",
        "리조트",
        "cc",
        "gc"
    ]

    // MARK: - normalize

    /// 코스명을 정규화하여 비교용 문자열 반환.
    /// - 빈 문자열 / whitespace-only 입력 → "" 반환
    public static func normalize(_ name: String) -> String {
        var s = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        // 접미사 반복 제거 (예: "봄골프클럽CC" → 두 번 순회)
        var changed = true
        while changed {
            changed = false
            for suffix in suffixes {
                if s.hasSuffix(suffix) {
                    s = String(s.dropLast(suffix.count))
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    changed = true
                }
            }
        }

        // 공백 전부 제거
        s = s.replacingOccurrences(of: " ", with: "")
        return s
    }

    // MARK: - areSimilar

    /// 두 코스명이 유사한지 판정.
    /// 정규화 후 양방향 contains 비교.
    /// 어느 한쪽이 빈 문자열이면 false.
    public static func areSimilar(_ a: String, _ b: String) -> Bool {
        let na = normalize(a)
        let nb = normalize(b)
        guard !na.isEmpty, !nb.isEmpty else { return false }
        return na.contains(nb) || nb.contains(na)
    }

    // MARK: - matches(course:query:)

    /// query 가 course 의 name 또는 aliases 와 양방향 contains 매칭되는지.
    /// normalize 후 비교. 빈 query 는 false.
    public static func matches(course: GolfCourse, query: String) -> Bool {
        let nq = normalize(query)
        guard !nq.isEmpty else { return false }
        for k in course.searchableKeys() {
            if k.contains(nq) || nq.contains(k) {
                return true
            }
        }
        return false
    }

    // MARK: - findConflictingRound

    /// SwiftData ModelContext에서 충돌 라운드를 찾는다.
    ///
    /// 충돌 기준: ymd(KST) 동일 (date-only). 시간·코스명 표기차(영문/한글) 무시.
    ///   코스명 유사도는 같은 날 여러 라운드 중 '우선 제시' 정렬에만 사용한다.
    ///   같은 날이면 코스가 달라도 후보로 반환하며, 최종 판단(대체/새기록/취소)은 사용자 팝업이 한다.
    ///
    /// 충돌이 여러 개이면 코스 유사 우선 → lastActiveAt desc로 1개를 반환한다.
    ///
    /// - Parameters:
    ///   - date: OCR 드래프트의 날짜
    ///   - courseName: OCR 드래프트의 코스명
    ///   - context: SwiftData ModelContext
    /// - Returns: 충돌하는 Round, 없으면 nil
    @MainActor
    public static func findConflictingRound(
        date: Date,
        courseName: String,
        context: ModelContext
    ) -> Round? {
        // KST 캘린더로 ymd 분해
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current

        let targetComponents = calendar.dateComponents([.year, .month, .day], from: date)
        guard targetComponents.year != nil,
              targetComponents.month != nil,
              targetComponents.day != nil
        else { return nil }

        // 당일 범위 계산 (KST 00:00 ~ 익일 00:00)
        guard
            let dayStart = calendar.date(from: targetComponents),
            let dayEnd   = calendar.date(byAdding: .day, value: 1, to: dayStart)
        else { return nil }

        // SwiftData Fetch: 전체 Round 조회 후 인메모리 필터링
        // #Predicate에서 Date 범위 비교는 iOS 시뮬레이터에서 런타임 crash 가능성이 있어
        // 전체 fetch → Swift 코드 필터 방식 사용
        let descriptor = FetchDescriptor<Round>(
            sortBy: [SortDescriptor(\Round.startedAt, order: .reverse)]
        )

        let allRounds = (try? context.fetch(descriptor)) ?? []

        // 1. ymd 날짜 범위 필터
        let dayRounds = allRounds.filter { round in
            round.date >= dayStart && round.date < dayEnd
        }

        // 2. 충돌 후보 = 같은 날(KST) 전체. 코스명 영문/한글 표기차로 충돌을 놓치지 않도록
        //    코스명 유사도는 '필터'가 아니라 '후보 정렬 선호값'으로만 사용한다 (date-only 감지).
        //    같은 날 여러 라운드면 코스 유사한 것을 우선 제시하고, 최종 확인은 사용자 팝업이 한다.
        let conflicts = dayRounds

        // 3. 정렬: 코스명 유사 우선 → 최근 활동(lastActiveAt, nil은 startedAt) desc
        let sorted = conflicts.sorted { a, b in
            let aSim = areSimilar(a.courseName, courseName)
            let bSim = areSimilar(b.courseName, courseName)
            if aSim != bSim { return aSim }
            let ta = a.lastActiveAt ?? a.startedAt
            let tb = b.lastActiveAt ?? b.startedAt
            return ta > tb
        }

        return sorted.first
    }
}

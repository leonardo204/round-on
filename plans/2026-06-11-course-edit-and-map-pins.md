# 라운드 구장 수정 + 지도 핀 매칭 개선 (2026-06-11)

## 배경 / 문제
- 통계 "지역별 라운드" 지도에 일부 라운드 핀이 안 찍힘.
- 근본 원인: OCR import 시 `Round.courseId = ""` 저장(자동매칭 없음) + 골프장명 매칭 실패.
  - `BELLA 45` → DB alias `BELLA 45 ONEOSEU` 로 런타임 매칭됨 → 핀 정상.
  - `venue G` → DB "베뉴지C.C" alias가 음차 `BENYUJI`만 → 매칭 실패. (이미 courses.json에 `VENUE G` alias 추가 완료 → 런타임 매칭 복구됨)
- 추가 발견: `StatsView.courseCache`는 `CourseRepository.loadAll()`만 사용 → `PersistedDiscoveredCourse`(카카오로 찾은 구장, `kakao:` id) 미병합 → 카카오 지정 라운드는 핀 안 찍힘.

## 목표 (사용자 승인 범위)
1. OCR import 직후 `courseId` 자동 매칭 + 미매칭 시 검토화면 경고.
2. 골프장 검색이 alias도 매칭(현재 name만).
3. **라운드 정보(RoundDetailView)에서 구장 수정**: [유사 구장 추천] → 추천에 없으면 [DB 검색 / 카카오맵 검색]으로 선택. custom 직접입력 불가.
4. StatsView가 카카오(`kakao:`) 구장 좌표도 핀으로 표시.
5. (데이터) 베뉴지 영문 alias 추가 — **완료**.

## 구현 항목

### A. CourseNameMatcher.findSimilarCourses (Shared/Models/CourseNameMatcher.swift)
```swift
/// query(라운드 courseName)와 유사한 골프장 후보를 점수순 상위 limit개 반환.
/// 점수: exact name/alias > alias contains > areSimilar. 빈 query → [].
public static func findSimilarCourses(query: String, from courses: [GolfCourse], limit: Int = 5) -> [GolfCourse]
```
- 내부적으로 `matches(course:query:)` / `searchableKeys()` 재사용.

### B. StatsView 카카오 좌표 병합 (App-iOS/Views/StatsView.swift)
- `@Query private var discoveredCourses: [PersistedDiscoveredCourse]` 추가.
- `.task` 캐시 빌드(176-200줄)에서 `discoveredCourses.map { $0.toGolfCourse() }` 를 courseCache/index에 병합.
  - id 키는 `kakao:{kakaoPlaceId}` 형식이어야 `Round.courseId`(=roundCourseId)와 1단 매칭됨. `toGolfCourse()`의 id 확인 후 일치시킬 것.
- 결과: courseId가 `kakao:...` 인 라운드도 clubhouse 좌표로 핀 표시.

### C. 골프장 검색 alias 매칭 (Shared/Repositories/CourseRepository.swift search(byName:) + CourseSearchSheet localFiltered)
- 현재 `name.localizedCaseInsensitiveContains`만. → `CourseNameMatcher.matches(course:query:)` 도 OR 조건으로 추가.
- CourseSearchSheet(NewRoundView.swift:897-1116)의 `localFiltered`(922-925)도 동일하게 alias 포함 필터.

### D. OCR import 자동매칭 + 미매칭 경고
- **자동매칭**: `ImportViewModel`에서 OCR draft 생성 직후(makeDraft 이후), `draft.courseId`가 비어있으면
  `CourseRepository.shared.loadAll()` 로드 → `CourseNameMatcher.findSimilarCourses(draft.clubName, ...)`의 최상위가 `matches`로 confident하면 `draft.courseId`, `draft.clubName = matched.name`, `draft.clubSource = .autoMatched`(없으면 enum 케이스 추가) 설정.
  - 너무 공격적이면 안 됨: exact name/alias 또는 alias 양방향 contains 수준의 confident match만 자동 채택. 애매하면 비워둠(사용자 선택 유도).
- **경고 UI**: ImportReviewView(App-iOS/Views/Import/ImportReviewView.swift) — 저장 전 `draft.courseId`가 비어있으면 골프장 행에 경고 배지/문구("골프장 미선택 — 지도에 표시되지 않아요")와 [골프장 선택] 버튼 노출. 버튼은 기존 CourseSearchSheet 호출(89-108줄 흐름 재사용).
  - 저장 자체는 막지 않음(경고만). custom 입력은 여전히 불가.

### E. RoundDetailView 구장 수정 (App-iOS/Views/RoundDetailView.swift) — 핵심 신규
- Hero Card 코스명(186줄) 근처 또는 메뉴(95-120줄)에 "구장 수정" 액션 추가.
- 흐름:
  1. **추천 시트/섹션**: `CourseNameMatcher.findSimilarCourses(round.courseName, from: loadAll(), limit: 5)` 결과를 카드로 표시. 탭하면 즉시 선택.
  2. **"직접 검색" 진입**: 추천에 없으면 버튼 → 기존 `CourseSearchSheet`(NewRoundView.swift) 재사용. DB 검색 + 카카오맵 검색 모두 제공.
- 선택 처리:
  - `onSelectLocal(course)`: `round.courseId = course.id`, `round.courseName = course.name`, `modelContext.save()`.
  - `onSelectDiscovered(discovered)`: NewRoundView(805-822줄)처럼 `PersistedDiscoveredCourse` upsert 저장 후 `round.courseId = discovered.roundCourseId`(=`kakao:...`), `round.courseName = discovered.name`, `save()`.
  - custom(직접입력) 경로 없음 — CourseSearchSheet는 DB/카카오만 반환하므로 자동 충족.
- 저장 후 `@Query` 로 StatsView 자동 갱신.
- 로깅: 구장 수정 진입/선택(local/kakao)/저장 결과를 os.Logger(category: round 또는 import)로 기록.

### F. 기존 라운드 backfill (선택, 낮은 우선순위)
- 앱 시작 시 1회: `courseId == ""` 인 finished Round에 대해 `findSimilarCourses` confident match 시 `courseId` 채워 저장.
- 런타임 courseFor가 이미 표시를 처리하므로 필수는 아님. 구현 시 안전하게(애매하면 skip).

## 검증
- 빌드: `xcodebuild -scheme RoundOn -destination 'id=3FB51BDB-BF4E-41CF-807B-5D7E56578F0A' build`
- 컴파일 성공 + 기존 테스트(RoundCourseLabelingTests 등) 통과.
- courses.json JSON 유효성(이미 alias 추가됨).

## 주의
- iOS 코드 변경은 단일 ralph(영역 충돌 방지).
- courses.json은 직접 수정 완료 — ralph는 건드리지 말 것.
- `clubSource` enum에 `.autoMatched` 추가 시 기존 switch 망라성 확인.

# 골프장 DB 동기화 — 번들 base + 골프존 원격 보강 (혼선 방지 명세)

> 작성: 2026-05-29. 근거: `/v1/courses`·`/v1/course-pars` 실측 + Worker `golfzonFetch.ts`/`syncCourses.ts` 코드 조사.
> **이 문서의 목적: "원격이 전체 DB여야 하는데 216개뿐"이라는 반복 혼선을 끝낸다.**

---

## 1. 두 데이터 소스 — 범위가 다르다 (둘 다 정상)

| 소스 | 곳 수 | 내용 | 역할 |
|---|---|---|---|
| **번들** `App-iOS .../courses.json` | **979** | full `GolfCourse`(id·name·region·holes·dataQuality·aliases…) | **base 데이터셋** (다중 소스 수집본). 941곳은 par 없는 `low`. |
| **원격** 골프존 API (스케줄 수집→KV) | **216** | 골프존 한국 코스만 | 번들을 **보강**(특히 par). 교체 아님. |

- **216 ≠ 979는 정상.** 골프존 한국 코스 실제 합계가 216(`fetchAllGolfzonCourses`가 list API 전 페이지 순회 후 `country===1` 필터). 번들 979는 더 넓은 수집본. **원격은 골프존 부분집합이지 전체 DB가 아니다.**
- ⚠️ "원격이 9백몇 개여야 하는 것 아니냐"는 오해 — 골프존 소스 자체가 216이다.

## 2. 원격은 2개 엔드포인트 (Bearer 인증, golf.zerolive.co.kr)

Worker `DbCourse = { id, name }` — 설계상 **최소 메타**다.

| 엔드포인트 | 페이로드 | 비고 |
|---|---|---|
| `GET /v1/courses` | `{ version, updatedAt, schema, count, courses:[{id,name}] }` | **id+name만**. 전체 GolfCourse 아님 |
| `GET /v1/course-pars` | `{ …, count, coursePars:[{courseId, courseName, subCourses:[{name, pars:[9]}]}] }` | **실제 par 데이터 — 보강의 핵심** |

→ `/v1/courses`는 "어떤 골프존 코스가 있나" 목록, `/v1/course-pars`가 "그 코스들의 서브코스별 9홀 par".

## 3. 동기화 트리거 (앱 측 `CourseRepository`)

- **자동**: 앱 cold start → `fetchRemoteIfStale` (마지막 성공 7일 경과 시에만)
- **수동**: 설정 화면 갱신 버튼 → `fetchRemoteForce`
- ETag/If-None-Match → 304 시 스킵. 실패 시 디스크 캐시 → 번들 4단 fallback.

## 4. 올바른 소비 방식 = **머지(보강)**, 교체 아님

원격은 번들을 **덮어쓰지 않는다.** id(없으면 `CourseNameMatcher` 이름 유사도)로 매칭해:
- `/v1/course-pars`의 par를 번들 `GolfCourse.holes`에 채우고 `dataQuality` 승격
- `/v1/courses`의 id+name은 코스 존재/이름 확인용 (관대한 최소 DTO로 디코드만, 실패 금지)

`self.cache = dto.courses` 식 **전체 교체 금지** — 번들 full 데이터가 날아간다.

## 5. 과거 버그 (반복 방지 기록)

1. 앱이 `/v1/courses`(id+name)를 **full `GolfCourse`로 디코드** → `totalCourses`·`region`·`holes`·`dataQuality` 없어 항상 `JSON 파싱 실패 (remote)` → 번들 fallback. **원격 코스 메타가 한 번도 적용된 적 없음.**
2. `/v1/course-pars`는 **fetch만 하고 디코드·머지 안 함** → 골프존 par가 그냥 버려짐.
→ 결과: 앱은 줄곧 번들만 사용. 골프존 보강 0.

## 6. 불변 규칙 (혼선 방지)

- 🚫 원격 = 전체 DB로 착각 금지. 원격은 **골프존 216 보강 피드**(메타+par), 번들 979가 base.
- 🚫 원격으로 번들 **교체 금지** — 항상 **id/이름 매칭 머지**.
- ✅ 디코드 모델은 원격 실제 shape(`count`, `{id,name}`, `coursePars`)에 맞춘 **관대한 전용 DTO** 사용. full `GolfCourse`로 디코드하지 말 것.
- ✅ par의 신뢰원천: 골프존 `/v1/course-pars` > 번들. 머지 시 par 채우고 dataQuality 승격.
- ✅ 마지막 sync **성공(디코드·머지 성공) 시각만** `SyncMeta.lastSuccessAt`에 기록(HTTP 200만으로 찍지 말 것). 설정 화면에 표시.

---

*관련: `40-COURSE_DB_SCHEMA.md`(스키마), `41-COURSE_DB_PIPELINE.md`(수집), `Shared/Repositories/CourseRepository.swift`(소비), `Worker/src/handlers/syncCourses.ts`·`lib/golfzonFetch.ts`(적재).*

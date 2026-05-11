# 53 — 권한 요청 메시지 (Permissions)

> **작성일**: 2026-05-11
> **버전**: v4 기반
> **출처 명세서**: [기능 명세서 v4](../golf-scorecard-app-spec_3.md) §9 (spec_3.md:655-672)
> **관련 문서**: `02-USER_FLOWS.md` (권한 거부 분기), `21-DATA_MODEL.md` (Player.name 제약), `30-API_SPEC.md` (viewer TTL), `31-VIEWER_HTML.md` (책임 경계), `33-SECURITY.md` (작성 예정)

> **[spec 미정의 항목 일람]**
>
> 아래 5개는 `spec_3.md §9`에 명시 없음. 본 문서가 보강 제안하며, 구현 권장안은 각 항목이 등장하는 절에 `[SPEC-UNDEFINED]` 라벨로 표기한다.
>
> 1. HealthKit Share vs Update 키 분리 (spec §9는 "Workout Write"만 기술) — §3
> 2. `NSPhotoLibraryAddUsageDescription` (사진 저장 Add 키) 필요성 — §4
> 3. iOS 14+ Precise Location 정책 분기 — §2
> 4. 알림 권한 거부 시 F3 fallback UI 처리 방식 — §6
> 5. iCloud 미로그인 시 sync 비활성 안내 UI — §7

---

## 1. 권한 매트릭스

spec_3.md §9 (spec_3.md:657-664) 기준 6개 권한과 본 시리즈 범위 외 1개를 포함한다. 각 행의 "spec 출처" 컬럼은 spec_3.md 라인 번호로 1:1 추적한다.

| 권한 | Info.plist 키 | 요청 시점 | 거부 시 동작 | spec 출처 |
|------|--------------|---------|-----------|---------|
| 위치 (When In Use) | `NSLocationWhenInUseUsageDescription` | 앱 첫 실행 (F-A) | 수동 검색 fallback (02-USER_FLOWS L49) | spec_3.md:657-659 |
| HealthKit Workout | `NSHealthShareUsageDescription` + `NSHealthUpdateUsageDescription` [SPEC-UNDEFINED 분리] | 라운드 시작 (F-B) | 워크아웃 없이 점수만 기록 (02-USER_FLOWS L69) | spec_3.md:660 |
| 사진 라이브러리 (선택 접근) | `NSPhotoLibraryUsageDescription` | 사진 첨부 시 (F9) | 카메라만 노출 | spec_3.md:661 |
| 카메라 | `NSCameraUsageDescription` | "촬영" 옵션 탭 시 (F9) | 라이브러리만 노출 | spec_3.md:662 |
| 알림 | (Info.plist 키 불필요, 런타임 호출) | 라운드 시작 후 | 무음 동작, 기능 영향 없음 [SPEC-UNDEFINED fallback] | spec_3.md:663 |
| iCloud / CloudKit | (시스템 계정 자동, Info.plist 키 불필요) | 첫 SwiftData write | 로컬 only [SPEC-UNDEFINED UI] | spec_3.md:664 |
| **본 시리즈 범위 외** | `NSMotionUsageDescription` | — | — | spec_3.md 미정의 → `13-HAPTICS_AND_MOTION.md` 도입 시 보강 |

**매트릭스 독해 가이드**

- "Info.plist 키 불필요" 행은 런타임 API 호출만으로 처리되며 Info.plist 등록 시 심사 거부 가능
- [SPEC-UNDEFINED] 라벨이 붙은 셀은 본 문서 해당 절에서 구현 권장안을 제시
- "본 시리즈 범위 외" 행은 spec_3.md에 정의 없는 권한. 13-HAPTICS_AND_MOTION.md 도입 전까지 Info.plist에 추가하지 않는다

---

**권한 요청 순서 및 UX 원칙**

iOS 시스템 alert는 사용자가 맥락을 이해할 때 요청해야 거부율이 낮다. 본 앱의 권한 요청 순서는 아래를 따른다:

1. 위치 — 앱 진입 직후 (골프장 매칭이 핵심 가치임을 사용자가 직관적으로 인지)
2. HealthKit — "라운드 시작" 직전 (워크아웃 기록 가치 설명 후 요청)
3. 알림 — 라운드 시작 직후 (홀 전환 알림 필요성 체감 후 요청)
4. 사진/카메라 — 해당 기능 탭 시점 (Just-in-time 요청)

한 번에 여러 권한을 일괄 요청하는 방식은 지양한다.

---

## 2. 위치 권한 (NSLocationWhenInUseUsageDescription)

- 관련 기능: F1 골프장 자동 매칭, F3 GPS 홀 자동 감지 (spec_3.md:57-62, 70-77)
- 요청 API: `CLLocationManager.requestWhenInUseAuthorization()` (02-USER_FLOWS L41)
- 요청 시점: 앱 첫 실행 F-A 플로우 진입 시 (02-USER_FLOWS L41-44)
- 위치 사용 빈도: 앱 실행 시 1회 fetch (F1), 라운드 중 2분 폴링 또는 사용자 인터랙션 시 (F3, spec_3.md:73)
- Always On 권한 (`NSLocationAlwaysAndWhenInUseUsageDescription`)은 요청하지 않음 — 배터리 절약 원칙 (spec_3.md:73)

**[SPEC-UNDEFINED] iOS 14+ Precise / Approximate Location 정책 분기**

- 골프장 반경 3km 매칭 및 홀 감지는 Precise Location 필요 (spec_3.md:59)
- 사용자가 Approximate 선택 시: 매칭 정확도 저하 가능, 수동 검색 권장 안내 필요
- 구현 권장: `CLLocationManager.accuracyAuthorization` 확인 후 UI 상태 반영
- dataQuality: low 코스(546개 중 524개)에서는 홀 감지 비활성 — 위치 정확도 분기와 독립적으로 처리 (CLAUDE.md §PROJECT, 02-USER_FLOWS L51-52)

### 한국어 카피

> "라운드온은 골프장을 자동으로 매칭하고 라운드 중 홀 위치를 감지하기 위해 위치 정보를 사용합니다. 위치 정보는 기기 외부로 전송되지 않습니다."

### 영문 초안 (참고용)

> "Round-On uses your location to automatically match the golf course and detect your current hole during a round. Your location never leaves the device."
>
> **[글로벌 검토 필요]** 영어 "round on"의 부정적 함의("공격하다")로 인해 글로벌 출시 전 앱 이름 및 usage string 브랜드 재고 필요 (CLAUDE.md §PROJECT)

**거부 fallback**: 수동 골프장 검색/선택 화면으로 전환 (spec_3.md:634, 02-USER_FLOWS L49)

---

## 3. HealthKit 권한 (NSHealthShareUsageDescription + NSHealthUpdateUsageDescription)

- 관련 기능: F8 Apple Health 연동 (spec_3.md:116-119, 660)
- 요청 시점: 라운드 시작 "라운드 시작" 탭 후 HealthKit 미허가 시 (02-USER_FLOWS L63)

**[SPEC-UNDEFINED] Share vs Update 키 분리 보강**

spec_3.md §9 (spec_3.md:660)는 "HealthKit Workout Write"만 명시한다. 본 문서는 보수적으로 두 키 모두 권장한다.

- `NSHealthShareUsageDescription` (Read): 걸음 수, 칼로리, 심박수 읽기
- `NSHealthUpdateUsageDescription` (Write): `HKWorkoutActivityType.golf` 세션 생성 및 기록

두 키를 동시에 선언해야 `HKHealthStore.requestAuthorization(toShare:read:)` 호출이 유효하다. Write 전용으로 선언해도 심사 통과는 가능하나, F8 심박/칼로리 표시(spec_3.md:118)를 위해 Read 포함을 권장한다.

HealthKit은 Info.plist 키 선언 + Xcode capabilities "HealthKit" 체크박스 모두 필요하다. entitlements 파일은 §9 구현 단계 책임이다.

### 한국어 카피

> "라운드 중 걸음 수, 칼로리, 심박수, 활동 시간을 기록하고 Apple 건강 앱과 동기화하기 위해 사용됩니다."

### 영문 초안 (참고용)

> "Used to record steps, calories, heart rate, and active time during your round, and to sync this data with Apple Health."
>
> **[글로벌 검토 필요]** (CLAUDE.md §PROJECT)

**거부 fallback**: 워크아웃 세션 없이 점수 기록만 진행 (spec_3.md:116-119, 02-USER_FLOWS L69)

---

## 4. 사진 라이브러리 권한 (NSPhotoLibraryUsageDescription)

- 관련 기능: F9 사진 첨부 — 카메라 롤에서 선택 (spec_3.md:134-138, 661)
- 요청 시점: 사진 첨부 메뉴 → "라이브러리" 옵션 탭 시
- iOS 14+ Limited Photos Access (`PHPickerViewController`) 권장 — spec_3.md:661 "선택 접근" 준수
- `PHPickerViewController` 사용 시 `NSPhotoLibraryUsageDescription` 없이도 동작 가능하나, iOS 13 이하 호환 또는 `UIImagePickerController` fallback 대비를 위해 선언 유지 권장

**[SPEC-UNDEFINED] NSPhotoLibraryAddUsageDescription 필요성**

viewer 다운로드 기능(spec_3.md:137 "방문자가 사진 다운로드 가능")을 iOS 앱 내에서 구현하거나, viewer 링크 저장 화면을 추가할 경우 `NSPhotoLibraryAddUsageDescription` 키가 별도로 필요하다. 보수적으로 함께 선언을 권장하며, 사용하지 않을 경우 App Store Connect에서 키 삭제 가능하다.

- Read (`NSPhotoLibraryUsageDescription`): 사진 첨부 시 라이브러리 선택
- Add (`NSPhotoLibraryAddUsageDescription`): 촬영 사진 카메라 롤 저장 또는 viewer 다운로드 저장
- 두 키는 독립적으로 요청 가능. 각각 다른 usage string을 사용해야 심사 통과율이 높다

### 한국어 카피 (Read)

> "라운드 사진을 첨부하기 위해 선택한 사진만 사용합니다. 라운드 viewer 공유 외에는 외부 전송하지 않습니다."

### 영문 초안 (참고용)

> "Used to attach photos of your round. Only photos you select are accessed, and they are never shared outside the round viewer link."
>
> **[글로벌 검토 필요]** (CLAUDE.md §PROJECT)

**거부 fallback**: 카메라 즉석 촬영 옵션만 노출 (spec_3.md:135)

---

## 5. 카메라 권한 (NSCameraUsageDescription)

- 관련 기능: F9 라운드 중 즉석 촬영 (spec_3.md:135, 662)
- 요청 시점: 사진 첨부 메뉴 → "촬영" 옵션 탭 시 (spec_3.md:662)
- 촬영 즉시 라운드에 첨부, 카메라 롤 별도 저장 여부는 사용자 선택
- 사진/카메라 두 권한은 독립적으로 요청 가능. 라이브러리만 허가하고 카메라 거부 시 "촬영" 옵션만 비노출 처리

### 한국어 카피

> "라운드 중 사진을 즉시 촬영해 첨부하기 위해 사용됩니다."

### 영문 초안 (참고용)

> "Used to capture and attach photos directly during your round."
>
> **[글로벌 검토 필요]** (CLAUDE.md §PROJECT)

**거부 fallback**: 라이브러리 선택 옵션만 노출 (spec_3.md:135)

---

## 6. 알림 권한 (UNUserNotificationCenter)

- 관련 기능: F3 GPS 홀 자동 감지 전환 알림 (spec_3.md:639-643, 663)
- Info.plist 키 불필요 — 런타임 `UNUserNotificationCenter.requestAuthorization(options:)` 호출 (spec_3.md:663)
- 요청 옵션: `.alert`, `.sound` 최소 범위 권장 (배지는 라운드 특성상 불필요)
- 요청 시점: 라운드 시작 후 적절한 시점 (첫 홀 진입 전 또는 F-B 완료 직후 권장)
- 용도: 홀 자동 전환 감지 알림, Watch 미착용 시 iPhone 알림
- dataQuality: high 코스(14개)에서만 F3 알림 실질 발생 (CLAUDE.md §PROJECT, 02-USER_FLOWS L52)

**[SPEC-UNDEFINED] 알림 권한 거부 시 F3 fallback UI**

spec_3.md §9 (spec_3.md:663)는 거부 시 동작을 명시하지 않는다. 구현 권장:

- 알림 권한 거부 시 시스템 알림 대신 앱 내 토스트/배너로 홀 전환 안내
- F3 GPS 홀 감지 자체(spec_3.md:70-77)는 알림 권한과 무관하게 동작
- 알림 비활성 상태는 설정 화면에서 iOS 알림 설정으로 딥링크 재유도 가능
- 재요청 팝업은 iOS 정책상 1회 이상 시스템 prompt 불가 — 설정 유도만 허용

알림 거부 시 핵심 기능(점수 입력, 홀 전환)에 영향 없음 — 무음 동작으로 처리한다.

---

## 7. iCloud / CloudKit (자동 권한)

- 관련 기능: F7 CloudKit sync (spec_3.md:112-114, 664)
- Info.plist 키 불필요 — 시스템 iCloud 계정 기반 자동 처리 (spec_3.md:664)
- SwiftData + CloudKit 연동: 첫 SwiftData write 시점에 내부적으로 권한 협상

**iCloud 미로그인 / iCloud Drive 비활성 시**

- 동작: 로컬 SwiftData만 활성화, 멀티 디바이스 sync 비활성 (spec_3.md:114)
- **[SPEC-UNDEFINED] UI 처리**: 설정 화면 또는 라운드 시작 화면에 "iCloud 미연결 — 이 기기에만 저장됩니다" 배너 표시 권장. 오류 alert 대신 비방해적 안내 선호.
- 라운드 기록 손실 방지: iCloud 연결 복구 시 로컬 SwiftData를 자동 merge. 충돌 해소 정책은 21-DATA_MODEL.md에서 정의.
- CloudKit Dashboard에서 별도 권한 설정 불필요 — iOS 개발자 계정 및 App ID의 CloudKit capability 활성화로 처리 (§9 구현 단계 책임)

---

## 8. 개인정보 처리 방침 (App Store 심사 대비)

App Store 심사 및 Privacy Nutrition Label 작성 시 아래 정책을 기준으로 한다 (CLAUDE.md §PROJECT).

- **위치**: 기기 외부 전송 절대 금지. 골프장 매칭 및 홀 감지에만 사용 (spec_3.md:667, CLAUDE.md §PROJECT)
- **동반자 이름**: 별명만 허용 (Player.name 모델 제약 — 21-DATA_MODEL.md). 실명 및 연락처 업로드 금지 (spec_3.md:282, 670, CLAUDE.md §PROJECT)
- **viewer 데이터 및 사진**: 공유 시점으로부터 7일 후 Cloudflare KV/R2 자동 삭제 (spec_3.md:669, CLAUDE.md §PROJECT, 30-API_SPEC §8)
- **디바이스 토큰**: 익명 UUID — 외부 식별 불가, 서버 측 PII 연결 없음 (spec_3.md:670)
- **HealthKit 데이터**: 기기 및 iCloud Health 외부로 전송하지 않음
- **권한 거부 시에도 동일 정책 유지**: 위 정책은 권한 허가 여부와 무관하게 적용

**Privacy Nutrition Label 수집 항목 요약** (App Store Connect 입력 기준):

| 데이터 유형 | 수집 여부 | 외부 전송 | 비고 |
|-----------|---------|---------|-----|
| 정확한 위치 | 조건부 (권한 허가 시) | 없음 | 기기 내 처리만 |
| 사진 | 조건부 (권한 허가 시) | viewer 공유 시만 | 7일 후 삭제 |
| 건강 데이터 | 조건부 (권한 허가 시) | 없음 | Apple Health 연동만 |
| 식별자 | 익명 UUID만 | 없음 | 실명/연락처 없음 |

**Privacy Manifest (PrivacyInfo.xcprivacy)**: iOS 17+ 필수 제출 항목. 위치, 사진, 카메라, HealthKit 사용 목적 선언 필요. 작성 시점은 구현 단계에서 결정 (§9 구현 단계 책임).

---

## 9. 책임 경계

### 책임 경계

| 문서 | 담당 영역 |
|------|----------|
| **본 문서 (53-PERMISSIONS)** | Info.plist 키 목록, usage string 한/영 카피, 요청 시점, 거부 fallback 정책 |
| `02-USER_FLOWS.md` | 권한 거부 후 사용자 플로우 분기 전체 (F-A L49, F-B L69) |
| `21-DATA_MODEL.md` | `Player.name`이 별명만 허용한다는 모델 제약 (실명 금지), CloudKit 충돌 해소 정책 |
| `30-API_SPEC.md` | viewer 7일 TTL, 서버 측 PII 차단 정책, KV/R2 삭제 메커니즘 |
| `33-SECURITY.md` (작성 예정) | bcrypt cost, 보안 헤더, PII 패턴 매칭 서버 구현 |
| `13-HAPTICS_AND_MOTION.md` (작성 예정) | 모션 권한 (`NSMotionUsageDescription`) 도입 시 §1 매트릭스 보강 |
| **구현 단계** | Xcode 빌드 설정, entitlements 파일, Privacy Manifest (`PrivacyInfo.xcprivacy`), App Store Connect Privacy 설문 |

본 문서는 사용자 대면 문자열(usage string)과 정책 방향만 정의한다. 실제 API 호출 코드, entitlements XML, Privacy Manifest 항목 값은 구현 단계 책임이다. 이 경계를 지켜야 문서 중복과 구현 단계 혼선을 방지할 수 있다.

### 부록: 후속 보완 TODO

아래 항목은 구현 착수 전 또는 글로벌 출시 전 반드시 보완한다.

**spec 미정의 5건** (헤더 [spec 미정의 항목 일람] 박스와 동일):

1. HealthKit Share vs Update 키 분리 구현 결정 (§3)
2. `NSPhotoLibraryAddUsageDescription` 포함 여부 확정 (§4)
3. iOS 14+ Precise Location 분기 UI 설계 (§2)
4. 알림 권한 거부 시 F3 fallback UI 구현 (§6)
5. iCloud 미로그인 시 배너 안내 UI 구현 (§7)

**영문 카피 4건 글로벌 출시 전 재검토** (§2~§5 각 [글로벌 검토 필요] 항목):

- 앱 이름 "Round-On"의 영어권 부정 함의 해소 후 usage string 일괄 재작성 (CLAUDE.md §PROJECT)
- 영문 카피 4건: 위치(§2), HealthKit(§3), 사진 Read(§4), 카메라(§5). 알림(§6)·iCloud(§7)은 Info.plist usage description 불필요로 해당 없음
- App Store 현지화(Localization) 파일에서 한국어/영어 카피를 별도 키로 관리할 것

---

*최종 업데이트: 2026-05-11*

# iOS Gemini OCR 통합 가이드

> **작성**: 2026-05-29
> **대상**: 다른 세션의 Claude (이 문서만 읽고 구현 가능하도록 자기완결로 작성)
> **근거**: `test-bed/` 의 Gemini A/B 실측 (16장 회귀셋). 측정 스크립트·정답은 `test-bed/gemini_ocr.py`, `test-bed/samples/`
> **결정 사항(사용자 확정)**: 품질 최우선, 속도(1초) 포기, **Gemini 우선 채택**, 모델은 `gemini-2.5-flash` 그대로
> **선행 문서**: `GOALS.md` (OCR 목표·게이트), `plans/2026-05-28_postround-killer.md`

---

## 0. TL;DR — 무엇을 만드나

기존 iOS 앱은 사진을 **Apple Vision on-device**로 OCR한다 (`Shared/OCR/GolfScorecardExtractor.swift`). 이걸 **Gemini Vision API 호출**로 교체(우선)한다.

- 입력: 스코어카드 사진 1장 (가로 태블릿 출력 PNG / 스마트스코어 앱 공유 스크린샷 JPG)
- 처리: 사진을 Gemini로 전송 → 구조화 JSON(코스명·날짜·홀별 over-par·합계) 수신
- 출력: 기존 `Round` (SwiftData @Model)로 변환해 import
- 핵심: **구조 검증 + 재시도**로 LLM 비결정성(특정 이미지 재현적 오류) 방어

⚠️ 이 방향은 사진을 외부(Google)로 전송한다. `GOALS.md §8.2`의 "on-device·PII-free·외부전송 금지" 금지선을 **"사용자 옵트인 시 클라우드 전송 허용"**으로 개정하는 결정이 전제다. (사용자 확정됨)

→ 따라서 이 작업은 **OCR 교체(§2~6)에 그치지 않고, 개인정보 동의·설정·처리방침·광고까지 한 묶음**이다. 사진 외부전송은 **동의 팝업·설정 노출·웹 처리방침(`golf.zerolive.co.kr/privacy`)이 갖춰져야 App Store 심사를 통과**한다(§9). Gemini 비용 상쇄용 광고(분석 3회당 1회)도 포함(§10). 이미 출시된 **Wander 앱(`/Users/zerolive/work/Wander`)이 동일 패턴을 구현**해 두었으니 그대로 이식한다(§14 경로표).

---

## 1. 왜 Gemini인가 (측정 근거)

16장 회귀셋(가로카드 8 + 앱스샷 8), 각 이미지를 사람이 직접 판독한 ground-truth 기준 실측:

| | Apple Vision (on-device) | **Gemini 2.5-flash** |
|---|---|---|
| 가로카드 플레이어 셀 | 95.8% | **100%** |
| 가로카드 PAR 셀 | 93.1% | 96.5% |
| 가로카드 코스명 / 날짜 | 75% / 100% | 88% / 100% |
| 앱스샷 플레이어 셀 | **0%** (헤더행 없어 실패) | **92.4%** (이상치 1장 제외 100%) |
| 앱스샷 코스명 / 날짜 | 87.5% / 0% | 100% / 100% |
| 속도 | 0.9초 | ~20초 |

- **본인+동반자 점수(가장 중요)는 Gemini가 가로카드 100%.** 앱스샷은 Vision이 아예 불가하고 Gemini만 가능.
- 속도 20초는 "AI 정밀 분석 중" 로딩 UX로 흡수 (사용자 결정: 품질 우선).
- par 행은 0.7%p 더 짜낼 수 있는 하이브리드(Vision 힌트 동봉)도 있으나 **채택 안 함** — par는 코스 DB(979곳)에서 보강 가능하고 복잡도만 늘기 때문. **Gemini 단독으로 간다.**

---

## 2. Gemini 호출 사양 (test-bed에서 검증된 그대로 이식)

### 2.1 엔드포인트 / 모델

```
POST https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={API_KEY}
Content-Type: application/json
```

### 2.2 요청 body

```json
{
  "contents": [{
    "parts": [
      { "text": "<PROMPT 아래 2.4>" },
      { "inline_data": { "mime_type": "image/jpeg", "data": "<base64 이미지>" } }
    ]
  }],
  "generationConfig": {
    "responseMimeType": "application/json",
    "responseSchema": { /* 아래 2.3 */ },
    "temperature": 0
  }
}
```

- `mime_type`: PNG면 `image/png`, JPG면 `image/jpeg`.
- 이미지는 base64 인코딩. iOS에서 `Data` → `.base64EncodedString()`.
- **이미지 다운스케일 권장**: 원본이 크면(>1600px) 긴 변 ~1600px로 리사이즈 후 전송 (정확도 유지하며 업로드/추론 시간 단축). test-bed 원본은 909~1800px대에서 잘 동작.

### 2.3 responseSchema (구조화 출력 강제 — 그대로 사용)

```json
{
  "type": "object",
  "properties": {
    "courseName": { "type": "string" },
    "date": { "type": "string" },
    "rows": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "label":   { "type": "string" },
          "kind":    { "type": "string", "enum": ["par", "player"] },
          "isOwner": { "type": "boolean" },
          "values":  { "type": "array", "items": { "type": "integer" } },
          "out":     { "type": "integer" },
          "inScore": { "type": "integer" },
          "total":   { "type": "integer" }
        },
        "required": ["label", "kind", "values", "out", "inScore", "total"]
      }
    }
  },
  "required": ["courseName", "date", "rows"]
}
```

### 2.4 PROMPT (한국어, 그대로 사용 — 검증됨)

```
이 이미지는 한국 골프 스코어카드(스마트스코어)입니다. 가로 표 형식이거나, 배경 사진 위에 본인 점수 2줄만 있는 앱 공유 카드일 수 있습니다.

규칙:
1. 표의 각 점수 셀에는 PAR 대비 차이값(over-par delta)이 인쇄되어 있습니다. 파4홀에서 5타=+1, 4타=0, 3타=-1(버디). 셀 안의 정수만 읽으세요.
2. 숫자 위/아래의 점(dot)·막대(bar) 같은 작은 마크는 over/under 시각표시이니 무시하세요. 단 음수(버디·이글)는 반드시 음수로 표기.
3. PAR 행이 보이면 kind="par", values=각 홀 실제 par 값(3/4/5).
4. 플레이어 행은 kind="player". values=홀별 over-par 정수(전반9 + 후반9 = 18개, 9홀 카드면 9개). out=전반 실제 타수, inScore=후반 실제 타수, total=18홀 실제 합계.
5. 본인(최상단·가장 진한 글씨·이름 전체표기, 보통 PAR 바로 아래)은 isOwner=true.
6. courseName=골프장 한글명(괄호 안 구 명칭 제외), date=YYYY-MM-DD.
정확도가 가장 중요합니다. 합계가 맞는지 스스로 검산하세요.
```

### 2.5 응답 파싱

성공 시 `candidates[0].content.parts[0].text` 가 위 스키마를 따르는 **JSON 문자열**. 이걸 다시 파싱한다.

> **데이터 의미 핵심**: `values`는 **실제 타수가 아니라 over-par delta**다. 실제 타수 = `해당 홀 par + delta`. `out`/`inScore`/`total`은 **실제 타수 합계**(이미지에 직접 인쇄된 값). 앱스샷에는 PAR 행이 없으므로 `rows`에 player만 온다.

---

## 3. Swift 구현 설계

### 3.1 새 타입: 응답 모델

`Shared/OCR/GeminiScorecard.swift` (신규)

```swift
import Foundation

/// Gemini 응답 1:1 매핑. values = over-par delta (실제 타수 아님).
public struct GeminiScorecard: Codable, Sendable {
    public let courseName: String
    public let date: String          // "YYYY-MM-DD"
    public let rows: [GeminiRow]

    public var parRow: GeminiRow? { rows.first { $0.kind == "par" } }
    public var players: [GeminiRow] { rows.filter { $0.kind == "player" } }
}

public struct GeminiRow: Codable, Sendable {
    public let label: String
    public let kind: String          // "par" | "player"
    public let isOwner: Bool?
    public let values: [Int]         // over-par delta (par행은 실제 par 3/4/5)
    public let out: Int
    public let inScore: Int
    public let total: Int

    enum CodingKeys: String, CodingKey {
        case label, kind, isOwner, values, out, total
        case inScore = "in"          // Gemini는 "inScore" 키 사용. 아래 주의 참고.
    }
}
```

> ⚠️ **키 주의**: responseSchema는 `inScore`로 정의돼 있으므로 Gemini 응답 JSON의 키도 `inScore`다. 위 `CodingKeys`에서 `case inScore = "inScore"`로 맞춰라 (`"in"`이 아님 — test-bed 파이썬은 `inScore`를 그대로 받았다). **구현 후 실제 응답 키를 한 번 로그로 확인할 것.**

### 3.2 새 Extractor (기존 GolfScorecardExtractor와 병렬)

`Shared/OCR/GeminiScorecardExtractor.swift` (신규)

```swift
public final class GeminiScorecardExtractor {
    private let apiKey: String
    private let model = "gemini-2.5-flash"
    private let session: URLSession

    public init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    /// 사진 → 검증 통과한 GeminiScorecard. 검증 실패 시 maxRetries 만큼 재시도.
    public func extract(imageData: Data, mime: String, holeCount: Int = 18,
                        maxRetries: Int = 2) async throws -> GeminiScorecard {
        var lastError: Error?
        for attempt in 0...maxRetries {
            do {
                let card = try await callOnce(imageData: imageData, mime: mime,
                                              temperature: attempt == 0 ? 0 : 0.2)
                try Validator.check(card, holeCount: holeCount)   // 4장 참고
                return card
            } catch {
                lastError = error                                 // 검증 실패 → 재시도
            }
        }
        throw lastError ?? OCRError.exhausted
    }

    private func callOnce(imageData: Data, mime: String, temperature: Double) async throws -> GeminiScorecard {
        // 1) body 구성 (2.2~2.4) → 2) POST → 3) candidates[0].content.parts[0].text 파싱 → GeminiScorecard
        // URLSession.data(for:) async/await. 타임아웃 60s. 4xx/5xx 시 throw.
    }
}
```

기존 코드 패턴 참고: 네트워크/async 방식은 `Shared/Repositories/CourseRepository.swift`의 URLSession async/await + ETag fallback 구조를 그대로 따른다.

### 3.3 데이터 매핑: GeminiScorecard → Round

기존 import 매퍼(`App-iOS/Import/.../ScorecardMapper`)를 확장하거나 새 매퍼를 만든다. 변환 규칙:

1. **홀별 실제 타수** = `par[i] + values[i]`.
   - 가로카드: `parRow.values`가 홀별 par. 이걸로 모든 player의 delta를 실제 타수로 환산.
   - **앱스샷(par 행 없음)**: 코스 DB(`GolfCourse`)에서 홀별 par를 가져와 환산. DB에 홀별 par가 없으면 → 홀별 실제 타수는 못 만들고 `out`/`inScore`/`total`(이미지 직접 표시값)만 신뢰. (이 경우 `Round`에 홀 스코어 없이 합계만 저장하거나, 사용자 review에서 par 입력)
2. **owner 행**(`isOwner==true`) → `Round`의 본인 스코어. 동반자 행 → `Round.players`.
3. `courseName` → §5의 코스명 매칭으로 `courseId` 확정.
4. `date`("YYYY-MM-DD") → `Round.date`. 실패/누락 시 사진 EXIF 촬영일 폴백(§6).
5. 변환 후 `CourseNameMatcher.findConflictingRound(date:courseName:context:)`로 중복 라운드 감지(기존 로직 재사용).

기존 `Round` 모델 필드: `id, date, courseId, courseName, frontCourseName, backCourseName, isImported(=true로), players: [Player]?, holes: [HoleScore]?` — `Shared/Models/Round.swift` 참조.

---

## 4. 구조 검증 + 재시도 (★ 가장 중요 — 품질 100%의 유일한 장애물)

### 4.1 왜 필요한가 (실측)

회귀셋에서 단 1장(IMG_1358, 앱스샷)이 `temperature=0`인데도 **호출마다 39~88%로 흔들렸다.** 실패 양상: **back 9홀을 통째로 누락**(`values` 길이 9), `inScore=0`, `total=56`. 그런데 이 출력은 **`out+inScore==total`(56+0=56)을 거짓 통과**한다. 즉 합계 검증만으로는 못 잡는다.

### 4.2 검증 규칙 (`Shared/OCR/ScorecardValidator.swift` 신규)

player 행마다 아래를 **모두** 통과해야 정상으로 인정. 하나라도 실패하면 재시도 트리거:

1. **값 개수 일치**: `values.count == holeCount` (18 또는 9). ← IMG_1358 케이스를 여기서 잡는다.
2. **합계 정합**: `out + inScore == total`.
3. **(par 있을 때) over-par 정합**: `sum(front delta) + sum(front par) == out`, `sum(back delta) + sum(back par) == inScore`.
4. **현실성**: `total`이 코스 par 합(보통 72) 대비 비현실적이지 않을 것. 가드: `total >= parTotal - 18 && total <= parTotal + 90`. (언더 18 초과/오버 90 초과면 오인식)
5. **par 행 자체 검증**(있으면): 모든 값 ∈ {3,4,5}, 9홀 합 == 35/36 (또는 27/45 등 코스별).

### 4.3 재시도 정책

- 1차 `temperature=0`. 재시도 시 `0.2`로 살짝 올려 다른 디코딩 유도(같은 입력 반복 실패 회피).
- 최대 2회 재시도(총 3회). 그래도 전부 실패 → **사용자 수동 보정 화면으로 폴백**(앱이 죽지 않게). 부분 결과(검증 통과한 행만)는 미리 채워줄 수 있음.
- 재시도는 추가 ~20초씩 → "분석 중" 로딩 유지. 드문 케이스라 평균 영향 작음.

---

## 5. 코스명 매칭 (기존 자산 재사용)

Gemini `courseName`(한글) → DB 979곳 매칭. **새로 만들지 말고** `Shared/Models/CourseNameMatcher.swift` 재사용:

- `CourseNameMatcher.normalize(_:)`, `areSimilar(_:_:)`, `matches(course:query:)`.
- 매칭되면 `GolfCourse.id`를 `Round.courseId`에 채움. 미매칭이면 `courseName`만 저장하고 review에서 사용자 보정.
- **이미지별 표기 차이 주의**(실측): 같은 코스라도 가로카드는 영문 로고("Orange Dunes"), 앱스샷은 한글("골프존카운티 송도")처럼 다르게 나온다. alias 매칭(v4)이 이를 흡수해야 한다. 매칭 실패율이 높으면 alias 보강 대상.

---

## 6. 날짜 추출

1. 1차: Gemini `date`("YYYY-MM-DD"). 실측 100% 정확(가로/앱스샷 모두). 단 앱 표기가 `2026.05.25`(점)일 때 Gemini가 점 형식으로 줄 수 있으니 **`.`/`/` → `-` 정규화** 후 파싱.
2. 폴백: 파싱 실패 시 사진 **EXIF 촬영일**(`DateTimeOriginal`). `ImageIO`/`CGImageSource`로 읽기.

---

## 7. API 키 관리 (보안 결정 필요)

기존 패턴: `Info.plist`에 `ROUNDON_API_BEARER`를 xcconfig 빌드 주입(`$(ROUNDON_API_BEARER)`), 런타임에 읽음 (`Shared/Repositories/CourseRepository.swift`).

두 옵션 — 트레이드오프 명시:

| | A. 앱에 직접 키 | B. Worker 프록시 경유 |
|---|---|---|
| 구현 | 기존 Info.plist 패턴 그대로 `GEMINI_API_KEY` 주입 | Cloudflare Worker에 `/v1/ocr` 신설, 사진 relay |
| 키 보안 | 앱 바이너리에서 추출 가능(위험) | 키는 서버에만 |
| 사용량 제어 | 불가(키 유출 시 남용) | Worker에서 rate limit/인증 |
| 프라이버시 | 사진이 단말→Google 직접 | 사진이 단말→Worker→Google (Worker도 경유) |
| 비용 | Gemini 직접 | + Worker 대역폭 |

- **단기(PoC/베타)**: A로 빠르게. 키는 xcconfig(커밋 금지, `.gitignore`), Info.plist 주입.
- **운영**: B 권장(키 보호 + 사용량 제어). 단 GOALS의 free-tier·Worker 운영 원칙과 비용 재검토 필요.
- ⚠️ 키를 **소스/Info.plist 평문 커밋 금지**. 기존 `ROUNDON_API_BEARER`와 동일하게 xcconfig + gitignore.

---

## 8. UX (사용자 결정: 속도 포기, 품질 우선)

- import 시작 → **"AI가 스코어카드를 정밀 분석하고 있어요"** + circle/sprite 로딩 애니메이션. ~20초(재시도 시 더) 동안 유지.
- **최초 1회 옵트인 고지**: "정확한 인식을 위해 사진이 분석 서버(Google)로 전송됩니다. 동의하시겠어요?" — 동의 없이는 전송 금지(금지선 개정의 핵심 안전장치).
- 결과는 항상 **review 화면**에서 확인/수정 후 저장 (기존 `ImportReviewView` 흐름 재사용). 검증 실패 폴백 시 수동 입력.

진입점: 기존 `App-iOS/Views/Import/ImportLandingView.swift`(PhotosPicker) → `ImportViewModel.run(item:ownerName:)`. 이 `run()` 내부의 Vision 호출(`GolfScorecardExtractor().extract()`)을 `GeminiScorecardExtractor().extract()` (async)로 교체. ViewModel은 이미 `@Observable @MainActor`, phase(idle/running/review/...) 상태 관리하므로 로딩 UX 연결 쉬움.

---

## 9. 개인정보 보호 및 App Store 규정 준수 (★ 출시 필수 — Wander 패턴 이식)

사진을 외부(Google)로 보내므로 **App Store 심사 통과의 전제 조건**이다. Wander(`/Users/zerolive/work/Wander`)가 동일 구조를 이미 출시 상태로 구현해 두었으니 **새로 설계하지 말고 이식**한다 (§14 경로표).

### 9.1 외부전송 동의 팝업 (최초 1회, 동의 전 전송 금지)

- 스코어카드를 **처음 분석하기 직전** 모달 고지 → 동의해야만 Gemini 호출. 거부 시 분석 차단(또는 수동 입력 안내).
- 동의 상태: `UserDefaults` 키 `gemini_data_consent_accepted`(Bool). `ConsentManager`(Wander `AIUsageManager` 패턴) — `accept()` / `revoke()`.
- 팝업 문구(라운드온용):
  - 제목: **"스코어카드 분석 데이터 전송 안내"**
  - 본문: "스코어카드 자동 인식을 위해 **선택하신 사진**이 외부 AI 서버로 전송됩니다."
  - **전송 데이터**: 스코어카드 사진 1장(분석용), 촬영일(EXIF)
  - **수신자**: Google LLC (Gemini API)
  - **목적**: 스코어/코스명/날짜 자동 인식
  - **보관**: "전송된 사진은 분석 목적으로만 사용되며 별도 저장되지 않습니다."
  - 버튼: [동의하고 분석] / [취소]

### 9.2 설정 > "개인정보 및 데이터 전송" 탭

Wander `SettingsView`의 `aiPrivacyRow` 패턴. 사용자가 **눌러서 확인** 가능해야 한다(사용자 요구사항):

- **동의 상태** 행 (동의함 ✓ / 미동의, 동의 시점 날짜 표시)
- **전송 데이터** 행: 스코어카드 사진(분석 시), 촬영일
- **수신자** 행: Google LLC (Gemini API)
- **목적** 행: 스코어카드 자동 인식 · 분석 후 미저장
- **동의 시점** 행: "스코어카드 최초 분석 시 명시적 동의, 동의 전 미전송"
- **"개인정보 처리방침 보기"** → `golf.zerolive.co.kr/privacy` (in-app SFSafariViewController 또는 웹뷰)
- **"데이터 전송 동의 철회"** 버튼 → `gemini_data_consent_accepted=false`, 재사용 시 팝업 재노출

### 9.3 개인정보처리방침 — Worker 서빙 + 연결 (필수)

- **`golf.zerolive.co.kr/privacy`** 에 HTML 방침 페이지를 Cloudflare Worker로 서빙. Wander `wander-share-worker`의 `generatePrivacyPage()`(index.ts 609–748줄) 패턴 복제. (라운드온 viewer가 이미 `golf.zerolive.co.kr` Worker에 있으므로 라우트 추가)
- 방침 본문 필수 항목:
  1. **스코어카드 분석(AI)**: 동의 후 사진 1장 + 촬영일을 Gemini API(Google)로 전송, 분석 후 미저장
  2. **위치**: 기존 정책 유지 — 위치 좌표 **외부 전송 안 함**(on-device), viewer엔 별명+스코어만
  3. **광고(AdMob)**: IDFA·기기정보·광고 상호작용, ATT 동의 기반
  4. **수집 안 함**: 자체 서버 PII·analytics 미수집(viewer KV는 7일 후 자동삭제)
  5. **저장 위치**: 기기 내(SwiftData) / iCloud(공유) / Google(분석 일시처리)
  6. **문의·삭제 요청** 연락처
- **App Store Connect 제출 시 이 URL 필수 입력.** 출시 전 200 응답 확인.
- **app-ads.txt**도 같은 Worker로 서빙(광고 수익 검증, Wander index.ts 99–108줄 패턴).

### 9.4 App Store privacy 매니페스트 / nutrition label

- **`PrivacyInfo.xcprivacy`** 갱신: 사진(앱기능, 추적 아님), 광고 도입 시 IDFA·기기ID(추적). `NSPrivacyAccessedAPICategoryUserDefaults`(CA92.1).
- App Store Connect privacy 질문지를 이 매니페스트와 **일치**시킬 것.

### 9.5 ATT(추적 투명성) — 광고 IDFA 사용 시

- `Info.plist` `NSUserTrackingUsageDescription` 추가(예: "관련성 높은 광고 제공을 위해 사용됩니다. 광고 수익은 앱 무료 제공에 사용됩니다.").
- 앱 시작 후 수 초 뒤 `ATTrackingManager.requestTrackingAuthorization` (Wander `WanderApp.swift` 305–336줄). 거부 시 비맞춤 광고.

### 9.6 동의 철회 / 데이터 삭제

- 동의 철회(9.2) + 로컬 라운드 데이터 삭제 항목 제공(Wander SettingsView 507–626줄). 되돌릴 수 없음 확인 모달.

---

## 10. 광고 (AdMob) — "분석 3회당 광고 1회" + 비용 상쇄

Gemini 호출은 건당 비용이 발생하므로, **무료 제공을 위해 광고로 상쇄**한다. 사용자 요구: **스코어카드 3번 분석하면 광고 1회**.

### 10.1 게이팅 모델

- 카운터: `UserDefaults` 키 `scorecard_analysis_count`(Int). **분석 성공(검증 통과)마다 +1**.
- `count % 3 == 0` 시점에 **전면광고(Interstitial) 1회** 노출 (결과 review 진입 직전 또는 직후).
- Wander는 "사용량 소진 → 보상형 광고 보고 충전"(`RewardedAdManager`, 임계값 3)인데, 라운드온 요구는 **빈도 기반 전면광고**다. 둘 차이:
  - **전면(Interstitial)**: N회마다 강제 1회. 요구사항에 부합. 구현 단순. (권장)
  - **보상형(Rewarded)**: 사용자가 자발적으로 보고 혜택. Wander 코드 그대로 재활용 가능하나 "3번마다"와 결이 다름.
  - → **기본: 전면 + 카운터.** Wander `RewardedAdManager`의 카운트/날짜 저장·로드 구조를 `InterstitialAdManager`로 변형.
- (선택) 향후 "프리미엄 구독 시 광고 제거" 여지 — GOALS "구독 0" 원칙과 상충하니 별도 결정.

### 10.2 AdMob 설정 가이드

1. **SDK**: Google Mobile Ads (Swift Package Manager `GoogleMobileAds`).
2. **앱 ID**: `Info.plist` `GADApplicationIdentifier` = AdMob 콘솔에서 발급한 라운드온 앱 ID. (개발 중엔 Google 테스트 앱 ID/유닛 ID 사용 — 실 광고 클릭은 계정 정지 위험)
3. **Ad Unit ID**: 전면광고 유닛 생성 → `Secrets.plist`(커밋 금지, .gitignore)에 `ADMOB_INTERSTITIAL_ID` 저장. Wander `Secrets.plist` 패턴.
4. **app-ads.txt**: `golf.zerolive.co.kr/app-ads.txt` 를 Worker로 서빙 (`google.com, pub-XXXX, DIRECT, f08c47fec0942fa0`). App Store 도메인과 연결.
5. **ATT**: §9.5. IDFA 권한 → 맞춤/비맞춤 광고 분기.
6. **초기화**: 앱 시작 시 `MobileAds.shared.start()`. 전면광고 사전 로드(`InterstitialAd.load`) 후 트리거 시점에 present.
7. `PrivacyInfo.xcprivacy` 광고 데이터 타입 신고(§9.4).

---

## 11. 통합 체크리스트 (구현 순서)

**OCR 코어**
1. [ ] `GeminiScorecard.swift` (응답 모델) 추가 — `inScore` 키 실제 응답으로 확인
2. [ ] `GeminiScorecardExtractor.swift` (호출 + 재시도) 추가, CourseRepository의 URLSession 패턴 따름
3. [ ] `ScorecardValidator.swift` (§4 검증 규칙) 추가 — **값 개수 == holeCount 반드시 포함**
4. [ ] API 키 주입: xcconfig `GEMINI_API_KEY` + Info.plist (옵션 A 단기)
5. [ ] 매퍼: GeminiScorecard → Round (over-par→실타수 환산, owner/players 분리, par 없는 앱스샷 처리)
6. [ ] 코스명 매칭(`CourseNameMatcher`) + 날짜 정규화/EXIF 폴백 연결
7. [ ] `ImportViewModel.run()` 의 Vision 호출을 Gemini async 호출로 교체, 로딩/분석중 UX

**개인정보·규정 (출시 필수)**
8. [ ] 외부전송 동의 팝업 + `ConsentManager`(`gemini_data_consent_accepted`) — 동의 전 분석 차단 (§9.1)
9. [ ] 설정 > "개인정보 및 데이터 전송" 탭(4행 + 방침링크 + 철회) (§9.2)
10. [ ] `golf.zerolive.co.kr/privacy` Worker 페이지 작성·배포·200 확인 + 앱/스토어 연결 (§9.3)
11. [ ] `PrivacyInfo.xcprivacy` 갱신 + App Store Connect privacy 질문지 일치 (§9.4)
12. [ ] (광고 IDFA 시) ATT 권한 + `NSUserTrackingUsageDescription` (§9.5)
13. [ ] 동의 철회 / 데이터 삭제 항목 (§9.6)

**광고**
14. [ ] AdMob SDK 연동 + `GADApplicationIdentifier` + Ad Unit ID(Secrets.plist) (§10.2)
15. [ ] `scorecard_analysis_count` 카운터 + 3회당 전면광고 게이팅 (§10.1)
16. [ ] `golf.zerolive.co.kr/app-ads.txt` Worker 서빙 (§10.2)

**마무리**
17. [ ] 검증: §12
18. [ ] `GOALS.md §8.2` 금지선 문구 개정(옵트인 클라우드 전송 허용) + 광고/구독 정책 반영

> Vision 코드(`GolfScorecardExtractor`)는 당장 삭제하지 말 것 — 오프라인 폴백/회귀 비교용으로 남겨두고, 안정화 후 정리.

---

## 12. 검증 (test-bed 회귀셋 재사용)

- 정답 라벨: `test-bed/samples/smartscore/expected/*.json`(가로카드 8) + `test-bed/samples/smartscore-app/expected/*.json`(앱스샷 8). **각 이미지를 사람이 직접 판독한 ground-truth**(JPG↔PNG 교차참조 금지 원칙으로 작성됨).
- 스키마: `cardType, valueFormat("overPar"), courseName, date, owner, holeCount, rows[{label,kind,values(over-par),out,in,total,isOwner}]`.
- iOS에서 동일 이미지를 Gemini로 돌려 셀 일치율 측정 → 가로카드 100%, 앱스샷 owner 92%+(IMG_1358 재시도로 복구) 재현되는지 확인.
- 기대 게이트(GOALS §2.1): 셀 95%+, par 행, 합계 자가검증 100%, 코스명 90%+(alias), 날짜 95%+.

---

## 13. 절대 주의 (금지선/함정)

- 🚫 **`values`를 실제 타수로 착각 금지** — over-par delta다. 실타수 = par + delta.
- 🚫 **합계 검증만으로 이상치 거르기 금지** — IMG_1358처럼 `out+in=total`을 거짓 통과한다. **값 개수==holeCount 검증 필수.**
- 🚫 **API 키 평문 커밋 금지** (xcconfig/Secrets.plist + .gitignore).
- 🚫 **동의(옵트인) 없이 사진 전송 절대 금지** — 금지선 개정의 핵심 안전장치이자 App Store 심사 필수. 동의 상태 false면 분석 자체를 막아라.
- 🚫 **개인정보처리방침 URL 없이 출시 금지** — App Store Connect 제출에 방침 URL 필수. `golf.zerolive.co.kr/privacy` 가 200으로 떠야 한다.
- 🚫 **광고에 IDFA 쓰면서 ATT 권한 요청 누락 금지** — 심사 리젝 사유. `NSUserTrackingUsageDescription` + `ATTrackingManager` 필수.
- ⚠️ **앱스샷엔 par 행이 없다** — 코스 DB par로 보강하거나 합계만 신뢰.
- ⚠️ **par는 코스 DB로 보강 가능** — Gemini par 96.5%에 의존하지 말고 매칭된 `GolfCourse`의 par를 신뢰원으로 쓰는 게 더 정확할 수 있다.
- ⚠️ **PrivacyInfo.xcprivacy 갱신** — 사진(앱기능), 광고 시 IDFA·기기ID(추적) 신고. App Store privacy nutrition label과 일치시켜라.

---

## 14. 참고 파일 (이 워크스페이스)

| 목적 | 경로 |
|---|---|
| 검증된 Gemini 호출 로직(파이썬 원본) | `test-bed/gemini_ocr.py` |
| 정답 회귀셋 + 측정 스크립트 | `test-bed/samples/`, `test-bed/gemini_ab.py` |
| 기존 Vision Extractor(교체 대상) | `Shared/OCR/GolfScorecardExtractor.swift` |
| 기존 OCR 결과 모델 | `Shared/OCR/Models.swift` |
| Import 화면 | `App-iOS/Views/Import/ImportLandingView.swift` |
| Import ViewModel(교체 지점) | `App-iOS/Import/ViewModels/ImportViewModel.swift` |
| 라운드 모델 | `Shared/Models/Round.swift` |
| 코스명 매칭(재사용) | `Shared/Models/CourseNameMatcher.swift` |
| 네트워크 패턴 참고 + 키 주입 | `Shared/Repositories/CourseRepository.swift` |
| OCR 목표·게이트 | `GOALS.md` |

### 참고: Wander 앱 (이미 App Store 출시, Gemini+AdMob+개인정보 구현 완료)

`/Users/zerolive/work/Wander` — 같은 패턴이 **이미 동작하는 레퍼런스**. 새로 설계하지 말고 이식하라.

| 목적 | Wander 경로 |
|---|---|
| 외부전송 동의 팝업 (`AIDataConsentOverlay`) | `src/Views/Result/ResultView.swift` (939–1040줄) |
| 동의 상태 관리 (`acceptAIConsent`/`revokeAIConsent`) | `src/Core/AIUsageManager.swift` (키 `ai_data_consent_accepted`) |
| 설정 > AI/개인정보 탭 (4행 + 방침링크 + 철회) | `src/Views/Settings/SettingsView.swift` (260–500줄, `aiPrivacyRow`) |
| 개인정보처리방침 Worker (`generatePrivacyPage`) | `wander-share-worker/dawn-band-946e/src/index.ts` (609–748줄) → `wander.zerolive.co.kr/privacy` |
| app-ads.txt 서빙 | `wander-share-worker/src/index.ts` (99–108줄) |
| 보상형 광고 + 횟수 게이팅 | `src/Services/AdService/RewardedAdManager.swift` (키 `admob_reward_daily_count`, 임계값 3) |
| ATT 권한 요청 | `src/WanderApp.swift` (305–336줄) |
| App Store privacy 매니페스트 | `src/Resources/PrivacyInfo.xcprivacy` |
| AdMob/Ad Unit ID 시크릿 | `src/Secrets.plist` (`ADMOB_REWARDED_ID`), Info.plist `GADApplicationIdentifier` |
| 데이터 삭제/캐시 삭제 | `src/Views/Settings/SettingsView.swift` (507–626줄) |

---

*이 가이드는 test-bed 실측(2026-05-29) 기반. 측정 원본과 정답은 `test-bed/`에 보존됨.*

# 50 — 개인정보 처리방침 (Privacy Policy)

> **상태**: 현행화 완료(2026-06-05) · 법적 검토 권장 · placeholder 확정 완료
>
> ⚠️ **2026-05-18 변경**: viewer 사진 공유 기능 폐기. R2 사진 업로드·EXIF GPS strip 관련 항목은 모두 무효. **viewer 외부 전송 데이터 = 동반자 별명 + 스코어 + deviceToken(익명 UUID) + PIN(bcrypt)만 — 좌표·사진 없음**.
>
> ⚠️ **2026-06-05 현행화**: 광고(AdMob)·AI 스코어카드 인식(Google Gemini)·골프장 검색(카카오) 도입을 반영. **IDFA(광고 식별자) 수집 + ATT 추적 사용**, **스코어카드 이미지를 Google Gemini로 전송**, **골프장 검색 시 카카오로 좌표 전송** 사실을 본문에 반영.

> **관련 문서**: [01-SPEC](01-SPEC.md) · [33-SECURITY](33-SECURITY.md) · [53-PERMISSIONS](53-PERMISSIONS.md) · [21-DATA_MODEL](21-DATA_MODEL.md) · [30-API_SPEC](30-API_SPEC.md) · [전체 인덱스](README.md)

> **작성일**: 2026-05-11 (현행화: 2026-06-05)
> **버전**: v4 기반
> **상태**: 현행화 완료 — App Store 제출 전 법적 검토 권장
> **출처 명세서**: [기능 명세서 v4](01-SPEC.md) §9 (01-SPEC.md:655-672), §3.4 (01-SPEC.md:274-284)
> **관련 문서**: `33-SECURITY.md`, `53-PERMISSIONS.md`, `21-DATA_MODEL.md`, `30-API_SPEC.md`

---

> **[확정 항목 일람 — 확정 완료 (2026-06-05)]**
>
> 아래 6건은 모두 실제 값으로 확정되었습니다.
>
> | # | 항목 | 확정값 |
> |---|------|--------|
> | 1 | 사업자명 및 대표자명 | `사과와제로` |
> | 2 | 개인정보 보호책임자 | `이용섭` |
> | 3 | 연락 이메일 | `zerolive7@gmail.com` |
> | 4 | 사업장 주소 | `서울특별시 광진구 광나루로 44길 39` |
> | 5 | 본 방침 시행일 | `2026-06-05` |
> | 6 | 법적 관할 | `대한민국법` (영어권 출시 시 GDPR/CCPA 추가 검토 필요) |

---

## 1. 총칙

`사과와제로` (이하 "회사")이 운영하는 **라운드온(Round-On)** (이하 "본 앱")은 「개인정보 보호법」(이하 "PIPA") 제30조에 따라 정보주체의 개인정보를 보호하고 이와 관련한 고충을 신속하고 원활하게 처리할 수 있도록 다음과 같이 개인정보 처리방침을 수립·공개합니다.

### 1.1 적용 범위

본 방침은 다음 서비스 전반에 적용됩니다.

- **iOS 앱** 라운드온(Round-On) — iPhone 및 Apple Watch 클라이언트
- **viewer 웹** `golf.zerolive.co.kr` — 라운드 스코어카드 공유 페이지

### 1.2 PIPA §30 의무 고지 항목

본 방침은 PIPA §30이 요구하는 다음 11개 항목을 모두 포함합니다.

| 번호 | 항목 | 본 방침 위치 |
|------|------|------------|
| 1 | 개인정보 처리 목적 | §3 |
| 2 | 처리하는 개인정보 항목 | §2 |
| 3 | 개인정보 보유·이용 기간 | §4 |
| 4 | 제3자 제공 여부 | §5.1 |
| 5 | 처리 위탁 여부 | §5.2 |
| 6 | 정보주체의 권리·의무 | §6.1 |
| 7 | 개인정보 파기 절차·방법 | §6.2 |
| 8 | 개인정보 보호책임자 | §11.1 |
| 9 | 자동화된 개인정보 수집 장치 | §2 표 비고 |
| 10 | 안전성 확보 조치 | §7 |
| 11 | 방침 변경 절차 | §12 |

### 1.3 개인정보 처리 원칙

회사는 다음 원칙을 준수합니다.

- **수집 최소화**: 서비스 제공에 필요한 최소한의 정보만 수집합니다.
- **목적 제한**: 수집 목적 외 용도로 개인정보를 사용하지 않습니다.
- **투명성**: 수집 항목, 목적, 보유 기간을 명확히 공개합니다.
- **안전성**: 기술적·관리적·물리적 보호 조치를 시행합니다.
- **정보주체 권리 보장**: 열람·정정·삭제·처리 정지 권리를 보장합니다.
- **위치·HealthKit 최소 전송 원칙**: 골프장 자동 매칭(F1) 및 워크아웃 기록(F8)에 사용하는 위치 정보와 건강 데이터는 기기 내에서 처리하며 외부로 전송하지 않습니다. **예외**: 사용자가 직접 골프장 검색을 실행한 경우에 한해, 검색 결과 정렬 목적으로 카카오 지도 API에 좌표를 전송합니다(§2·§5.2). HealthKit 데이터는 어떠한 경우에도 외부로 전송하지 않습니다. (CLAUDE.md §PROJECT)

### 1.4 법적 검토 권장

본 문서는 정책 방향 및 placeholder를 제공하는 초안입니다. App Store 제출 전 법률 전문가의 검토를 권장합니다. 본 문서는 법적 책임을 지지 않습니다.

---

## 2. 수집하는 개인정보 항목

회사는 아래 7종의 정보를 처리합니다. 별도 회원가입, 이름, 연락처, 생년월일은 수집하지 않습니다.

| 항목 | 수집 시점 | 저장 위치 | 외부 전송 | 출처 |
|------|---------|---------|---------|------|
| 위치 정보 (GPS, Precise) | 앱 실행 시 골프장 자동 매칭 (F1) | 기기 RAM 일시 보관 | 골프장 자동 매칭은 기기 내 처리(외부 전송 없음). **단, 사용자가 골프장 검색 시 카카오 지도 API(`dapi.kakao.com`)로 좌표(x/y) 전송 — 검색 결과 정렬 목적** | 01-SPEC.md:57-62, CLAUDE.md §PROJECT |
| HealthKit (걸음 수·칼로리·심박수·활동 시간) | 라운드 시작 시 (F8) | 기기 HealthKit (OS 관리) | 없음 — 기기 내 처리 전용 | 01-SPEC.md:116-119 |
| 스코어카드 이미지 (사용자가 PhotosPicker로 선택) | 가져오기·AI 분석 시 | 기기 → Google Gemini API (`generativelanguage.googleapis.com`) | **AI(Google Gemini)로 점수 추출 목적 전송. 추출 후 앱은 미보관(서버 보관은 Google 처리방침 따름)** | App-iOS Gemini 연동 |
| 광고 식별자 (IDFA, Device ID) | ATT 동의 시 광고 표시 시점 | 기기 (광고 SDK) | **AdMob(Google)로 전송 — 맞춤 광고 게재 및 광고 측정 목적. ATT 동의 시에만 수집** | App-iOS PrivacyInfo.xcprivacy |
| 동반자 별명 (실명·연락처 업로드 금지) | 라운드 시작 시 | 기기 SwiftData → Cloudflare KV (viewer 공유 시, 7일) | viewer 공유 시 KV 저장 | 01-SPEC.md:282 |
| 디바이스 식별자 (deviceToken, 익명 UUID) | 앱 최초 실행 시 | 기기 | viewer 생성 시 Cloudflare Worker로 전송 (Rate limit 카운터에만 사용) | 01-SPEC.md:670 |
| iCloud 계정 (CloudKit private DB) | 라운드 저장 시 (F7) | 사용자 본인 iCloud (Apple 관리) | 사용자 본인 계정 영역 — 외부 제3자 전송 아님 | 01-SPEC.md:111-114 |

**수집하지 않는 정보**: 회원 ID, 비밀번호, 실명, 이메일, 전화번호, 생년월일, 성별, 결제 정보 등은 수집하지 않습니다. 동반자 이름 필드에 실명·연락처·주민번호 등 개인식별정보를 입력해도 서버측 PII 마스킹 정책(33-SECURITY §7)에 의해 자동 마스킹 처리됩니다.

**광고 식별자(IDFA)**: 본 앱은 AdMob(Google) 광고 SDK를 사용하며, 사용자가 ATT(App Tracking Transparency) 프롬프트에서 추적을 허용한 경우에 한해 광고 식별자(IDFA)를 맞춤 광고 및 광고 측정 목적으로 수집·이용합니다. ATT 동의를 거부한 경우 비맞춤 광고만 게재됩니다.

**자동화된 개인정보 수집 장치**: 본 앱은 AdMob 광고 SDK를 통해 광고 식별자(IDFA)를 자동 수집할 수 있습니다(위 ATT 정책 적용). 그 외 쿠키·행동 추적 픽셀은 사용하지 않습니다. viewer 웹페이지의 세션 쿠키(`viewer_session`)는 PIN 인증 세션 유지 목적으로만 사용하며 15분 후 자동 만료됩니다. (33-SECURITY §5.4)

---

## 3. 수집·이용 목적

회사는 수집한 개인정보를 아래 목적으로만 이용합니다. 목적 범위를 초과하여 사용하지 않으며, 목적이 변경되는 경우 사전에 동의를 받겠습니다.

| 목적 | 관련 기능 | 처리 항목 |
|------|---------|---------|
| 자동 골프장 매칭 (골프장·서브코스 단위) | F1, F3 | 위치 정보 (기기 내) |
| 골프장 검색 결과 정렬 | 골프장 검색 | 위치 좌표 (카카오 지도 API 전송) |
| AI 스코어카드 인식 (점수 자동 추출) | 가져오기 / AI 분석 | 스코어카드 이미지 (Google Gemini 전송) |
| 광고 제공 (앱 운영 재원) | 보상형 광고(AdMob) | 광고 식별자(IDFA, ATT 동의 시) |
| 라운드 기록 저장 및 관리 | F2~F6 | 동반자 별명, 기기 내 SwiftData |
| 다른 디바이스 동기화 | F7 | iCloud (CloudKit private DB) |
| 라운드 스코어카드 viewer 링크 공유 | F9~F10 | 동반자 별명, 스코어, deviceToken |
| 워크아웃 메트릭 기록 및 Apple Health 연동 | F8 | HealthKit (기기 내 처리) |
| viewer 생성 요청 남용 방지 (Rate limiting) | viewer 공유 | deviceToken (익명 UUID) |

---

## 4. 보유 및 이용 기간

회사는 법령에 따른 보유 기간이 경과하거나 처리 목적이 달성된 경우 지체 없이 파기합니다. 사용자 관점의 보유 기간은 다음과 같습니다.

| 데이터 | 보유 기간 | 파기 방법 |
|--------|---------|---------|
| 스코어카드 (라운드 기록, SwiftData + CloudKit private DB) | **사용자가 앱에서 삭제할 때까지** | 앱 내 삭제 → CloudKit private DB 자동 회수 |
| AI 분석용 스코어카드 이미지 (Google Gemini 전송분) | 점수 추출 직후 **앱 미보관** | 추출 완료 시 앱은 즉시 폐기. Google 서버측 보관 정책은 Google 개인정보 처리방침에 따름 |
| viewer 메타데이터 (동반자 별명, 스코어, Cloudflare KV) | viewer 생성 후 **7일** 자동 삭제 | KV TTL 만료 자동 파기 또는 사용자 "공유 취소" 즉시 파기 |
| PIN 오답 잠금 카운터 | **1시간** (5회 오답 시) | TTL 만료 자동 파기 |
| Rate limit 카운터 | **70초** (Sliding Window) | TTL 만료 자동 파기 |
| 세션 쿠키 (viewer_session) | **15분** | 브라우저 만료 또는 탭 종료 |
| Idempotency-Key | **24시간** | KV TTL 만료 자동 파기 |

위치 정보는 기기 RAM에 일시 보관되며 앱 종료 시 즉시 소멸됩니다.

**법령에 따른 보유 기간 예외**: 관계 법령에 별도 보유 기간이 규정된 경우 해당 기간 동안 보유합니다. 현재 라운드온 서비스에 적용되는 법령상 의무 보유 항목은 없습니다.

상세 TTL 표는 `33-SECURITY §9` 참조. 사용자의 명시 삭제 절차는 §6.2 참조.

---

## 5. 제3자 제공 및 처리 위탁

### 5.1 제3자 제공

**없음.** 라운드온은 수집한 개인정보를 정보주체의 동의 없이 제3자에게 제공하지 않습니다. 수사기관 등 법령에 의한 요청이 있는 경우 법적 의무에 따라 최소한의 정보를 제공할 수 있으며, 이 경우 사용자에게 사전 또는 사후 통지합니다.

### 5.2 처리 위탁

회사는 아래 업무를 각 수탁사에 위탁합니다. 위탁 시 개인정보 보호 관련 법규 준수, 개인정보 안전 관리, 목적 외 사용 금지 등을 준수합니다.

| 수탁사 | 위탁 업무 | 처리 데이터 | 보관 기간 | 소재국 |
|-------|---------|----------|---------|--------|
| Cloudflare Inc. | viewer 호스팅 (Cloudflare Workers), 메타데이터 저장 (KV) | 동반자 별명, 스코어, deviceToken (익명 UUID), PIN(bcrypt) | viewer 생성 후 7일 자동 삭제 | 미국 (전 세계 CDN 분산) |
| Google LLC | AdMob 광고 게재 / Gemini 스코어카드 OCR (점수 추출) | 광고 식별자(IDFA, ATT 동의 시), 스코어카드 이미지 | Google 처리방침에 따름 | 미국 |
| Kakao Corp. (카카오) | 골프장 검색 좌표 처리 (검색 결과 정렬) | 위치 좌표(x/y) | Kakao 처리방침에 따름 | 대한민국 |

- Cloudflare 개인정보 처리방침: https://www.cloudflare.com/ko-kr/privacypolicy/
- Google 개인정보 처리방침: https://policies.google.com/privacy
- Kakao 개인정보 처리방침: https://www.kakao.com/policy/privacy

**국외 이전**: Cloudflare Inc. 및 Google LLC는 미국 법인입니다. 사용자의 viewer 데이터는 Cloudflare 글로벌 네트워크에서, 광고 식별자 및 스코어카드 이미지는 Google 서버에서 처리될 수 있습니다. 이에 따른 국외 이전은 PIPA §28조의2에 따라 본 방침에 고지합니다. Cloudflare는 EU-U.S. Data Privacy Framework 인증을 유지하고 있습니다.

### 5.3 기기 내 처리 및 사용자 본인 계정 저장소

아래 항목은 PIPA §26의 "처리 위탁"에 해당하지 않습니다.

- **Apple HealthKit**: 기기 내 OS API로 처리되며 외부로 전송되지 않습니다. 회사는 HealthKit 데이터에 접근하지 않습니다. (위탁 아님)
- **Apple iCloud (CloudKit private DB)**: 사용자 본인의 iCloud 계정 저장 영역입니다. Apple의 표준 엔드투엔드 암호화가 적용됩니다. 회사는 사용자의 iCloud 데이터를 직접 처리하지 않습니다. Apple의 개인정보 처리방침 적용: https://www.apple.com/legal/privacy/ko/

---

## 6. 정보주체의 권리 및 파기

### 6.1 사용자 권리 (PIPA §35~37)

정보주체는 언제든지 아래 권리를 행사할 수 있습니다.

| 권리 | 행사 방법 |
|------|---------|
| 열람 | 앱 내 라운드 목록에서 직접 확인 |
| 정정 | 앱 내 라운드 편집 기능 사용 |
| 삭제 (라운드 기록) | 앱 내 삭제 → CloudKit private DB 자동 회수 |
| 삭제 (viewer 공유 데이터) | 앱 내 "공유 취소" → `DELETE /api/share/{shortId}` 즉시 호출 → KV 즉시 파기 (204 응답, 30-API §9.6) |
| 처리 정지 | 앱 삭제 또는 각 권한 거부 (위치·HealthKit·사진 접근·ATT 추적 등 개별 거부 가능) |
| 권리 행사 위탁 | 법정대리인이 미성년자 대리 행사 가능 |

권리 행사에 대한 회사의 응답: 접수 후 10일 이내 처리. 거부 시 사유를 서면으로 통지.

**권리 행사 방법**: 위 행사 방법 외에 아래 연락처로 서면 요청도 가능합니다.

- 이메일: `zerolive7@gmail.com`
- 이메일 요청 시 건명에 "개인정보 처리 [열람/정정/삭제/처리정지] 요청"을 포함하십시오.

**미성년자 대리 행사**: 만 14세 미만 정보주체의 법정대리인은 해당 아동의 개인정보에 대해 열람·정정·삭제·처리 정지를 요청할 수 있습니다.

### 6.2 파기 절차

**자동 파기**: 보유 기간 TTL 만료 시 시스템이 자동 파기합니다. (§4 TTL 표 참조)

**사용자 명시 삭제**: 삭제 요청 즉시 회수합니다.

- viewer 삭제: `DELETE /api/share/{shortId}` 수신 즉시 KV 메타데이터 삭제. 204 반환. (33-SECURITY §9.2)
- 라운드 기록 삭제: 앱 내 삭제 → SwiftData 즉시 파기 → CloudKit private DB 동기화로 자동 회수.

**디바이스 분실 시**: iCloud 계정을 통해 다른 디바이스의 앱에서 라운드를 삭제할 수 있습니다.

**파기 방법**: 전자적 파일은 복구 불가능한 방법으로 영구 삭제합니다.

---

## 7. 안전성 확보 조치

회사는 PIPA §29 및 개인정보의 안전성 확보조치 기준(개인정보보호위원회 고시)에 따라 다음 기술적·관리적·물리적 조치를 시행합니다. 상세 구현은 `33-SECURITY.md`에 정의됩니다.

### 7.1 기술적 조치

- **전송 구간 암호화**: HTTPS 전 구간 강제 적용. Cloudflare 자동 적용 (01-SPEC.md:281)
- **HSTS**: `Strict-Transport-Security: max-age=31536000; includeSubDomains; preload` (33-SECURITY §8.2)
- **PIN 암호화 저장**: bcrypt cost 12 해싱 적용 (33-SECURITY §4)
- **PII 패턴 서버측 마스킹**: 휴대전화·이메일·주민번호·신용카드 4종 정규식 매칭 시 마스킹 후 저장. 평문 저장하지 않음 (33-SECURITY §7)
- **Rate limiting**: deviceToken 단위 1분 5건 viewer 생성 제한 (33-SECURITY §6)
- **세션 쿠키 보호**: HttpOnly + Secure + SameSite=Strict 속성 적용 (33-SECURITY §5.4)
- **iOS Keychain 저장**: editToken은 기기 iOS Keychain에 저장합니다. (33-SECURITY §3.4)
- **보안 헤더**: `X-Content-Type-Options: nosniff`, `Referrer-Policy: no-referrer`, `Permissions-Policy: geolocation=(), camera=()` (33-SECURITY §8.3)

### 7.2 관리적 조치

- 개인정보 접근 권한 최소화 (Cloudflare API 토큰 분리 관리)
- 로그 마스킹: PIN 평문, editToken 평문, IP 원본을 Workers 로그에 기록하지 않음 (33-SECURITY §9.3)
- 본 방침 및 내부 지침 정기 검토

### 7.3 물리적 조치

- Cloudflare 데이터센터 물리 보안 적용 (Cloudflare Trust Center 참조)
- 앱 데이터는 사용자 기기 내 iOS 보안 격리 영역에 저장

### 7.4 보안 사고 대응

개인정보 침해 사고 발생 시 다음 절차를 따릅니다.

1. **탐지 즉시**: 침해 범위 확인 및 서비스 접근 차단
2. **72시간 이내**: 관할 당국(개인정보보호위원회) 신고 (PIPA §34)
3. **정보주체 통지**: 침해 사실, 유출된 항목, 조치 사항을 지체 없이 통지
4. **재발 방지**: 원인 분석 후 보안 강화 조치 시행

viewer 서비스 특성상 7일 TTL 자동 파기로 침해 가능 데이터 범위가 제한됩니다.

---

## 8. App Store Privacy Nutrition Label

App Store Connect 개인정보 보호 관행 입력 양식과 1:1 매핑됩니다.

| 카테고리 | 데이터 | 추적 사용 | 사용자 연결 | 사용 목적 |
|---------|------|---------|-----------|---------|
| Location | Precise Location | No | Not Linked | App Functionality (골프장 자동 매칭, 검색 결과 정렬) |
| Health & Fitness | Fitness (걸음 수·칼로리·심박수) | No | Not Linked | App Functionality (워크아웃 메트릭, 기기 내 처리) |
| User Content | Photos (스코어카드 이미지, 사용자 선택) | No | Not Linked | App Functionality (AI 점수 추출 — Google Gemini 전송) |
| Identifiers | Device ID (IDFA) | **Yes** | Not Linked | Third-Party Advertising (AdMob 맞춤 광고), Developer's Advertising or Marketing |
| Identifiers | Device ID (deviceToken, 익명 UUID) | No | Not Linked | App Functionality (Rate limiting) |

**Data Used to Track You**: Device ID (IDFA) — AdMob 맞춤 광고. ATT 동의 시에만 사용.

**Data Linked to You**: None (deviceToken·IDFA 모두 실명·연락처와 연결되지 않음)

**Data Not Linked to You**: Location, Health & Fitness, Photos, Device ID (IDFA / deviceToken)

위치는 Precise Location을 사용하며, 골프장 검색 시 카카오 지도 API로 좌표를 전송하므로 App Store Connect에서 "Collected — Precise Location, App Functionality, Not Linked, Not used for tracking"으로 신고합니다. (53-PERMISSIONS §8)

**iOS 14+ Approximate Location 대응**: 사용자가 Approximate Location(대략적 위치)을 선택한 경우 골프장 반경 3km 매칭 정확도가 저하될 수 있습니다. 이 경우 앱은 수동 골프장 검색 화면으로 안내합니다. 자동 매칭 단계의 위치 데이터는 기기 외부로 전송하지 않으며, 외부 전송은 사용자가 직접 골프장 검색을 실행한 경우(카카오 API, §2·§5.2)에 한합니다. (53-PERMISSIONS §2)

---

## 9. iOS Privacy Manifest (`PrivacyInfo.xcprivacy`)

본 앱은 iOS 17+ 필수 제출 요건인 Privacy Manifest를 다음 기준으로 작성합니다. (53-PERMISSIONS §8)

### 9.1 추적 여부 선언

```xml
<key>NSPrivacyTracking</key>
<true/>
<key>NSPrivacyTrackingDomains</key>
<array>
    <string>googleadservices.com</string>
    <string>googlesyndication.com</string>
    <string>doubleclick.net</string>
    <string>admob.googleapis.com</string>
</array>
```

본 앱은 AdMob 광고를 위해 ATT 동의 하에 사용자를 추적하며, 위 4개 추적 도메인을 선언합니다. (`PrivacyInfo.xcprivacy`와 일치)

### 9.2 Required Reason API 1종 (확정)

iOS 개인정보 보호 프레임워크가 요구하는 Required Reason API 접근 근거는 아래 1종입니다. (실제 `PrivacyInfo.xcprivacy`와 1:1 일치)

| API 카테고리 | Reason 코드 | 사용 목적 |
|-----------|----------|---------|
| `NSPrivacyAccessedAPICategoryUserDefaults` | CA92.1 | 사용자 설정 저장 (앱 테마, 알림 등 환경 설정. 앱 내 사용 통계 목적 사용 없음) |

SDK 단위 Privacy Manifest는 §9.5 참조.

### 9.3 NSPrivacyCollectedDataTypes

수집 데이터 유형 선언은 §8 Privacy Nutrition Label 표와 동일하게 선언합니다. 구체적 XML 작성은 Xcode 구현 단계 책임입니다.

### 9.4 NSPrivacyAccessedAPITypes 전체 선언 (실제 적용본)

아래는 실제 `PrivacyInfo.xcprivacy`에 선언된 항목입니다. (코드 미사용 API는 선언하지 않음 — UserDefaults 1종만)

```xml
<key>NSPrivacyAccessedAPITypes</key>
<array>
    <dict>
        <key>NSPrivacyAccessedAPIType</key>
        <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
        <key>NSPrivacyAccessedAPITypeReasons</key>
        <array>
            <string>CA92.1</string>
        </array>
    </dict>
</array>
```

### 9.5 SDK 단위 Privacy Manifest

본 앱은 Google Mobile Ads SDK(AdMob)를 Swift Package Manager로 통합합니다. `GoogleMobileAds`는 SDK 패키지에 자체 Privacy Manifest(`PrivacyInfo.xcprivacy`)를 포함하므로, 앱은 별도로 AdMob 관련 Required Reason API를 중복 선언하지 않습니다. 앱 빌드 시 Apple이 각 SDK의 manifest를 집계(aggregate)하여 App Store Connect Privacy Report를 생성합니다.

---

## 10. 아동의 개인정보 보호

회사는 다음 원칙을 준수합니다.

- 만 14세 미만 아동의 개인정보를 의도적으로 수집하지 않습니다.
- 아동이 개인정보를 제공한 사실이 확인될 경우 즉시 삭제합니다.
- App Store Connect Age Rating: 본 앱은 AdMob 광고(제3자 광고)를 포함하므로 Apple의 광고 관련 등급 정책에 따라 **17+** 등급이 적용될 수 있습니다. 아동 타깃 앱(`Made for Kids`) 카테고리는 미해당.
- COPPA(미국 아동 온라인 개인정보 보호법) 준수 여부는 글로벌 출시 시 별도 검토합니다.

---

## 11. 개인정보 보호책임자 및 권익침해 구제

### 11.1 개인정보 보호책임자

정보주체는 PIPA §38에 따라 개인정보 처리에 관한 불만 처리, 피해 구제 등을 위해 아래 책임자에게 문의하실 수 있습니다.

- **성명**: `이용섭`
- **연락처**: `zerolive7@gmail.com`
- **주소**: `서울특별시 광진구 광나루로 44길 39`

문의 접수 후 10일 이내 답변 드리겠습니다.

### 11.2 권익침해 구제방법

아래 기관에 개인정보 침해 신고, 상담, 분쟁 조정을 신청하실 수 있습니다.

| 기관 | 연락처 | 웹사이트 |
|------|------|---------|
| 개인정보분쟁조정위원회 | 1833-6972 | www.kopico.go.kr |
| KISA 개인정보침해신고센터 | 118 | privacy.kisa.or.kr |
| 대검찰청 | 1301 | www.spo.go.kr |
| 경찰청 사이버수사국 | 182 | cyberbureau.police.go.kr / ecrm.police.go.kr |

> 위 연락처는 KISA `privacy.go.kr` 표준 양식을 기준으로 작성되었으며, 출시 시점에 최신 정보로 재확인합니다.

---

## 12. 방침의 변경

본 방침이 변경되는 경우 다음 절차를 따릅니다.

- **사전 공지**: 변경 내용 및 시행일을 시행 **7일 전** 앱 내 알림 및 viewer 사이트(`golf.zerolive.co.kr`)에 공지합니다. 중요 변경(수집 항목 추가, 제3자 제공 신규 발생 등)의 경우 30일 전 공지하며 별도 동의를 받습니다.
- **이전 버전 보관**: 본 방침의 이전 버전은 본 specs 시리즈의 git 이력(commit history)으로 보관됩니다.
- **앱 내 접근 경로**: 앱 설정(Settings) → 개인정보 처리방침 메뉴에서 현행 버전을 항상 확인할 수 있습니다.
- **본 방침 시행일**: `2026-06-05`

중요 변경의 예시: 새로운 개인정보 수집 항목 추가, 수집 목적 변경, 신규 제3자 제공 또는 처리 위탁 발생, 보유 기간 연장, 개인정보 처리방침 담당자 변경.

---

## 부록: 문서 관리

| 항목 | 내용 |
|------|------|
| 문서 식별 | `ref-docs/specs/50-PRIVACY_POLICY.md` — 라운드온 개인정보 처리방침 정책 본문 |
| 법적 검토 | App Store 제출 전 변호사 검토 권장. 본 문서는 정책 방향 및 placeholder 제공이며 법적 효력의 보증이 아님 |
| 변경 이력 | `git log ref-docs/specs/50-PRIVACY_POLICY.md` 참조 |
| 준거법 | `대한민국법` (예: 대한민국법) — 한국법 단일 가정. 영어권 출시 시 GDPR(유럽)/CCPA(미국 캘리포니아) 추가 검토 필요 (CLAUDE.md §PROJECT) |
| 영어판 | 글로벌 출시 시 별도 작성. 앱 이름 "Round-On"의 영어권 부정 함의 해소 후 병행 작성 (CLAUDE.md §PROJECT) |
| 관련 문서 | `33-SECURITY.md` (기술 보안), `53-PERMISSIONS.md` (iOS 권한), `21-DATA_MODEL.md` (데이터 모델), `30-API_SPEC.md` (API 명세) |
| App Store URL | [SPEC-UNDEFINED] — 출시 후 App Store 앱 링크 기재 |
| viewer URL | https://golf.zerolive.co.kr (7일 만료 라운드 viewer, CLAUDE.md §PROJECT) |

---

**ODbL 라이선스 표기**: 본 앱에서 사용하는 한국 골프장 데이터(v3 기반)는 OpenStreetMap(OSM) ODbL 라이선스 데이터를 기반으로 합니다. 이 데이터는 골프장 매칭(F1)에 사용합니다. 라이선스 정보(`© OpenStreetMap contributors, ODbL 1.0`)는 앱 내 설정 → 정보 화면(SettingsView)에 이미 표기되어 있습니다. (CLAUDE.md §PROJECT)

---

*최종 업데이트: 2026-06-05*

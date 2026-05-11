# 50 — 개인정보 처리방침 (Privacy Policy)

> **작성일**: 2026-05-11
> **버전**: v4 기반
> **상태**: 정책 본문 (Public) — App Store 제출 전 법적 검토 권장
> **출처 명세서**: [기능 명세서 v4](../golf-scorecard-app-spec_3.md) §9 (spec_3.md:655-672), §3.4 (spec_3.md:274-284)
> **관련 문서**: `33-SECURITY.md`, `53-PERMISSIONS.md`, `21-DATA_MODEL.md`, `30-API_SPEC.md`

---

> **[추후 확정 항목 일람 — App Store 제출 직전 일괄 치환]**
>
> 본문에 placeholder 토큰으로 표기된 항목입니다. 실제 제출 전 아래 6건을 확정하여 `sed` 일괄 치환하십시오.
>
> 1. `{사업자명}` — 사업자명 및 대표자명 (zerolive.co.kr 도메인 보유자와 일치 확인 필요)
> 2. `{보호책임자}` — 개인정보 보호책임자 (사업자 본인 또는 별도 지정)
> 3. `{이메일}` — 연락 이메일 (예: `privacy@golf.zerolive.co.kr` 또는 기존 이메일)
> 4. `{사업장주소}` — 공개 가능한 사업장 주소
> 5. `{시행일}` — 본 방침 시행일 (앱 출시일 기준)
> 6. `{관할법}` — 법적 관할 (한국법 단일 가정. 영어권 출시 시 GDPR/CCPA 추가 검토 필요)

---

## 1. 총칙

`{사업자명}` (이하 "회사")이 운영하는 **라운드온(Round-On)** (이하 "본 앱")은 「개인정보 보호법」(이하 "PIPA") 제30조에 따라 정보주체의 개인정보를 보호하고 이와 관련한 고충을 신속하고 원활하게 처리할 수 있도록 다음과 같이 개인정보 처리방침을 수립·공개합니다.

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
- **위치·HealthKit 기기 외부 전송 금지**: 골프장 매칭 및 워크아웃 기록에 사용하는 위치 정보와 건강 데이터는 기기 외부로 절대 전송하지 않습니다. (CLAUDE.md §PROJECT)

### 1.4 법적 검토 권장

본 문서는 정책 방향 및 placeholder를 제공하는 초안입니다. App Store 제출 전 법률 전문가의 검토를 권장합니다. 본 문서는 법적 책임을 지지 않습니다.

---

## 2. 수집하는 개인정보 항목

회사는 아래 6종의 정보를 처리합니다. 별도 회원가입, 이름, 연락처, 생년월일은 수집하지 않습니다.

| 항목 | 수집 시점 | 저장 위치 | 외부 전송 | 출처 |
|------|---------|---------|---------|------|
| 위치 정보 (GPS, Precise) | 앱 실행 시 골프장 자동 매칭 (F1) | 기기 RAM 일시 보관 | 없음 — 기기 외부로 절대 전송하지 않음 | spec_3.md:57-62, CLAUDE.md §PROJECT |
| HealthKit (걸음 수·칼로리·심박수·활동 시간) | 라운드 시작 시 (F8) | 기기 HealthKit (OS 관리) | 없음 — 기기 내 처리 전용 | spec_3.md:116-119 |
| 사진 (사용자가 선택 또는 촬영) | 사진 첨부 시 (F9) | 기기 → Cloudflare R2 (viewer 공유 시, 7일) | viewer 공유 시 R2 업로드 (EXIF GPS strip 후 전송) | spec_3.md:134-138 |
| 동반자 별명 (실명·연락처 업로드 금지) | 라운드 시작 시 | 기기 SwiftData → Cloudflare KV (viewer 공유 시, 7일) | viewer 공유 시 KV 저장 | spec_3.md:282 |
| 디바이스 식별자 (deviceToken, 익명 UUID) | 앱 최초 실행 시 | 기기 | viewer 생성 시 Cloudflare Worker로 전송 (Rate limit 카운터에만 사용) | spec_3.md:670 |
| iCloud 계정 (CloudKit private DB) | 라운드 저장 시 (F7) | 사용자 본인 iCloud (Apple 관리) | 사용자 본인 계정 영역 — 외부 제3자 전송 아님 | spec_3.md:111-114 |

**수집하지 않는 정보**: 회원 ID, 비밀번호, 실명, 이메일, 전화번호, 생년월일, 성별, 결제 정보, 광고 식별자(IDFA/GAID) 등은 수집하지 않습니다. 동반자 이름 필드에 실명·연락처·주민번호 등 개인식별정보를 입력해도 서버측 PII 마스킹 정책(33-SECURITY §7)에 의해 자동 마스킹 처리됩니다.

**자동화된 개인정보 수집 장치**: 본 앱은 쿠키, 행동 추적 픽셀, 광고 SDK 등 자동화된 정보 수집 장치를 사용하지 않습니다. viewer 웹페이지의 세션 쿠키(`viewer_session`)는 PIN 인증 세션 유지 목적으로만 사용하며 15분 후 자동 만료됩니다. (33-SECURITY §5.4)

---

## 3. 수집·이용 목적

회사는 수집한 개인정보를 아래 목적으로만 이용합니다. 목적 범위를 초과하여 사용하지 않으며, 목적이 변경되는 경우 사전에 동의를 받겠습니다.

| 목적 | 관련 기능 | 처리 항목 |
|------|---------|---------|
| 자동 골프장 매칭 및 홀 감지 | F1, F3 | 위치 정보 |
| 라운드 기록 저장 및 관리 | F2~F6 | 동반자 별명, 기기 내 SwiftData |
| 다른 디바이스 동기화 | F7 | iCloud (CloudKit private DB) |
| 라운드 스코어카드 viewer 링크 공유 | F9~F10 | 동반자 별명, 사진, deviceToken |
| 워크아웃 메트릭 기록 및 Apple Health 연동 | F8 | HealthKit (기기 내 처리) |
| viewer 생성 요청 남용 방지 (Rate limiting) | viewer 공유 | deviceToken (익명 UUID) |

---

## 4. 보유 및 이용 기간

회사는 법령에 따른 보유 기간이 경과하거나 처리 목적이 달성된 경우 지체 없이 파기합니다. 사용자 관점의 보유 기간은 다음과 같습니다.

| 데이터 | 보유 기간 | 파기 방법 |
|--------|---------|---------|
| 스코어카드 (라운드 기록, SwiftData + CloudKit private DB) | **사용자가 앱에서 삭제할 때까지** | 앱 내 삭제 → CloudKit private DB 자동 회수 |
| viewer 사진 (Cloudflare R2) | viewer 생성 후 **7일** 자동 삭제 | R2 TTL 만료 자동 파기 또는 사용자 "공유 취소" 즉시 파기 |
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

### 5.2 처리 위탁 (Cloudflare만 해당)

회사는 아래 업무를 Cloudflare Inc.에 위탁합니다. 위탁 계약 시 개인정보 보호 관련 법규 준수, 개인정보 안전 관리, 목적 외 사용 금지 등을 계약서에 명시하고 있습니다.

| 수탁사 | 위탁 업무 | 처리 데이터 | 보관 기간 | 소재국 |
|-------|---------|----------|---------|--------|
| Cloudflare Inc. | viewer 호스팅 (Cloudflare Workers), 메타데이터 저장 (KV), 사진 저장 (R2) | 동반자 별명, 사진, 스코어, deviceToken (익명 UUID) | viewer 생성 후 7일 자동 삭제 | 미국 (전 세계 CDN 분산) |

Cloudflare 개인정보 처리방침: https://www.cloudflare.com/ko-kr/privacypolicy/

**국외 이전**: Cloudflare Inc.는 미국 법인으로 전 세계 CDN을 운영합니다. 사용자의 viewer 데이터는 Cloudflare 글로벌 네트워크에서 처리될 수 있습니다. 이에 따른 국외 이전은 PIPA §28조의2에 따라 본 방침에 고지합니다. Cloudflare는 EU-U.S. Data Privacy Framework 인증을 유지하고 있습니다.

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
| 삭제 (viewer 공유 데이터) | 앱 내 "공유 취소" → `DELETE /api/share/{shortId}` 즉시 호출 → KV + R2 즉시 파기 (204 응답, 30-API §9.6) |
| 처리 정지 | 앱 삭제 또는 각 권한 거부 (위치·HealthKit·사진 등 개별 거부 가능) |
| 권리 행사 위탁 | 법정대리인이 미성년자 대리 행사 가능 |

권리 행사에 대한 회사의 응답: 접수 후 10일 이내 처리. 거부 시 사유를 서면으로 통지.

**권리 행사 방법**: 위 행사 방법 외에 아래 연락처로 서면 요청도 가능합니다.

- 이메일: `{이메일}` [추후 확정]
- 이메일 요청 시 건명에 "개인정보 처리 [열람/정정/삭제/처리정지] 요청"을 포함하십시오.

**미성년자 대리 행사**: 만 14세 미만 정보주체의 법정대리인은 해당 아동의 개인정보에 대해 열람·정정·삭제·처리 정지를 요청할 수 있습니다.

### 6.2 파기 절차

**자동 파기**: 보유 기간 TTL 만료 시 시스템이 자동 파기합니다. (§4 TTL 표 참조)

**사용자 명시 삭제**: 삭제 요청 즉시 회수합니다.

- viewer 삭제: `DELETE /api/share/{shortId}` 수신 즉시 KV 메타 + R2 사진 동시 삭제. 204 반환. (33-SECURITY §9.2)
- 라운드 기록 삭제: 앱 내 삭제 → SwiftData 즉시 파기 → CloudKit private DB 동기화로 자동 회수.

**디바이스 분실 시**: iCloud 계정을 통해 다른 디바이스의 앱에서 라운드를 삭제할 수 있습니다.

**파기 방법**: 전자적 파일은 복구 불가능한 방법으로 영구 삭제합니다.

---

## 7. 안전성 확보 조치

회사는 PIPA §29 및 개인정보의 안전성 확보조치 기준(개인정보보호위원회 고시)에 따라 다음 기술적·관리적·물리적 조치를 시행합니다. 상세 구현은 `33-SECURITY.md`에 정의됩니다.

### 7.1 기술적 조치

- **전송 구간 암호화**: HTTPS 전 구간 강제 적용. Cloudflare 자동 적용 (spec_3.md:281)
- **HSTS**: `Strict-Transport-Security: max-age=31536000; includeSubDomains; preload` (33-SECURITY §8.2)
- **PIN 암호화 저장**: bcrypt cost 12 해싱 적용 (33-SECURITY §4)
- **PII 패턴 서버측 마스킹**: 휴대전화·이메일·주민번호·신용카드 4종 정규식 매칭 시 마스킹 후 저장. 평문 저장하지 않음 (33-SECURITY §7)
- **Rate limiting**: deviceToken 단위 1분 5건 viewer 생성 제한 (33-SECURITY §6)
- **세션 쿠키 보호**: HttpOnly + Secure + SameSite=Strict 속성 적용 (33-SECURITY §5.4)
- **사진 EXIF GPS 제거**: viewer 공유를 위해 Cloudflare R2에 업로드하기 전, **iOS 클라이언트가** 사진의 EXIF GPS 메타데이터를 완전히 제거한 후 전송합니다. 촬영 위치 정보는 기기 외부로 절대 전송되지 않습니다. (§1.3 "기기 외부 GPS 전송 금지" 원칙 정합)
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
| Location | Precise Location | No | Not Linked | App Functionality (골프장 자동 매칭, 홀 감지) |
| Health & Fitness | Fitness (걸음 수·칼로리·심박수) | No | Not Linked | App Functionality (워크아웃 메트릭, 기기 내 처리) |
| User Content | Photos (사용자 선택 사진) | No | Not Linked | App Functionality (viewer 공유 사진 첨부) |
| Identifiers | Device ID (익명 UUID) | No | Not Linked | App Functionality (Rate limiting) |

**Data Used to Track You**: None

**Data Linked to You**: None (deviceToken은 익명 UUID, 실명·연락처 수집 없음)

**Data Not Linked to You**: Location, Health & Fitness, Photos, Device ID

위치는 Precise Location을 사용하나 기기 외부로 전송하지 않으므로 App Store Connect에서 "Not Collected (위치 전송 없음)"로 신고합니다. (53-PERMISSIONS §8)

**iOS 14+ Approximate Location 대응**: 사용자가 Approximate Location(대략적 위치)을 선택한 경우 골프장 반경 3km 매칭 정확도가 저하될 수 있습니다. 이 경우 앱은 수동 골프장 검색 화면으로 안내합니다. Approximate Location 선택 시에도 위치 데이터는 기기 외부로 전송하지 않습니다. (53-PERMISSIONS §2)

---

## 9. iOS Privacy Manifest (`PrivacyInfo.xcprivacy`)

본 앱은 iOS 17+ 필수 제출 요건인 Privacy Manifest를 다음 기준으로 작성합니다. (53-PERMISSIONS §8)

### 9.1 추적 여부 선언

```xml
<key>NSPrivacyTracking</key>
<false/>
<key>NSPrivacyTrackingDomains</key>
<array/>
```

본 앱은 사용자를 추적하지 않으며, 추적 도메인이 없습니다.

### 9.2 Required Reason API 4종 (확정)

iOS 개인정보 보호 프레임워크가 요구하는 Required Reason API 접근 근거를 아래와 같이 확정합니다.

| API 카테고리 | Reason 코드 | 사용 목적 |
|-----------|----------|---------|
| `NSPrivacyAccessedAPICategoryUserDefaults` | CA92.1 | 사용자 설정 저장 (앱 테마, 알림 등 환경 설정. 앱 내 사용 통계 목적 사용 없음) |
| `NSPrivacyAccessedAPICategoryFileTimestamp` | C617.1 | SwiftData 영속 저장 시 파일 타임스탬프 접근 |
| `NSPrivacyAccessedAPICategorySystemBootTime` | 35F9.1 | HealthKit 워크아웃 세션 시간 검증 |
| `NSPrivacyAccessedAPICategoryDiskSpace` | E174.1 | Cloudflare R2 사진 업로드 전 기기 가용 용량 확인 |

SDK 단위 Privacy Manifest (사용 서드파티 SDK 목록)는 [SPEC-UNDEFINED] — 사용 SDK 확정 시 보강합니다.

### 9.3 NSPrivacyCollectedDataTypes

수집 데이터 유형 선언은 §8 Privacy Nutrition Label 표와 동일하게 선언합니다. 구체적 XML 작성은 Xcode 구현 단계 책임입니다.

### 9.4 NSPrivacyAccessedAPITypes 전체 선언 예시

아래는 구현 단계에서 `PrivacyInfo.xcprivacy`에 추가할 항목의 참조 예시입니다.

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
    <dict>
        <key>NSPrivacyAccessedAPIType</key>
        <string>NSPrivacyAccessedAPICategoryFileTimestamp</string>
        <key>NSPrivacyAccessedAPITypeReasons</key>
        <array>
            <string>C617.1</string>
        </array>
    </dict>
    <dict>
        <key>NSPrivacyAccessedAPIType</key>
        <string>NSPrivacyAccessedAPICategorySystemBootTime</string>
        <key>NSPrivacyAccessedAPITypeReasons</key>
        <array>
            <string>35F9.1</string>
        </array>
    </dict>
    <dict>
        <key>NSPrivacyAccessedAPIType</key>
        <string>NSPrivacyAccessedAPICategoryDiskSpace</string>
        <key>NSPrivacyAccessedAPITypeReasons</key>
        <array>
            <string>E174.1</string>
        </array>
    </dict>
</array>
```

SDK 단위 Privacy Manifest (서드파티 SDK 포함 목록)는 [SPEC-UNDEFINED] — 사용 SDK 확정 후 위 배열에 추가합니다.

---

## 10. 아동의 개인정보 보호

회사는 다음 원칙을 준수합니다.

- 만 14세 미만 아동의 개인정보를 의도적으로 수집하지 않습니다.
- 아동이 개인정보를 제공한 사실이 확인될 경우 즉시 삭제합니다.
- App Store Connect Age Rating: 골프 카운터 앱 특성상 "4+" 또는 "9+" 등급 적용 예정. 아동 타깃 앱(`Made for Kids`) 카테고리는 미해당.
- COPPA(미국 아동 온라인 개인정보 보호법) 준수 여부는 글로벌 출시 시 별도 검토합니다.

---

## 11. 개인정보 보호책임자 및 권익침해 구제

### 11.1 개인정보 보호책임자

정보주체는 PIPA §38에 따라 개인정보 처리에 관한 불만 처리, 피해 구제 등을 위해 아래 책임자에게 문의하실 수 있습니다.

- **성명**: `{보호책임자}` [추후 확정]
- **연락처**: `{이메일}` [추후 확정]
- **주소**: `{사업장주소}` [추후 확정]

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
- **본 방침 시행일**: `{시행일}` [추후 확정]

중요 변경의 예시: 새로운 개인정보 수집 항목 추가, 수집 목적 변경, 신규 제3자 제공 또는 처리 위탁 발생, 보유 기간 연장, 개인정보 처리방침 담당자 변경.

---

## 부록: 문서 관리

| 항목 | 내용 |
|------|------|
| 문서 식별 | `Ref-docs/specs/50-PRIVACY_POLICY.md` — 라운드온 개인정보 처리방침 정책 본문 |
| 법적 검토 | App Store 제출 전 변호사 검토 권장. 본 문서는 정책 방향 및 placeholder 제공이며 법적 효력의 보증이 아님 |
| 변경 이력 | `git log Ref-docs/specs/50-PRIVACY_POLICY.md` 참조 |
| 준거법 | `{관할법}` (예: 대한민국법) — 한국법 단일 가정. 영어권 출시 시 GDPR(유럽)/CCPA(미국 캘리포니아) 추가 검토 필요 (CLAUDE.md §PROJECT) |
| 영어판 | 글로벌 출시 시 별도 작성. 앱 이름 "Round-On"의 영어권 부정 함의 해소 후 병행 작성 (CLAUDE.md §PROJECT) |
| 관련 문서 | `33-SECURITY.md` (기술 보안), `53-PERMISSIONS.md` (iOS 권한), `21-DATA_MODEL.md` (데이터 모델), `30-API_SPEC.md` (API 명세) |
| App Store URL | [SPEC-UNDEFINED] — 출시 후 App Store 앱 링크 기재 |
| viewer URL | https://golf.zerolive.co.kr (7일 만료 라운드 viewer, CLAUDE.md §PROJECT) |

---

**ODbL 라이선스 표기**: 본 앱에서 사용하는 한국 골프장 데이터(546개)는 OpenStreetMap(OSM) ODbL 라이선스 데이터를 기반으로 합니다. 이 데이터는 골프장 매칭(F1)에만 사용하며, 위치 정보와 결합하여 외부로 전송하지 않습니다. 라이선스 정보는 앱 내 설정 → 정보에 표기됩니다. (CLAUDE.md §PROJECT)

---

*최종 업데이트: 2026-05-11*

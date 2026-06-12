# 기획 검토 보고서 — 라운드온 킬러 피처 발굴

- **검토일**: 2026-05-28
- **검토 대상**: 라운드온(Round-On) iPhone+Watch 골프 스코어 카운터 앱의 킬러 피처 발굴 (1인 개발 + 마케팅 0 예산 + 점진적 확대 OK)
- **종합 판정**: ✅ **진행 가능** (다수결 3/3, 조건부 2건 포함)

---

## 1. 요약

**'라운드 카드 (Round Card)' — 라운드 종료 직후 자동 생성되는 인스타·카톡 친화 시그니처 이미지 카드를 킬러 피처로 1순위 권고.** Service/Business 두 페르소나가 독립적으로 동일한 결론에 도달했고, Tech는 이를 가능하게 하는 인프라(Live Activity + 데이터 자동 수집)를 1순위로 제안 — 시너지가 명확.

**핵심 근거 3줄**
- Service/Business가 독립적으로 '라운드 카드'를 1순위로 지목 (Strava 14B kudos + Spotify Wrapped 2B impressions 사례 입증된 viral 메커니즘)
- Tech가 평가한 MVP 공수 3.5주 + Live Activity 추가 시 6주 — 1인 개발자 시간 여유 충분 안에서 실행 가능
- 스마트스코어 유료화 반발(2024~2025 실제 사용자 이탈) + 광고/구독 강요에 피로한 40~60대 골퍼의 명확한 niche

---

## 2. 종합 판정

| 관점 | 판정 | 한 줄 결론 |
|------|------|-----------|
| 서비스 기획 | ⚠️ conditional | 스마트스코어 유료화 반발 + Strava식 가벼운 공유가 핵심 빈틈 |
| 기술 기획 | ✅ possible | Watch 모션 + Live Activity 조합이 1인 개발 moat 최적해 |
| 사업 기획 | ⚠️ conditional | 라이프스타일 BM 가능, 킬러 피처 1개에 집중 필수 |

**판정 규칙**: 다수결 + 경고. `conditional`은 `possible` 쪽에 합산 (2/3 conditional 이지만 다수결 진행 가능). 조건은 §6 위험 섹션에 명시.

### 평가 점수표 (한눈에 보기)

| 평가 축 | 점수 (1~4) | 짧은 코멘트 |
|---|---|---|
| 페인 포인트 진짜성 | 4 | 스마트스코어 유료화 반발·"4인 동반자 단톡방 공유 수단 부족" 실제 후기 다수 |
| 시장 규모·성장성 | 2 | 한국 골프 시장 16개월 연속 축소 + 일본·동남아 진출은 차순위 |
| 차별화·moat | 3 | UX moat(가입 없음·PII-free·휘발성)는 카피 가능하나 시간 싸움에서 viewer K-factor가 진짜 moat |
| 기술 실현성 | 4 | Apple 표준 프레임워크 + Workers free tier 안에서 모두 가능, 외부 의존 0 |
| 단위 경제성 | 2 | LTV 1,500~3,500원/유저로 절대 매출 작음. 사용자 3만 도달이 라이프스타일 BEP |
| 규제·리스크 | 4 | PII-free 정책 자체가 규제 회피. KGA 핸디캡 표현·affiliate 표기만 주의 |
| **종합 평균** | **3.2** | 1인 라이프스타일 BM 가시권. 결정타는 viral coefficient |

### 단위 경제성 시뮬레이션

business 에이전트의 `unit_economics`·`market_sizing` 기반 (수치는 응답 범위 안에서만 인용):

| 항목 | 보수 가정 | 중간 가정 | 낙관 가정 |
|---|---|---|---|
| ARPU (유료 전환자) | ₩9,900/년 | ₩9,900/년 | ₩9,900/년 |
| 유료 전환율 | 3% | 5% | 10% |
| 광고 RPM (무료 사용자) | ₩1,000/유저/년 | ₩2,000/유저/년 | ₩3,000/유저/년 |
| 사용자당 평균 LTV | ₩1,300 | ₩2,500 | ₩3,500 |
| CAC (orgnic only) | ₩0 | ₩0 | ₩0 |
| LTV/CAC | ∞ | ∞ | ∞ (절대 매출이 본질 제약) |
| 손익분기 (연 ₩3천만 BEP) | 23,000명 | 12,000명 | 8,500명 |

> CAC=0이지만 절대 매출 규모가 작음. **사용자 1만~3만 명 도달이 핵심 임계점**.

### MVP 로드맵 (12주 기준)

| 주차 | 트랙: 개발 | 트랙: GTM·검증 |
|---|---|---|
| 1~4주 | 라운드 카드 v2 (Wrapped 톤 자동 생성, 디자인 테마 3종, 카톡/인스타 원탭 공유) | 동호회 베타 20명 모집 (지인+골프 카페), viewer 공유 클릭률·재공유율 로그 분석 |
| 5~8주 | Live Activity 스코어카드 + Dynamic Island, App Intents 한국어 음성 입력 | App Store 등록 + ASO 키워드 검증(광고 없는·가입 없는·심플한), '#골프스타그램' 콘텐츠 시딩 |
| 9~12주 | 시즌 Wrapped 자동 생성 (분기/연말 회고 카드), 동반자 그룹 라이트 라이벌리 | K-factor 측정 + Pro 구독(연 9,900원 디자인 테마 해금) 도입 검토 |
| Go/No-Go 지표 | — | 12주차 DAU 100+ / 라운드당 viewer 공유 30%+ / K-factor 0.2+ |

---

## 2-1. 교차 검증 결과

- **수치 정합성**: 정합 확인. tech의 12주 MVP(라운드 카드 + Live Activity)와 business의 "3~6개월 집중" 권고가 일치. service의 viral coefficient 0.3 가정과 business의 K-factor 0.3 임계점이 동일 수치
- **타이밍 정합성**: 정합 확인. tech 3.5주 MVP → business 3개월 집중 → service 시즌 Wrapped 2026 Q3 발사 일정으로 자연스럽게 이어짐
- **타깃 정합성**: 정합 확인. service "월 1~3회 라운딩 40~60대 + 2030 보조 페르소나" vs business "iPhone+Apple Watch 사용 골퍼 200만(SAM)" — 같은 사용자층 가리킴
- **차별점 vs moat**: ⚠️ 부분 충돌. service는 "가입 없음·휘발성"을 차별점으로 강조, business는 "이건 카피 가능한 UX moat라 약함" 평가. **진짜 moat는 viewer K-factor 0.3 + 골프장 DB v4 정합성**이라는 business의 진단이 더 현실적
- **규제·데이터 정합성**: 정합 확인. tech의 HealthKit/CoreMotion/PrivacyManifest 권한 명세 vs business의 PIPA·affiliate 표시광고법·KGA 핸디캡 표현 회피 — 서로 다른 영역을 보완 커버
- **가정 충돌**: 정합 확인. 세 페르소나 모두 "1인 개발 가능 + 마케팅 0 + 점진적 확대" 가정 일치. 단 service는 "라운드 사이 hook 강화는 도메인 확장 한계"로 보수적, tech는 "Watch 자동 샷 카운터로 가능"으로 적극적 — 우선순위 차이일 뿐

**메인 의장 메모**: 세 페르소나가 **라운드 카드**라는 같은 결론에 다른 경로로 수렴. Service(viral) + Business(monetization) + Tech(인프라) 가 모두 같은 피처를 가리키는 강한 신호. 다만 business가 짚은 "절대 매출 작음 — 사용자 3만 도달이 BEP"는 service/tech가 잘 다루지 않은 현실 제약. 사용자가 이걸 받아들일 수 있는지가 핵심.

---

## 3. 서비스 관점 검토

- **가치 제안**: 동호회·친구와 가볍게 라운드를 자랑하고 비교하고 싶은 40~60대 주말 골퍼에게, 가입 없이 카톡 한 줄로 공유되는 휘발성 스코어카드와 라운드 사이를 채우는 위트있는 회고 카드를 제공
- **타깃 사용자**: 월 1~3회 라운딩 40~60대 주말 골퍼 (스마트스코어/김캐디 가입·유료화 피로감) + 2030 골프스타그램 보조 페르소나
- **해결하는 문제**: (1) 단톡방 자랑 캡처·편집 번거로움 (2) 스마트스코어 데이터 종속·유료화 신뢰 붕괴 (3) 라운드 사이 2~4주 retention 단절 (4) 동반자 4인 스코어 실시간 단톡방 공유 수단 부족
- **차별점**: 가입 없음·휘발성·PII-free 톤이 스마트스코어 반대편 niche 정확 점유
- **MVP 범위**: 라운드 카드 v2 (Wrapped 톤) MVP — 라운드 종료 직후 자동 생성 시그니처 카드 + 카톡 공유 + 7일 viewer + 동호회 20~40명 베타로 viral coefficient 측정

**판단 근거**
- 스마트스코어 유료화·데이터 종속 논란이 2024~2025 실제 사용자 이탈 발생 → 라운드온 톤이 정확히 그 빈자리에 맞물림
- Strava 14B kudos + Spotify Wrapped 2B impressions 사례 — '자동 생성 자랑 카드'가 0원 마케팅에서 가장 검증된 viral 메커니즘
- 골프스타그램 문화 2030 작동 중이지만 '한 탭으로 멋진 라운드 카드' 도구 부재 (수기 캡처가 표준)
- 1인 개발·마케팅 0 제약하 '제품 자체가 분배 채널' 되는 viral 피처가 유일한 활로

**서비스 측 위험 요소**
- 40~60대 주력층이 Wrapped식 그래픽에 덜 반응할 수 있음 (디자인 너무 힙하면 동호회 형님들 안 씀)
- 휘발성 7일 TTL이 retention 적이 될 수 있음 ("내 기록 어디?" 불만) → 로컬 영구 보관 + URL만 휘발 메시지 명확화 필요
- 동호회 단톡방 공유 viral이 "내가 100타 친 거 자동 공유되면 창피" 역효과 → opt-in + 수치 가리기 옵션 필수
- 골프라운지 같은 동호회 풀스택은 회피, '카드 공유 레이어'에만 머무는 게 차별화 유지

**사용한 가정**
- viewer 공유 사용률·재공유율 실제 데이터 없음 — '공유 카드' 부분 작동 가정만
- 40~60대 이미지 카드 반응도는 골프스타그램 2030 통계 기반 추정치
- 1인 리소스로 카드 생성 파이프라인 Worker 측 구현 가능 가정
- OCR import 양방향 viral 활용 가능 가정 ("친구가 보내준 카드"를 OCR로 받아 비교)

**참고 자료**
- [news] 스마트스코어 유료화·데이터 소유권 회사 귀속 — https://byline.network/2024/08/23-350/
- [news] 스스플러스 누적 스코어 유료화 반발·철회 — https://www.techm.kr/news/articleView.html?idxno=129944
- [review] 4인 전체 스코어 실시간 공유 수단 부족 — http://www.dealbada.com/bbs/board.php?bo_table=forum_golf&wr_id=1138793
- [trend] Strava 사회적 정체성화 — https://startupsignals.substack.com/p/strava-if-its-not-on-strava-it-didnt
- [trend] Spotify Wrapped 첫 주 다운로드 21%↑ + 2B impressions — https://nogood.io/blog/spotify-wrapped-marketing-strategy/
- [trend] Duolingo streak loss aversion — https://www.thepmrepo.com/articles/how-duolingo-gamified-monthly-active-users-lessons-in-habit-formation
- [trend] 골프스타그램 2030 확산 — https://www.golfjournal.co.kr/news/articleView.html?idxno=4182

---

## 4. 기술 관점 검토

- **핵심 기술 컴포넌트**: watchOS 10 high-frequency motion API (스윙 임팩트 감지), ActivityKit Live Activity + Dynamic Island, App Intents + Siri 한국어, CoreML/Vision Pose Detection, HKWorkoutSession, MapKit MKTileOverlay, Cloudflare Workers AI (Llama 3.1 8B) viewer 요약, WidgetKit 컴플리케이션
- **권장 스택**: 기존 (SwiftUI + SwiftData + WatchKit + Cloudflare Workers/KV) 유지 + Apple 표준 프레임워크 우선 의존 + Workers AI 무료 티어(10K req/day) 활용. 외부 SaaS 의존도 0
- **데이터 전략**: 모션 데이터 Watch 로컬 처리 후 요약치만 SwiftData (원시 IMU 전송 금지). HealthKit 사용자 동의 read/write, 외부 전송 0. 스윙 영상 디바이스 머무름, 메타데이터만 SwiftData. Workers AI 요약은 viewer 공유 시점만 PII 화이트리스트 데이터 전송, KV 7일 캐싱
- **MVP 공수 추정**: A(Live Activity 스코어카드) 2주, B(Watch 스윙 카운터) 4주+PoC 2주, C(App Intents 음성) 1.5주, D(Vision 스윙 분석) 6주+튜닝, E(Workers AI 요약) 1주. 전부 합 14~16주. A+C만 3.5주

**실현 가능성 분해**
- 검증된 기술로 가능: ActivityKit Live Activity (Apple Sports 골프 사례), watchOS 10 고주파 모션 (Golfshot Swing ID), App Intents 한국어 (iOS 18 12개 도메인), Vision VNDetectHumanBodyPoseRequest 33 키포인트, HKWorkoutSession 골프 표준, WidgetKit 컴플리케이션, Workers AI Llama 3.1 8B
- 불확실 / PoC 필요: 스윙 자동 감지 false positive (카트 진동/걷기 분리), Pose Detection 정확도 (측면 1대 카메라), 한국어 App Intents 자연어 매칭 ('버디 적어줘'), Live Activity 12시간 staleness, Workers AI Llama 한국어 골프 코멘트 자연스러움
- 막힘 / 불가: 없음

**확장성 노트**: Workers free tier 100K req/day = 1만 MAU까지 무료 (viewer 페이지뷰 5만/일 + API 5만/일 가정). KV 1K write/day = 일 300 라운드 한도, 초과 시 Paid $5/월. Workers AI 10K req/day = 일 5천 라운드 요약 무료. CoreML/ActivityKit/CoreMotion 모두 클라이언트 처리 → 서버 비용 0

**규제·보안 노트**: HealthKit Info.plist 권한 + PrivacyManifest NSPrivacyAccessedAPICategoryHealthKit. CoreMotion NSMotionUsageDescription. Vision 카메라 권한 + 영상 외부 전송 금지 명세. App Intents 추가 권한 없음. Live Activity APNs .p8 키 필요. OSM ODbL 기존 유지

**판단 근거**
- 5개 후보 모두 Apple 표준 또는 검증 오픈소스로 구성 → 1인 풀스택 범위 내
- Workers free tier 안에서 1만 MAU까지 운영비 0
- Watch 고주파 모션 + Live Activity는 Apple Sports/Golfshot 검증, 한국어 + 익명 + DB 979곳으로 차별화
- 기존 코드베이스 그대로 확장 → 학습 비용 최소

**기술 측 위험 요소**
- 스윙 자동 감지 false positive — PoC 없이 출시 시 UX 신뢰 붕괴
- Live Activity 4~5시간 라운드 staleness 관리 필요
- Vision Pose 1인 모델 튜닝까지 가면 공수 폭증 → 표준 API + 룰베이스 한정 권장
- Workers AI Llama 4096 토큰 한계 — 18홀 전체 프롬프트 길이
- Apple Intelligence 한국어 지원 일정 의존 (2026 기준 베타)
- Watch 고주파 모션 배터리 소모 → 4시간 라운드 후 배터리 부족 컴플레인

**사용한 가정**
- Apple Watch Series 6+ / iOS 18 / watchOS 10+ 다수 보유
- 라운드당 viewer 페이지뷰 5~10회, 일 신규 라운드 100~300건 목표
- 스윙 영상 분석 옵트인 (자동 촬영 안 함)
- Apple Intelligence 한국어 2026 내 안정화, 미지원 시 Shortcuts 폴백

**참고 자료**
- [official_docs] Cloudflare Workers 100K req/day 무료 — https://developers.cloudflare.com/workers/platform/limits/
- [official_docs] KV 100K read/1K write/day 무료, 1GB — https://developers.cloudflare.com/kv/platform/limits/
- [official_docs] Workers AI 10K req/day 무료, Llama 3.1 8B — https://developers.cloudflare.com/workers-ai/platform/pricing/
- [news] watchOS 10 high-frequency motion + Golfshot — https://www.apple.com/newsroom/2024/05/apple-watch-is-the-perfect-golfing-companion/
- [news] Apple Sports 골프 Live Activity — https://www.apple.com/newsroom/2026/02/apple-sports-adds-golf-to-its-lineup/
- [official_docs] App Intents iOS 18 12 도메인 — https://developer.apple.com/documentation/appintents/integrating-actions-with-siri-and-apple-intelligence
- [benchmark] Vision Pose Detection 골프 스윙 분석 SwingAi — https://apps.apple.com/us/app/swingai-golf-sport-analyzer/id6748661094

---

## 5. 사업 관점 검토

- **수익 모델**: 1차 Pro 구독 연 9,900~14,900원 (통계 무제한/핸디캡/카드 디자인 테마), 2차 골프장·골프웨어 affiliate (CPS 7~9%), 3차 비방해형 광고 (iOS interstitial $10 eCPM). 본기능(카운터/GPS/viewer 공유/기본 통계) 영구 무료 — 스마트스코어 유료화 철회 사례 반면교사
- **시장 규모**: TAM 한국 골퍼 700만 × 연 1만원 = 700억 / SAM iPhone+Watch 골퍼 200만, ARPU 5천~1만원 = 100~200억 / SOM 3년 누적 다운로드 3~10만, MAU 1~3만, 유료 5% = 연 매출 1,500만~6,000만원
- **경쟁자·대체재**: 스마트스코어(스스플러스 4,500/월, 스스투플러스 9,900/월), 카카오골프예약(200만), 김캐디(200만 DL, 시리즈A 78억), 골프존 티스캐너, Hole19/Golfshot(연 $49~70), 골프몬·골팡·XGOLF
- **경쟁 우위(moat)**: 단기는 UX moat(PII-free·가입 없음·Apple Watch 단순성), 카피 가능해 약함. 중기는 (1) 광고/구독 강요 없는 커뮤니티 신뢰, (2) 한국 965곳 DB v3+v4 정합성·보정 누적, (3) viewer K-factor 0.3 이상
- **단위 경제성**: CAC=0 (orgnic), LTV 1,500~3,500원/유저/년, 사용자 1만 → 연 1,500~3,500만원 (1인 BEP), 3만 → 4,500만~1억원 라이프스타일 안착
- **GTM 전략**: (1) viewer 공유 = 자연 viral (라운드당 평균 3명 노출, K-factor 설계 핵심), (2) App Store ASO '광고 없는·가입 없는·심플한' 키워드, (3) 콘텐츠 SEO + 골프 커뮤니티(클리앙 골프, 김캐디 골프톡, 카페) 자연 노출
- **자금 조달**: 자력 운영 충분. 외부 투자 불필요 (받으면 라이프스타일 → 스타트업 trajectory 강제 전환). 연 유지비 30만 원 이내 (App Store 13만 + 도메인/KV 5~10만)
- **규제·법 이슈**: PII-free = PIPA 회피. KGA 공인은 스마트스코어 독점이라 '자체 핸디캡' 우회. affiliate 도입 시 공정위 표시·광고 심사지침 '제휴' 표기 의무. 부킹 중개 → affiliate 단순 링크 수준 유지. HealthKit Apple 심사 5.1.3 의료 데이터 명세

**판단 근거**
- 한국 골프 시장 22.4조·700만 골퍼는 충분하나 본류는 스마트스코어/카카오/김캐디 선점 → niche에서만 승산 → conditional
- 스마트스코어 4,500~9,900원/월 가격 포인트가 시장 형성 검증
- 1인 BEP (연 3~5천만) = 사용자 1~3만 × 유료 5% 가정 시 도달 가능 자릿수 (viewer K-factor + ASO 받쳐줘야 함)
- 한국 골프 16개월 연속 축소 + 20·30대 이탈은 위협이지만 '신중 골퍼' 늘수록 라운드온 포지셔닝 매력 증가
- Apple Watch 단순성 + viewer 공유 차별화 명확. 단 카피 가능 UX moat 시간 싸움

**사업 측 위험 요소**
- 스마트스코어/김캐디가 viewer 공유 카피 시 사용자 유출 (moat 부재)
- 한국 골프 축소 3~5년 지속 시 신규 유입 줄어 orgnic GTM 둔화
- K-factor 0.3 미달 시 사용자 1만 도달 3년+ 동기 유실
- 한국 골프 affiliate 네트워크 약함 (쿠팡파트너스 외) — 1인 협상 부담
- App Store SKAdNetwork 강화·ATT 추가 제한으로 광고 RPM 하락 시 광고 BM 붕괴
- 구독 도입 시 '광고 없는·가입 없는' 브랜드 자산 훼손 — 스마트스코어 유료화 철회 반복 위험

**사용한 가정**
- viewer K-factor 0.2~0.3 설계 가능
- iOS interstitial eCPM 한국 $10 (Q4 2024) ±30% 2026~2027 유지
- 유료 전환율 5% (간단 앱 10~20% 보수적, 골퍼 페이먼트 의향이 라이프스타일보다 높을 수도)
- 한국 골프 700만 (2023 KGA) ±10% 변동
- 1인 BEP 연 3,000~5,000만 (생활비 + 운영비)

**참고 자료**
- [industry_report] 한국 골프 시장 22.4조·700만 골퍼 — https://biz.heraldcorp.com/article/10600021
- [competitor] 스마트스코어 스스플러스 4,500원/월 — https://www.newsis.com/view/NISX20240730_0002831960
- [competitor] 스마트스코어 스스투플러스 9,900원/월 — https://www.golftimes.co.kr/news/articleView.html?idxno=200176
- [case_study] 스마트스코어 스코어 관리 유료화 철회 — https://www.techm.kr/news/articleView.html?idxno=129944
- [competitor] 김캐디 시리즈A 78억·200만 DL — https://wowtale.net/2025/05/09/240745/
- [regulation] KGA 핸디캡 공식 시스템 — https://www.kgagolf.or.kr/web/handicap/apply/notice
- [industry_report] AdMob iOS interstitial 한국 eCPM $10 — https://www.playwire.com/blog/admob-ecpm-benchmarks-what-publishers-should-expect
- [competitor] Hole19 연 $49.99 / Golfshot 연 $69.99 Apple Watch GPS — https://apps.apple.com/kr/app/hole19-%EA%B3%A8%ED%94%84-gps-app-%EB%B0%8F-%EC%8A%A4%EC%BD%94%EC%96%B4%EC%B9%B4%EB%93%9C/id794462227
- [case_study] 김윤후 '간단' 앱 1인 개발 유료 전환 10~20% — https://maily.so/josh/posts/1gz2v974r3q
- [industry_report] 골프 affiliate 평균 7.5%, $5K+ 9% — https://www.affmu.com/ko/golf-affiliate-programs.html

---

## 6. 종합 위험 요소

> 세 에이전트 risks 통합 + conditional 사유 명시

- ⚠️ **service conditional 조건**: viewer 7일 TTL이 retention 적이 될 수 있음 — "로컬 영구 보관 + URL만 휘발" 메시지 명확화 + opt-in 기본값 + 수치 가리기 옵션 필수
- ⚠️ **business conditional 조건**: 절대 매출 규모 작음 — 사용자 1~3만 도달이 1인 BEP 임계점. viewer K-factor 0.3 + ASO가 받쳐줘야 함. 본기능 유료화 금지 (스마트스코어 반면교사)
- 🔴 한국 골프 시장 16개월 연속 축소 + 20·30대 이탈 → 신규 골퍼 유입 둔화
- 🔴 스마트스코어/김캐디가 viewer 공유 카피 시 UX moat 무력화
- 🟡 40~60대가 Wrapped 그래픽에 덜 반응할 수 있음 → 디자인 톤 균형 필요
- 🟡 휘발성 7일이 "내 기록 어디?" 불만 유발 가능
- 🟡 자동 공유가 "100타 친 거 창피" 역효과 → opt-in + 수치 가리기 필수
- 🟡 스윙 자동 감지 false positive (PoC 필수)
- 🟡 Apple Intelligence 한국어 지원 일정 의존 (2026 베타)
- 🟡 한국 affiliate 네트워크 약함 → 1인 협상 부담
- 🟡 구독 도입 시 브랜드 자산 훼손 위험 — 디자인 테마 해금 같은 신중 모델 필요
- 🟡 App Store SKAdNetwork 강화 시 광고 RPM 하락
- 🟢 PII-free 정책 유지 = PIPA 자동 회피 (낮은 리스크)
- 🟢 Workers free tier 1만 MAU까지 운영비 0 (낮은 리스크)

---

## 7. 다음 단계 권고

1. **'라운드 카드 v2' 3~6개월 집중 개발** — 라운드 종료 직후 자동 생성 시그니처 이미지 카드 + 카톡/인스타 공유. service+business 1순위 합의 + tech 인프라(Live Activity + Workers AI 요약) 시너지
2. **베타 검증 사전 진행** — 동호회 20~40명 모집 (지인 + 골프 카페 자발 참여), Round Card 시안 3종 노출해 단톡방 자발 공유 여부 측정. viewer 공유 클릭률·재공유율 로그 분석으로 가설 사전 검증
3. **Live Activity + App Intents 음성 입력 묶음 (5~8주차)** — tech 1+3순위. iPhone 잠긴 채로 라이브 스코어 + Siri 한국어 "라운드온 버디 적어" 단축어. 라운드 중 hook 강화
4. **시즌 Wrapped (9~12주차)** — Spotify Wrapped 패턴. 분기/연말 자동 회고 카드. 라운드 5회 이상 사용자 대상 2026 Q3 발사
5. **Pro 구독 도입 (12주차+)** — 연 9,900원 단일 플랜, 디자인 테마 10종 해금. 본기능은 영구 무료 명시 → "라운드온은 본 기능을 절대 유료화하지 않습니다" 약속 App Store 설명에 박기
6. **monthly 모니터링 4지표** — (a) MAU (b) 유료 전환율 (c) viewer 공유/DAU = K-factor proxy (d) Pro 구독 누적 매출. 1년 후 DAU 3,000 미달 시 킬러 피처 재검토
7. **글로벌 진출은 6~12개월 후 검토** — 한국 골프장 DB 의존도 높음. '코스 자동 감지 없이 수동 입력으로도 작동' fallback 강화가 선행 조건
8. **법무 체크포인트** — affiliate 도입 전 공정위 표시광고 심사지침 검토, '제휴' 표기 의무, KGA 공인 표현 금지, HealthKit 사용 시 Apple 5.1.3 의료 데이터 명세
9. **Watch 자동 샷 카운터는 베타 트랙으로 분리** — tech 2순위지만 false positive PoC 필수. 1인 운영 부담 큼. 라운드 카드 + Live Activity 성과 확인 후 별도 phase

---

*보고서 생성: plan-review skill | 모델: Claude Opus 4.7 (1M context)*

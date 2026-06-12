# 기획 검토 보고서 — 라운드온 킬러 피처 (post-round 재정의)

- **검토일**: 2026-05-28
- **검토 대상**: 라운드온 킬러 피처 재발굴 — post-round 전제 (라운드 중 카운터는 카트 태블릿 점유로 무의미)
- **종합 판정**: ⚠️ **조건부 가능** (다수결 3/3 conditional)
- **이전 보고서**: `plans/2026-05-28_killer-feature.md` (잘못된 전제 — 라운드 중 hook 권고)

---

## 1. 요약

**OCR import 1초 자동화 + 시즌 Wrapped + 라운드 카드 디자인 테마 3개를 킬러 피처로 권고.** 3 페르소나가 독립적으로 동일한 결론에 수렴 — 강한 시그널. 단, 모든 게 OCR 정확도 95%+ 달성에 달려있는 조건부 가능 판정.

**핵심 근거 3줄**
- 카트 태블릿(골프존 카운티/스마트스코어) 이 라운드 중 1차 기록을 점유 → 라운드온은 **사후 OCR import 가 유일한 진입점**. 이 영역은 무주공산
- Service/Business 가 독립적으로 OCR import 강화 + 시즌 Wrapped + 라운드 카드 디자인 테마를 1~3순위로 지목 (tech 도 8~10주 MVP 가능 확인)
- 스마트스코어 유료화 반발 + 가입 0 + PII-free 톤이 정확한 niche. 단 카피 가능 UX moat라 시간 싸움

---

## 2. 종합 판정

| 관점 | 판정 | 한 줄 결론 |
|------|------|-----------|
| 서비스 기획 | ⚠️ conditional | post-round 전제는 옳지만 OCR + Wrapped 두 축 집중해야 생존 |
| 기술 기획 | ⚠️ conditional | OCR 정확도가 핵심, 나머지는 검증된 조립 |
| 사업 기획 | ⚠️ conditional | post-round OCR niche 자력 운영 가능, 본격 수익은 조건부 |

**판정 규칙**: 다수결 + 경고. 3/3 conditional 이지만 다수결 진행 가능 (possible 합산). 조건은 §6 위험 섹션에 명시.

### 평가 점수표 (이전 보고서 대비 변화)

| 평가 축 | 점수 (1~4) | 짧은 코멘트 | 이전 대비 |
|---|---|---|---|
| 페인 포인트 진짜성 | 4 | "카메라 앨범에 묻혀 끝" 명확한 행동 갭. 스마트스코어 유료화 반발 + post-round 무주공산 | ↑ (이전 4) |
| 시장 규모·성장성 | 2 | 한국 골프 16개월 축소 + 2030 라운드 -11% 추가 감소 전망. TAM 자체 축소 | = (이전 2) |
| 차별화·moat | 2 | 카트 태블릿 종속 회피 자체는 강하나 OCR + viewer 는 모방 가능 6개월 | ↓ (이전 3, moat 약화 인정) |
| 기술 실현성 | 3 | OCR 정확도가 게이트. Workers AI 한국어 PoC 필요. 8~10주 MVP | ↓ (이전 4, OCR 리스크 반영) |
| 단위 경제성 | 2 | LTV 2,000~3,000원/유저 블렌디드. 사용자 3만~8만이 BEP 임계점 | = (이전 2) |
| 규제·리스크 | 4 | 사진 기능 폐기 정책 충돌 검토 필요하나 본인 사진 import 라 부합. PIPA 회피 | = (이전 4) |
| **종합 평균** | **2.83** | 라이프스타일 BM 가시권. 결정타는 OCR 정확도 95%+ | ↓ (이전 3.2) |

### 단위 경제성 시뮬레이션

business 에이전트 응답 범위 기반:

| 항목 | 보수 가정 | 중간 가정 | 낙관 가정 |
|---|---|---|---|
| 무료 사용자 광고 ARPU | ₩300/년 | ₩800/년 | ₩1,500/년 |
| Pro 구독 단가 | ₩14,900/년 | ₩14,900/년 | ₩14,900/년 |
| 유료 전환율 | 3% | 5% | 7% |
| Pro 평균 유지기간 | 1년 | 2년 | 3년 |
| 블렌디드 LTV | ₩650 | ₩2,000 | ₩4,500 |
| CAC (orgnic only) | ₩0 | ₩0 | ₩0 |
| 손익분기 (연 ₩3천만 BEP) | 46,000명 MAU | 15,000명 MAU | 6,700명 MAU |
| 비고 | 골프 시즌성 -30% | 광고+구독 하이브리드 | 일본 진출 후 ARPU 2배 |

> 보수 가정에서도 사용자 4.6만 MAU 도달 시 라이프스타일 BEP 통과 — 1인 운영 + 시간 충분 = 자력 운영 가능.

### MVP 12주 로드맵 (3 페르소나 통합)

| 주차 | 트랙: 개발 | 트랙: GTM·검증 |
|---|---|---|
| 1주 | OCR 템플릿 PoC (골프존 카운티 1종, 본인+지인 카드 30장, par/HCP/4인 분리 정확도 측정) | 베타 5~10명 인터뷰 — "카트 출력 → 무엇을 하나" 실제 행동 추적 |
| 2주 | Workers AI 한국어 PoC (Llama 3.3 vs Qwen3 비교 — 동일 라운드 JSON 5종 코멘트) | OCR 정확도 80%+ 게이트 확인. 미달 시 VNDetectRectangles 사전 셀 추출 전략 |
| 3주 | Share Extension + AirDrop 수신 (App Group 큐잉) | OG 카드 디자인 v2 — 카톡 단톡방 썸네일 viral 80% 영역 |
| 4~6주 | 통계 v2 → AI 프롬프트 컨텍스트 변환 + 회고 위젯 + Round Card 디자인 3종 (시즌·베스트홀·동반자 비교) | 동호회 베타 20~40명 확장 (지인 + 골프 카페 자발 참여) |
| 7주 | Instagram Stories sticker + attribution URL (golf.zerolive.co.kr) | 인스타·카톡 viral 깔때기 측정 |
| 8주 | 카드 2종(스마트스코어) 추가 + 실패 케이스 사용자 옵트인 업로드 | App Store 등록 + ASO ("광고 없는·가입 없는·심플한") |
| 9~10주 | 동반자 라이벌리 카드 + 코스 정복 배지 (DB 979곳 활용) | 골프 커뮤니티(MZ골프·웨고·아이러브골프) 콘텐츠 시딩 |
| 11~12주 | 시즌 Wrapped PDF 프로토타입 (Spotify 모델) | K-factor 측정 → 0.2+ 시 Pro 구독 도입 검토 |
| Go/No-Go 지표 | — | 12주차 DAU 100+ / OCR import 후 공유율 30%+ / K-factor 0.2+ |

---

## 2-1. 교차 검증 결과

- **수치 정합성**: 정합 확인. tech 8~10주 MVP vs business "M0~M6 무료 기간" 자연스럽게 맞물림. service viral coefficient 0.3 vs business K-factor 0.3 동일 가정
- **타이밍 정합성**: 정합 확인. tech Week 1 OCR PoC → service "베타 5~10명 인터뷰 먼저" → business "M0~M6 사용자 확보" 가 일관된 흐름
- **타깃 정합성**: ⚠️ 약한 차이. service "30~50대 월 1~2회 라운더" vs business "40~60대 80%" → 양쪽이 보완. 1차 타깃 40대로 좁히는 권고
- **차별점 vs moat**: 일치. service "가입 0·PII-free·7일 TTL" 차별점이 강하지만, business 가 "모방 가능 6개월 — 약함" 으로 진단. 양쪽 모두 moat 약함 인정 → 시간 싸움
- **규제·데이터 정합성**: 보완 완료. tech "사진 기능 폐기 정책 충돌 검토" + business "PIPA 적용 최소". OCR import 는 본인 사진이라 폐기 정책 위반 아님 명시
- **가정 충돌**: 없음. 모두 1인 개발 + 마케팅 0 + post-round 전제 + Workers free tier 가정 일치

**메인 의장 메모**: 3 페르소나가 OCR import + 시즌 Wrapped + 라운드 카드를 같은 1~3순위로 독립 수렴. 이전 보고서가 Live Activity/Watch 자동 카운터를 권고한 건 사용자가 지적한 정확한 잘못된 전제(라운드 중 hook 가능 가정) 위에 있었음. 이번 보고서는 그 전제를 폐기하고 재구성. tech 의 핵심 리스크 — OCR 정확도 95% 게이트가 미달 시 LLM Vision API fallback 이 필요한데 free tier 운영 원칙과 충돌 → Week 1 PoC 결과가 모든 의사결정의 분기점.

---

## 3. 서비스 관점 검토

- **가치 제안**: 캐디 태블릿이 적어준 스코어카드로 가입·구독 없이 시즌 자랑을 만들고 싶은 월 1~2회 라운더에게, 사진 한 장 → 통계·카드·동반자 비교를 1분 안에 제공
- **타깃 사용자**: 한국 거주 30~50대 월 1~2회 라운더 (연 12~24라운드). 카트 태블릿으로 라운드 중 기록은 충족되나, 라운드 종료 후 PDF/사진을 단톡방·인스타에 공유하고 시즌 누적으로 보고 싶지만 스마트스코어 유료화에 거부감 + PII·구독에 민감
- **해결하는 문제**: 라운드 종료 후 받은 스코어카드 이미지가 "카메라 앨범에 묻혀 끝". 시즌 누적·동반자 비교·자랑용 카드를 무료로 빠르게 해주는 도구 없음
- **차별점**: (1) 가입 0 + PII-free + 7일 TTL — 단톡방 즉시 공유 최적, (2) 양사(스마트스코어/골프존 카운티) 카드 동시 수용 중립 OCR, (3) 시즌 Wrapped·동반자 라이벌리·코스 정복 배지 회상 콘텐츠 화력 집중
- **MVP 범위**: 4개 압축 — (A) 공유시트 1초 import + OCR 동반자 자동 매칭, (B) 동반자 라이벌리 카드 (별명별 누적 승률·평균차·최근 5R), (C) 시즌 Wrapped (반기/연말, Spotify 톤), (D) 코스 정복 배지 (DB 979곳)

**판단 근거**
- 재정의된 전제(카트 태블릿이 라운드 중 점유)는 한국 골프장 디지털 스코어카드 보급 현실과 부합. 라운드 중 hook 진입 불가, post-round 는 무주공산
- 스마트스코어 유료화 반발 "내 데이터로 장사한다" 명확. 가입 0·구독 0·PII-free 라운드온은 반발심리의 정확한 안티테제
- 동반자 공유·단톡방 자랑은 한국 골프 커뮤니티 핵심. Spotify Wrapped 6.3억 회 공유 — 개인화 데이터 회상 콘텐츠 공식이 골프 시즌 단위에 이식 가능
- 월 1~2회 라운드는 데일리 hook retention 거의 불가능. 라운드 단위 깊은 콘텐츠 + "카톡 공유 → 동반자 역유입" 바이럴이 유일한 현실 전략
- **이전 보고서의 Live Activity/Watch 카운터 1순위 권고는 카트 태블릿 점유 현실을 놓친 잘못된 전제 — 인정하고 post-round 로 전면 피벗**

**서비스 측 위험 요소**
- OCR 정확도 95% 미달 시 "1초 import" 약속 붕괴 → 첫인상 이탈
- 동반자 라이벌리·시즌 Wrapped 는 누적 라운드 필요 — 첫 1~2라운드 신규 사용자에게 빈 화면 (콜드스타트 보강 필요)
- 카톡 viewer URL OG 태그가 단톡방 viral 의 80% — 어설프면 카드 v2 가 아무리 좋아도 클릭 안 일어남
- 스마트스코어 무료 회귀 또는 김캐디 OCR 가입 장벽 낮추기 시 차별점 마모
- 월 1~2회 라운드 + 7일 TTL = 50일 빈 기간 채울 라이트 콘텐츠 부족 시 재진입 실패

**사용한 가정**
- 한국 골퍼 평균 라운드 빈도 월 1~2회 (KGA 2023 + 커뮤니티 정보)
- 카트 태블릿 시장 점유율 골프존 카운티 + 스마트스코어 = 90%+ 가정
- 스마트스코어 유료화 반발이 라운드온 차별점 핵심 동력
- 동반자 단톡방 공유 욕구 강함 — 실 사용자 인터뷰 5~10명 검증 필요

**참고 자료**
- [competitor] 스마트스코어 유료화 "데이터로 장사" 반발 — https://www.geconomy.co.kr/news/article.html?no=288098
- [trend] 한국 골퍼 78% 스코어 관리 앱 사용 — https://thebirdiemade.com/entry/...
- [competitor] 김캐디 사진/OCR + 18Birdies 연동 post-round 진입 — https://www.techm.kr/news/articleView.html?idxno=129372
- [trend] Spotify Wrapped 6.3억 공유 — https://www.campaigninsight.co.kr/news/articleView.html?idxno=1829
- [competitor] 골프존 필드 스코어카드 카트 태블릿 점유 — https://story.golfzon.com/613
- [news] 한국 골퍼 평균 96.9타 — https://www.etoday.co.kr/news/view/1231532
- [competitor] 3사 부킹/마켓 사업 무게 — post-round 회상 영역 무주공산 — https://brunch.co.kr/@kellypoly/82

---

## 4. 기술 관점 검토

- **핵심 컴포넌트**: Vision VNRecognizeTextRequest (ko-KR) + 카드 레이아웃 템플릿 매처, Share Extension + AirDrop 수신, PhotosKit auto-detect, Cloudflare Workers AI (Llama 3.3 70B 또는 Qwen3), WidgetKit (정적 통계 + D-day), ImageRenderer Round Card + Instagram Stories URL scheme, SwiftData 통계 v2 → AI 프롬프트 변환 레이어
- **권장 스택**: iOS 18+ SwiftUI/SwiftData 유지. OCR Swift Package 분리 (.accurate + ko-KR + 두 카드 bounding-box 템플릿 매처). Share Extension UTType.image + App Group 큐잉 (120MB 메모리 회피). Workers AI 한국어 모델 PoC 후 결정 — Llama 비공식 vs Qwen3 다국어 명시. KV 캐시 7일. Round Card SwiftUI ImageRenderer + instagram-stories:// + sticker payload
- **데이터 전략**: OCR 학습 데이터 본인+지인 50~100장 (개인 사본 fair use). 카드 레이아웃 hard-coded 2~3종 시작, 실패 케이스 사용자 동의 옵트인 익명 업로드. AI 코멘트는 라운드 JSON(스코어/par/홀별/코스명/동반자 별명만) — PII 없음. 골프장 DB v4 979곳 코스명 매칭 컨텍스트 강화
- **MVP 공수**: 1인 × 8~10주 (OCR 템플릿 2종 4주 + Share Extension 1주 + AI 회고 PoC 1.5주 + Widget 1주 + Round Card 다양화 1주 + 통합/QA 1.5주)

**실현 가능성 분해**
- 검증: Vision ko-KR OCR (95~99% 클린 프린트), Share Extension + AirDrop, WidgetKit, ImageRenderer Round Card, Workers + KV (이미 운영), Instagram Stories URL scheme
- 불확실 / PoC 필요: 스코어카드 표 구조 인식률 (Vision 은 텍스트 인식이지 표 구조 X), Workers AI Llama 3.3 한국어 골프 도메인 품질 (공식 지원 언어 미포함, Qwen3 가 더 안전 가능성), Workers AI free tier 100K req/day, Share Extension 메모리 120MB 안 .accurate 처리, PhotosKit auto-import 거부감
- 막힘: 없음

**확장성 노트**: post-round 전용이라 동시성 부담 극히 낮음. AI 코멘트 라운드당 1회 (월 1만 MAU × 4라운드 = 4만 req/월 free 충분). OCR 전부 on-device. Workers KV 쓰기 1K/day free 한도가 viewer 공유와 겹치면 압박 — 라운드별 1회 제한 필요. 1M 사용자 시 Workers Paid + KV $5/1M write 가 첫 비용 지점

**규제·보안 노트**: 사진 기능 폐기 정책(2026-05-18) 충돌 검토 — OCR import 는 "사용자가 직접 import한 스코어카드 사진"으로 한정, viewer/외부 미전송 시 부합. Share Extension 시스템 share sheet 라 권한 마찰 최소. AI 회고 JSON 동반자 별명 외 PII 없음 명시. Instagram Stories attribution_url 정책. 스코어카드 OCR 결과의 골프존/스마트스코어 UI 캡처 재배포는 회색지대 — 본인 라운드 변환만, 카드 원본 저장/공유 안 함 명문화

**판단 근거**
- Vision 한국어 인쇄체 95%+ 보장되지만 표 구조 파싱은 별도 템플릿 엔지니어링 — PoC 결과에 전체 성패
- Workers AI 한국어 모델 선택 PoC 후 결정. 둘 다 실패 시 OpenAI/Anthropic fallback 필요하나 free tier 원칙 충돌
- 나머지 컴포넌트 모두 iOS 표준 API 검증 — 8~10주 공수
- post-round 포지셔닝은 카트 태블릿 충돌 회피 → 카트 OEM 이 OCR import 자기 앱에 넣을 동기 0

**기술 측 위험 요소**
- OCR 표 구조 파싱 75% 미만 시 매번 수동 보정 → "1초만에" 캐치프레이즈 붕괴
- 골프존 카운티/스마트스코어 카드 레이아웃 변경 시 템플릿 전면 재작성
- Workers AI 한국어 출력 어색 시 회고 위젯 가치 소실
- Share Extension 메모리 한계로 .accurate 미사용 → 정확도 저하
- Instagram Stories SDK 정책 변경 (URL scheme deprecation) 시 viral 채널 끊김
- PhotosKit auto-detect 전체 사진 권한 → 사용자 거부 시 자동성 상실

**사용한 가정**
- 기존 OCR import 코드 Vision 기반, 단일 카드 1인 스코어 추출 작동 가정
- 한국 카트 출력 스코어카드 양사 시장 90% 커버
- Cloudflare 한국 PoP latency p95 200ms 이하
- 라운드 직후 카드 사진 찍기 한국 골퍼 다수 자연스러운 습관
- Workers AI $0.30/1M token 2026 유지
- Widget/Live Activity 정적 카운트다운 충분 (라운드 중 Live Activity 명시적 제외)

**참고 자료**
- [official_docs] Vision VNRecognizeTextRequest ko-KR — https://developer.apple.com/documentation/vision/vnrecognizetextrequest
- [official_docs] Workers AI 가격 100K req/day free — https://developers.cloudflare.com/workers-ai/platform/pricing/
- [official_docs] Llama 3.1 공식 한국어 미포함, Qwen3 100+ 다국어 — https://developers.cloudflare.com/workers-ai/models/qwen3-30b-a3b-fp8/
- [official_docs] Instagram Stories instagram-stories URL scheme — https://developers.facebook.com/docs/instagram-platform/sharing-to-stories/
- [benchmark] Vision OCR 95~99% — https://scanlens.io/blog/on-device-vs-cloud-ocr
- [other] Vision 영수증 OCR 패턴 (셀 grid 추출) — https://shawnbaek.com/2021/04/11/lets-make-a-receipt-text-recognizer-with-the-apple-vision-framework/

---

## 5. 사업 관점 검토

- **수익 모델**: (1) 무료 본기능 + AdMob 네이티브/배너 long-tail, (2) Round-On Pro 연 9,900~14,900원 / 월 1,900원 (시즌 Wrapped PDF·카드 디자인 테마·AI 코멘트·고급 통계 해금), (3) 골프용품/예약/투어 어필리에이트 (쿠팡 3% / 골프존 카운티 등 제휴 10~20%), (4) 시즌 종료기 골프장·골프웨어 네이티브 광고. 카트 태블릿이 라운드 중 점유 → 광고/유료화는 100% post-round 슬롯
- **시장 규모**: TAM 한국 골퍼 700만 × 디지털 1만원/년 = 700억 (스코어·통계·공유 카테고리) / SAM 40~60대 35% = 245만 명, ARPU 5천 = 120억 / SOM 3년 내 MAU 3~8만, 전환 5% = 유료 1.5~4천 × 12,000원 = 연 1,800만~4,800만원. 광고 추가 시 연 3,000만~8,000만원
- **경쟁자·대체재**: 스마트스코어 (380만, VIG 22%, 1,000억 추가 펀딩 추진), 김캐디 (200만 DL, 100억+ 투자, 일본 진출), 카카오골프예약 (33% 1위), 골프존 카운티 카트 태블릿, X-Golf/스크린골프, Apple Health/Garmin/Strava (general fitness post-activity 자랑 UX 벤치마크)
- **경쟁 우위(moat)**: 단기 moat 약함 — OCR UX·DB 979곳·viewer 7일 TTL PII-free 차별점 모방 가능. 잠재 moat: (1) post-round niche 일관 좁힘 브랜드 포지션, (2) 시즌 누적 데이터 lock-in, (3) 카트 태블릿 보완재 포지션 (직접 경쟁 안 함). 다만 스마트스코어/김캐디 확장 시 자본력 차이 위협
- **단위 경제성**: CAC orgnic 0~3,000원. 광고 eCPM 한국 일반 라이프스타일 (배너 500~1,500원·전면 5,000~15,000원/1000노출) × 세션 2~3회/월 × 12개월 = 광고 ARPU 연 300~1,500원/유저. 유료 전환 5% × 12,000원 × 2년 = LTV 24,000원. 블렌디드 LTV 2,000~3,000원. CAC<LTV 성립하나 절대 규모 작아 유료 광고 집행 비추
- **GTM 전략**: 첫 100명 (인스타·블로그 viewer 카드 #골프스타그램 + 네이버 골프 카페 후기 + micro-influencer 1~5만 구독), 첫 1,000명 (viewer 자체 viral — 동반자가 보고 다운로드), 첫 10,000명 (시즌 Wrapped PDF 12월 출시 Spotify 모델, 200M+ 24시간 engagement)
- **자금 조달**: 자력 운영. 1인·마케팅 0·Cloudflare KV TTL 7일·App Store 99달러/년. BEP 월 30~50만원. 연 매출 1,000만원 넘으면 라이프스타일 BM 성립. 외부 투자 불필요 — 받으면 카트 태블릿 사업자 정면충돌 강요받아 niche moat 손상
- **규제·법 이슈**: PIPA 적용 최소 (PII 없음). 어필리에이트 시 공정위 "제휴" 표기 의무. App Store IAP 30%/15% 수수료. 사업자등록 간이과세자 (연 매출 1.04억 미만), 4,800만 미만 부가세 면제

**판단 근거**
- post-round niche 카트 태블릿 미점유 빈 슬롯. 스마트스코어조차 라운드 중 입력 UX 집중 → 통계 자랑·시즌 회상 빈틈
- SOM 연 매출 3,000만~8,000만원 라이프스타일 BM 1,200만원~ 의 2~6배 손익분기 충분
- B2C 골프 통계 광고 ARPU 낮음·구독 전환율 3~7% — "돈이 큰 사업" X. 시리즈 펀딩 스케일 아님

**사업 측 위험 요소**
- 스마트스코어/김캐디 OCR import + viewer 공유 모방 위험 — 6개월 내 따라잡힐 수 있음 (자본력 차이)
- 한국 골프 16개월 연속 축소, 2030 라운드 -11% 추가 감소 전망 — TAM 자체 축소
- 광고 골프 광고주 풀 좁음 (골프웨어·예약·용품 한정). 비시즌(12~2월) 광고 수익 급감
- Apple 30% 수수료 + 한국 ARPU 미국 1/16 → 구독 단가 글로벌 절반 강제. LTV 압축
- post-round 전제 자체 오판 가능성 — 카트 태블릿이 자체 통계·공유 강화 시 슬롯 사라짐. 카트 사업자 로드맵 모니터링 필수

**사용한 가정**
- 한국 골프 700만 / 22.4조 (유원골프 백서 2024) 2026 자릿수 유효
- 광고 eCPM 일반 라이프스타일 범위 (골프 전용 공개 데이터 없음)
- 구독 전환율 5% (김윤후 10~20% 보수적, 골프 시즌성·고연령 특성 낮을 수 있음)
- 1인 비용 본인 인건비 제외 순현금 (서버·계정·도구)
- 카트 태블릿 향후 2~3년 자체 post-round 본격 강화 없음

**참고 자료**
- [industry_report] 한국 골프 22.4조·700만 (유원골프 백서 2024) — https://www.newsis.com/view/NISX20251023_0003374464
- [industry_report] 2025 내장객 -2.1%, 2030 라운드 -11% 전망 — https://www.golfin.co.kr/news/articleView.html?idxno=7365
- [funding] 스마트스코어 1,000억 추가 펀딩 추진 — https://www.thebell.co.kr/free/content/ArticleView.asp?key=202511101304462320109425
- [competitor] 김캐디 200만 DL, 100억+, 일본 진출 — https://www.unicornfactory.co.kr/article/2025050917100455328
- [competitor] 김캐디 30명 6배 성장 — https://flex.team/blog/2025/04/23/kimcaddie
- [case_study] 김윤후 단식 200만 사용자 월 1,200만 전환 10~20% — https://eopla.net/magazines/31129
- [case_study] 1인 개발 niche 월 1천만 6가지 전략 — https://blog.10xbuilders.io/blog/indie-app-monetization-strategy-guide/
- [case_study] Spotify Wrapped 200M+ 24h engagement — https://nogood.io/blog/spotify-wrapped-marketing-strategy/
- [competitor] CamScanner OCR freemium $4.99/월·$35.99/년 — https://apps.apple.com/us/app/camscanner-ocr-scanner/id388624839

---

## 6. 종합 위험 요소

> 3 페르소나 risks 통합 + conditional 사유

- ⚠️ **service conditional**: OCR 정확도 95% 미달 시 "1초 import" 약속 붕괴 + 콜드스타트 (첫 1~2라운드 빈 화면) + 카톡 OG 카드 viral 80% 영역 어설프면 클릭 안 일어남
- ⚠️ **tech conditional**: Vision 한국어 OCR 자체는 검증되나 스코어카드 표 구조 파싱은 별도 PoC 영역. Workers AI 한국어 골프 모델 선택 (Llama 비공식 vs Qwen3 다국어) PoC 필요
- ⚠️ **business conditional**: 절대 매출 규모 작음 (LTV 2,000~3,000원) — 사용자 1.5만~4.6만 MAU 가 라이프스타일 BEP. 카트 태블릿 사업자 자체 post-round 강화 시 슬롯 소실

- 🔴 **OCR 정확도 95% 게이트 미달** — 모든 피처의 전제 (Week 1 PoC 결과가 분기점)
- 🔴 **스마트스코어/김캐디 OCR + viewer 모방** — 6개월 내 따라잡힐 수 있음 (자본력 차이)
- 🔴 한국 골프 16개월 축소 + 2030 라운드 -11% — TAM 자체 축소
- 🟡 골프존 카운티/스마트스코어 카드 레이아웃 변경 시 템플릿 전면 재작성
- 🟡 Workers AI 한국어 출력 어색 시 회고 위젯 가치 소실 → OpenAI/Anthropic fallback 시 free tier 충돌
- 🟡 Share Extension 메모리 120MB 한계로 .accurate 미사용 → 정확도 저하
- 🟡 Instagram Stories URL scheme deprecation 시 viral 채널 끊김
- 🟡 카트 태블릿 사업자 자체 post-round 통계/공유 강화 시 슬롯 소실
- 🟡 광고 의존 시 골프 광고주 풀 좁음, 비시즌 수익 급감
- 🟡 Apple 30% 수수료 + 한국 ARPU 1/16 → 구독 단가 압축
- 🟡 사진 기능 폐기 정책 충돌 검토 — OCR 본인 사진 import 라 부합하나 명문화 필요
- 🟢 PIPA 회피 (PII 없음) 낮은 리스크
- 🟢 Workers free tier 1만 MAU 까지 운영비 0 낮은 리스크
- 🟢 카트 태블릿 OEM 직접 경쟁 회피 (보완재 포지션)

---

## 7. 다음 단계 권고

### 즉시 (Week 1~2)
1. **OCR 템플릿 PoC** — 골프존 카운티 1종 본인+지인 30장 par/HCP/4인 분리 정확도 측정. **80%+ 게이트 통과해야 전체 진행**. 미달 시 VNDetectRectangles 사전 셀 추출 전략 전환
2. **Workers AI 한국어 PoC** — Llama 3.3 70B fp8 vs Qwen3-30B-A3B 동일 라운드 JSON 5종 코멘트 비교. 한국어 + 골프 용어 정확도로 모델 결정
3. **베타 5~10명 인터뷰** — "카트 출력 → 스코어카드 받음 → 무엇을 하나" 실제 행동 추적. 단톡방 공유율·인스타 업로드율·캡쳐 후 묵힘 비율 실측

### 핵심 개발 (Week 3~8)
4. **공유시트 1초 import 강화** — Share Extension + AirDrop 수신 + OCR 동반자 자동 매칭. **1순위 킬러 피처**
5. **카톡 OG 카드 디자인 v2** — viewer URL 단톡방 썸네일 viral 80% 영역. Worker /og 엔드포인트 신설
6. **Round Card 디자인 다양화 3종** — 시즌별 / 베스트홀 / 동반자 비교
7. **Instagram Stories sticker 공유** — attribution URL (golf.zerolive.co.kr) 통합
8. **카드 2종(스마트스코어) 추가** — 실패 케이스 사용자 옵트인 업로드

### 확장 (Week 9~12)
9. **동반자 라이벌리 카드** — 별명별 누적 승률·평균차·최근 5R. **2순위**
10. **코스 정복 배지** — DB 979곳 색이 채워지는 한국 골프장 컬렉션
11. **시즌 Wrapped PDF 프로토타입** — 2026 상반기 Wrapped, Spotify 톤. 12월 출시 일정. **3순위 (Pro 구독 lock-in)**
12. **콜드스타트 보강** — 첫 import 후 "작년 카드 더 가지고 계신가요? 5장 import 하면 시즌 카드 완성" 유도 + 라운드 0회 사용자 샘플 데모

### Monetization (Month 6~)
13. **AdMob 네이티브 광고** — 라운드 상세 하단·통계 화면만. interstitial 금지 (사용성 훼손)
14. **Round-On Pro 구독 도입** — 연 14,900원 / 월 1,900원 단일. 디자인 테마 10종 해금 + AI 코멘트 무제한 + 시즌 Wrapped PDF
15. **"본 기능 영구 무료" 약속** App Store 설명 명시 — 스마트스코어 유료화 반발 사용자 흡수

### 글로벌 (Month 12~18)
16. **일본 진출 i18n** — 카트 태블릿 보급률 낮음 + ARPU 2배. v1.0 안정화 후 검토. 김캐디 일본 진출 = 시장 검증 시그널

### 모니터링
17. **monthly 4지표 추적** — MAU / 유료 전환율 / viewer 공유/DAU = K-factor / Pro 누적 매출. 1년 후 DAU 3,000 미달 시 킬러 피처 재검토
18. **카트 태블릿 OEM 분기 로드맵 모니터링** — 스마트스코어·골프존 카운티 자체 post-round 강화 시그널. 슬롯 소실 위협 조기 감지

### 법무
19. **사진 기능 폐기 정책 충돌 명문화** — OCR import 는 본인 사진만, viewer/외부 미전송 명시
20. **어필리에이트 도입 전 공정위 표시광고 심사지침** — "제휴" 표기 의무
21. **KGA 공인 표현 금지** — "라운드온 추정 핸디캡(USGA 약식)" 일관 표기

---

## 부록: 이전 보고서 (`2026-05-28_killer-feature.md`) 와 변화

| 항목 | 이전 권고 | 재정의 후 |
|---|---|---|
| 1순위 | 라운드 카드 + Live Activity 스코어카드 | **OCR import 1초 자동화 + Share Extension** |
| 2순위 | Watch 자동 샷 카운터 | **시즌 Wrapped PDF (Pro lock-in)** |
| 3순위 | App Intents 한국어 음성 입력 | **라운드 카드 디자인 테마** |
| 폐기 | — | Live Activity (라운드 중), Watch 자동 카운터, App Intents (모두 카트 태블릿 종속) |
| 신규 추가 | — | 공유시트/AirDrop import, 카톡 OG 카드 v2, 동반자 라이벌리, 코스 정복 배지 |
| 가정 변화 | 라운드 중 hook 가능 | **라운드 중 카트 태블릿 점유 → post-round 만 진입점** |
| 종합 평균 점수 | 3.2 | 2.83 (OCR 리스크·moat 약화 반영) |

이전 보고서는 사용자가 정확히 지적한 잘못된 전제(라운드온이 라운드 중 카운터를 점유 가능 가정) 위에 있었음. 이번 보고서는 post-round 만 진입점인 현실로 재구성 + 모든 권고를 그 전제에 맞춤.

---

*보고서 생성: plan-review skill | 모델: Claude Opus 4.7 (1M context)*

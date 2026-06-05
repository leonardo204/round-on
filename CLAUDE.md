# Claude Code 개발 가이드

> 공통 규칙(Agent Delegation, 커밋 정책, Context DB 등)은 글로벌 설정(`~/.claude/CLAUDE.md`)을 따릅니다.
> 글로벌 미설치 시: `curl -fsSL https://raw.githubusercontent.com/leonardo204/dotclaude/main/install.sh | bash`

---

## 프로젝트 핵심 사실

| 항목 | 값 |
|------|-----|
| 앱 이름 | 라운드온 (Round-On) — 2026-05-11 확정 |
| Bundle ID | `kr.zerolive.golf.roundon` (단일 — Watch app 동반 설치 호환) |
| Watch Bundle ID | `kr.zerolive.golf.roundon.watchkitapp` (WKCompanionAppBundleIdentifier 매칭) |
| Team ID | `XU8HS9JUTS` |
| Viewer 도메인 | `golf.zerolive.co.kr` |
| 저장소 | github.com/leonardo204/round-on (SSH: git@github.com:leonardo204/round-on.git) |
| 빌드 | `xcodebuild -scheme RoundOn` (Watch app 자동 embed) |

---

## 핵심 규칙

- **한국어로 답변** (코드·커밋 메시지·파일명 제외)
- **검증 필수**: 완료 선언 전 빌드 성공·타입체크·테스트 결과를 증거로 제시
- **커밋 금지**: 사용자 명시 요청 전까지 git add/commit/push 절대 금지
- **F4 카운터**: par에서 시작 X — **0에서 시작, 샷마다 +1** (OB +2, 해저드 +1, OK +1)
- **F3 GPS**: 골프장 + 서브코스 단위만 자동 감지 — **홀 단위 자동 감지는 미제공, 항상 수동 진행**
- **DB**: 한국 골프장 DB v3 965곳 기준. 941곳 `low`. dataQuality 기반 분기 처리 필수
- **DB 동기화**: 번들 979(다중소스 base) + 원격 골프존 216(보강 피드, 전체 아님). 원격=`/v1/courses`(id+name 메타)+`/v1/course-pars`(실 par). **번들 교체 금지 — id/이름 매칭 par 머지**. 관대한 전용 DTO 사용(full GolfCourse 디코드 금지). 상세: [ref-docs/golf-db-pack/42-COURSE_DB_SYNC.md](ref-docs/golf-db-pack/42-COURSE_DB_SYNC.md)
- **개인정보**: 위치 외부 전송 금지. 동반자 별명 + 스코어만 viewer 공유. **사진 기능 폐기됨(2026-05-18)** — 사진 관련 코드/spec 모두 무효. Viewer 7일 후 KV 자동 삭제
- **OSM ODbL**: 앱 내 설정 → 정보에 `© OpenStreetMap contributors, ODbL 1.0` 표기 필수
- **xcodebuild destination**: iPhone 16 Pro는 OS 버전을 명시해야 모호성 회피 (메모리 참조)
- **iOS 코드 변경**: 단일 ralph에 위임 (두 ralph 동시 iOS 영역 작업 금지)
- **로깅 필수**: 주요 흐름(import·저장·충돌·네트워크/Gemini·광고·화면전환)은 단계별로 `os.Logger`(subsystem `kr.zerolive.golf.roundon`, category별)로 진입/결과/실패를 기록. 새 기능엔 단계 로그 + 네트워크엔 소요시간(ms) 로그 필수 — 런타임 UI/비동기 버그 추적성 확보

---

## 자주 참조할 문서

- [README.md](README.md) — 프로젝트 전체 개요 (사람용)
- [ref-docs/specs/01-SPEC.md](ref-docs/specs/01-SPEC.md) — 기능 명세서 v4 (마스터)
- [ref-docs/specs/00-OVERVIEW.md](ref-docs/specs/00-OVERVIEW.md) — 제품 개요·Non-Goals
- [ref-docs/specs/15-NAVIGATION.md](ref-docs/specs/15-NAVIGATION.md) — 화면 전환 정책 (fullScreenCover/push/sheet 사용 규칙)
- [ref-docs/specs/20-ARCHITECTURE.md](ref-docs/specs/20-ARCHITECTURE.md) — 시스템 아키텍처
- [ref-docs/specs/21-DATA_MODEL.md](ref-docs/specs/21-DATA_MODEL.md) — SwiftData 모델·DataQuality enum
- [ref-docs/specs/30-API_SPEC.md](ref-docs/specs/30-API_SPEC.md) — Worker API 7개 엔드포인트
- [ref-docs/specs/33-SECURITY.md](ref-docs/specs/33-SECURITY.md) — bcrypt, PIN, PII 정책
- [ref-docs/golf-db-pack/README.md](ref-docs/golf-db-pack/README.md) — 골프장 DB v3 빠른 시작

---

## 메모리 갱신

중요한 결정이나 발견 시:
```bash
bash .claude/db/helper.sh decision-add "결정 내용" "이유"
bash .claude/db/helper.sh live-set current_task "현재 작업"
```

---

*최종 업데이트: 2026-06-05 (문서 폴더 ref-docs 소문자 통일)*

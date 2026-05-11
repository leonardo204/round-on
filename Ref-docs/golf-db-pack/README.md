# 한국 골프장 DB 패키지

> **라운드온 (Round-On)** 앱용 한국 골프장 데이터셋
> 빌드일: 2026-05-11  
> 데이터 출처: OpenStreetMap (ODbL 라이선스)

---

## 📦 패키지 구성

| 파일 | 용도 |
|------|------|
| **`courses.json`** | ⭐ **앱 번들에 포함할 파일** (140 KB, minified, 546개 골프장) |
| `courses_pretty.json` | 동일 데이터의 읽기용 (225 KB, indent 적용) |
| `courses_full_debug.json` | 전체 데이터 + 디버그 정보 (493 KB, 623개 - 연습장/스크린골프 포함) |
| `quality_report.json` | 데이터 품질 통계 리포트 |
| `build_db.py` | 재현 가능한 빌드 스크립트 |
| `40-COURSE_DB_SCHEMA.md` | JSON 스키마 명세 + Swift 코드 예시 |
| `41-COURSE_DB_PIPELINE.md` | 데이터 수집 파이프라인 전 과정 문서 |

---

## 🚀 빠른 시작 (Claude Code에서)

### 1. iOS 앱 번들에 추가
```
1) courses.json 을 Xcode 프로젝트에 드래그
2) "Copy items if needed" 체크, 앱 타겟 선택
3) 40-COURSE_DB_SCHEMA.md의 Swift 코드 예시 참고
```

### 2. 핵심 사용 패턴
```swift
// 앱 시작 시 1회 로드
let repo = CourseRepository.shared  // 546개 골프장 메모리에

// F1: 자동 매칭 (현재 위치에서 가장 가까운 골프장)
let nearest = repo.nearestCourse(to: currentLocation)
// → "남서울컨트리클럽" 등 반환

// F3: GPS 홀 자동 감지
let hole = nearest?.nearestHole(to: currentLocation)
// → 50m 이내 홀이 있으면 반환 (없으면 nil → 수동 모드)
```

---

## 📊 데이터 요약

- **546개 한국 골프장** (실제 코스, OSM 출처)
- **위치 정보**: 모든 골프장에 클럽하우스 좌표 보유
- **홀별 정보**: 14개 골프장에 9홀+ 매핑, 그 중 3개는 18홀 전체

### 지역별 분포
경기 188 / 경북 66 / 전남 59 / 경남 49 / 강원 48 / 충북 45 / 전북 30 / 제주 28 / 충남 27 / 인천 17 / 광주 13 / 울산 11 / 대구 10 / 부산 10 / 서울 9 / 세종 7 / 대전 6

### dataQuality 분포
- `complete` (18홀 + 모든 par): 3개
- `partial` (9홀+): 11개
- `minimal` (1~8홀): 8개
- `low` (위치만): 524개

> ⚠️ OSM의 한국 골프장 홀별 매핑이 미진해 대부분 `low` 품질입니다.  
> F1(골프장 자동 매칭)은 거의 모든 골프장에서 정상 작동하지만, F3(GPS 홀 자동 감지)는 14개 골프장에서만 동작합니다.  
> 자세한 내용은 `41-COURSE_DB_PIPELINE.md` §8 참고.

---

## 🔄 데이터 갱신

### OSM 데이터 재수집 + 재빌드
```bash
cd golf-db/
# 1) OSM 데이터 다운로드 (자세한 curl 명령은 41-COURSE_DB_PIPELINE.md §3)
bash fetch_osm.sh

# 2) 광역 polygon 빌드
python3 build_regions.py

# 3) 메인 빌드
python3 build_db.py
```

### 한국 공공데이터 통합 (보강)
공공데이터포털(data.go.kr)에서 다음 데이터셋을 수동 다운로드 후 통합:
- 행정안전부_골프장
- 문화체육관광부_전국 골프장 현황
- 국토교통부_골프장현황도

좌표계 변환 (EPSG:5174 → WGS84) 필요. 자세한 내용은 `41-COURSE_DB_PIPELINE.md` §9.1 참고.

---

## 📜 라이선스

이 데이터는 **OpenStreetMap 기여자들의 데이터**를 가공한 결과물이며, **ODbL 1.0** 라이선스를 따릅니다.

앱 내 어딘가에 다음 표기가 필요합니다:
```
© OpenStreetMap contributors, ODbL 1.0
https://www.openstreetmap.org/copyright
```

권장 위치: **설정 → 정보 → 사용된 오픈소스/데이터**

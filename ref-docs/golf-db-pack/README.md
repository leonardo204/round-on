# 한국 골프장 DB 패키지

> **관련 문서**: [../specs/01-SPEC.md](../specs/01-SPEC.md) · [../specs/21-DATA_MODEL.md](../specs/21-DATA_MODEL.md) · [40-COURSE_DB_SCHEMA.md](40-COURSE_DB_SCHEMA.md) · [41-COURSE_DB_PIPELINE.md](41-COURSE_DB_PIPELINE.md) · [../README.md](../README.md)

> **라운드온 (Round-On)** 앱용 한국 골프장 데이터셋
> 빌드일: 2026-05-12 (v3)
> 데이터 출처: OpenStreetMap (ODbL 라이선스) + 공공데이터 + 카카오 enrichment

---

## 패키지 구성

| 파일 | 용도 |
|------|------|
| **`courses.json`** | **앱 번들에 포함할 파일** (965곳, minified) |
| `courses_seed_v3.json` | v3 원본 데이터 |
| `40-COURSE_DB_SCHEMA.md` | JSON 스키마 명세 + Swift 코드 예시 |
| `41-COURSE_DB_PIPELINE.md` | 데이터 수집 파이프라인 전 과정 문서 |

---

## 빠른 시작

### 1. iOS 앱 번들에 추가

```
1) courses.json 을 Xcode 프로젝트에 드래그
2) "Copy items if needed" 체크, 앱 타겟 선택
3) 40-COURSE_DB_SCHEMA.md의 Swift 코드 예시 참고
```

### 2. 핵심 사용 패턴

```swift
// 앱 시작 시 1회 로드
let repo = CourseRepository.shared  // 965곳 메모리에

// F1: 자동 매칭 (현재 위치에서 가장 가까운 골프장)
let nearest = repo.nearestCourse(to: currentLocation)
// → "남서울컨트리클럽" 등 반환 (반경 3km 이내)

// F3: 골프장+서브코스 단위 감지 (홀 단위 자동 감지는 미제공)
// dataQuality 기반 분기 처리 필수
if nearest?.dataQuality == .complete || nearest?.dataQuality == .partial {
    // 홀별 정보 보유 — SubCourse 표시 가능
} else {
    // low (941곳): 골프장 감지만 동작, 수동 홀 진행 모드
}
```

---

## 데이터 요약 (v3, 2026-05-12 빌드)

- **965곳 한국 골프장** (실제 코스, OSM + 공공데이터 + 카카오 enrichment)
- **위치 정보**: 모든 골프장에 클럽하우스 좌표 보유
- **서브코스**: 27/36홀 골프장 387곳은 `SubCourse` 모델 지원 (v3 데이터에 서브코스 좌표 미포함, 후속 보강 예정)

### dataQuality 분포

| 등급 | 곳 수 | 설명 | F3 동작 |
|------|------|------|--------|
| `complete` | 3곳 (0.31%) | 18홀 완전 매핑 + 모든 par | 골프장+서브코스 감지 |
| `partial` | 12곳 | 9홀 이상 매핑 | 골프장+서브코스 감지 |
| `minimal` | 9곳 | 1~8홀 매핑 | 골프장 감지 |
| `low` | 941곳 | 클럽하우스 좌표만 | 골프장 감지만 동작 |

**F3 GPS 자동 감지 — 골프장 + 서브코스 단위 (홀 단위 자동 감지는 미제공, 수동 진행)**

### 지역별 분포 (v3, 965곳)

경기 188 / 경북 66 / 전남 59 / 경남 49 / 강원 48 / 충북 45 / 전북 30 / 제주 28 / 충남 27 / 인천 17 / 광주 13 / 울산 11 / 대구 10 / 부산 10 / 서울 9 / 세종 7 / 대전 6 / 기타

---

## 데이터 갱신

### OSM 데이터 재수집 + 재빌드

```bash
cd scripts/
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

좌표계 변환 (EPSG:5174 → WGS84) 필요. 자세한 내용은 `41-COURSE_DB_PIPELINE.md §9.1` 참고.

---

## 라이선스

이 데이터는 **OpenStreetMap 기여자들의 데이터**를 가공한 결과물이며, **ODbL 1.0** 라이선스를 따릅니다.

앱 내 **설정 → 정보 → 사용된 오픈소스/데이터**에 다음 표기 필수:

```
© OpenStreetMap contributors, ODbL 1.0
https://www.openstreetmap.org/copyright
```

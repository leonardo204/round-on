# 41 - 한국 골프장 DB 수집 파이프라인

> **관련 문서**: [../specs/01-SPEC.md](../specs/01-SPEC.md) · [../specs/21-DATA_MODEL.md](../specs/21-DATA_MODEL.md) · [40-COURSE_DB_SCHEMA.md](40-COURSE_DB_SCHEMA.md) · [README.md](README.md) · [../README.md](../README.md)

> **목적**: 한국 골프장 데이터를 수집·통합·갱신하는 전 과정 문서  
> **재현 가능성**: 이 문서대로 실행하면 동일한 `courses_seed_v3.json` 재생성 가능  
> **마지막 빌드**: 2026-05-12 (v3, 965곳 — 좌표 중복 통합 후)

---

## 1. 파이프라인 개요

```
┌─────────────────────────────────────────────────────┐
│  Stage 1: OpenStreetMap 데이터 수집 (Overpass API)   │
│  ───────────────────────────────────────────────   │
│  • 한국 leisure=golf_course polygon              │
│  • golf=hole way geometry                        │
│  • golf=tee/green/clubhouse polygon              │
│  • 한국 admin_level=4 광역시도 boundary           │
└────────────────────┬────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────┐
│  Stage 2: 광역시도 polygon 빌드                     │
│  ───────────────────────────────────────────────   │
│  • outer way line들을 linemerge → polygonize     │
│  • 17개 광역시도 polygon 생성                       │
│  • 200m buffer 적용 (경계선 인접 골프장 포함)        │
└────────────────────┬────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────┐
│  Stage 3: 골프장 단위 feature 매칭                  │
│  ───────────────────────────────────────────────   │
│  • hole/tee/green/clubhouse가 어느 골프장 안에     │
│    있는지 point-in-polygon으로 매칭                │
│  • hole way의 시작/끝 노드를 티/그린 좌표로 추출    │
└────────────────────┬────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────┐
│  Stage 4: 공공데이터 통합 (v3 신규)                  │
│  ───────────────────────────────────────────────   │
│  • 문화체육관광부 + 행안부 + 국토부 다단계 통합       │
│  • OSM 미수록 골프장 보충 (546 → 중간 1,163곳 → 좌표 중복 통합 후 965곳) │
│  • holesCount / courseType 필드 채움               │
└────────────────────┬────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────┐
│  Stage 5: 카카오 로컬 API enrichment (v3 신규)      │
│  ───────────────────────────────────────────────   │
│  • 골프장 이름 검색 → phone / kakaoPlaceUrl 채움   │
│  • 664/965 골프장에 enrichment 적용                │
└────────────────────┬────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────┐
│  Stage 6: 시설 타입 분류 + 품질 평가                │
│  ───────────────────────────────────────────────   │
│  • 이름 키워드로 course/practice/screen/park 분류  │
│  • 홀 매칭 수에 따라 complete/partial/minimal/low │
└────────────────────┬────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────┐
│  Stage 7: JSON 출력                                 │
│  ───────────────────────────────────────────────   │
│  • courses_seed_v3.json (앱 번들용, 965곳)         │
│  • courses_seed_v3_report.json (품질 리포트)       │
└─────────────────────────────────────────────────────┘
```

> **XcodeGen 연동**: production 빌드 산출물(`courses.json`)을 `project.yml`의 `resources:` 섹션에 등록하는 단계는 [TODO] — 구현 단계에서 처리.

---

## 2. 환경 / 의존성

### 2.1 시스템 요구사항
- Python 3.10+
- curl (HTTP 요청)
- 인터넷 연결 (Overpass API 호출용)

### 2.2 Python 패키지

```bash
pip install shapely
```

내장 라이브러리: `json`, `pickle`, `re`, `math`, `collections`, `datetime`, `statistics`

### 2.3 파일 구조

```
golf-db/
├── build_db.py                          # 메인 스크립트
├── region_polygons.pkl                  # 광역시도 polygon (캐시)
├── (input)
│   ├── golf_courses_geom.json           # OSM 골프장 polygon
│   ├── golf_holes_geom.json             # OSM hole way geometry
│   ├── golf_features_geom.json          # OSM tee/green/clubhouse
│   └── admin_boundaries.json            # OSM 광역시도 boundary
└── (output)
    ├── courses_kr.json                  # 전체 + 디버그 (493 KB)
    ├── courses_kr_production.json       # 앱 번들용 minified (140 KB)
    ├── courses_kr_production_pretty.json # 앱 번들용 pretty (224 KB)
    └── courses_kr_report.json           # 품질 리포트
```

---

## 3. Stage 1: OSM 데이터 수집 (Overpass API)

### 3.1 한국 골프장 polygon 수집

```bash
curl -s -X POST "https://overpass-api.de/api/interpreter" \
  --data-urlencode "data=[out:json][timeout:300];
    area['ISO3166-1'='KR'][admin_level=2]->.kr;
    (
      way['leisure'='golf_course'](area.kr);
      relation['leisure'='golf_course'](area.kr);
    );
    out tags geom;" \
  -o golf_courses_geom.json
```

**결과**: 약 922개 elements, 2.4 MB

### 3.2 골프장 내부 hole way 수집

```bash
curl -s -X POST "https://overpass-api.de/api/interpreter" \
  --data-urlencode "data=[out:json][timeout:300];
    area['ISO3166-1'='KR'][admin_level=2]->.kr;
    (
      way['leisure'='golf_course'](area.kr);
      relation['leisure'='golf_course'](area.kr);
    );
    map_to_area->.courses;
    (
      way(area.courses)['golf'='hole'];
    );
    out geom;" \
  -o golf_holes_geom.json
```

**결과**: 약 541개 hole way, 315 KB

### 3.3 tee/green/clubhouse polygon 수집

```bash
curl -s -X POST "https://overpass-api.de/api/interpreter" \
  --data-urlencode "data=[out:json][timeout:300];
    area['ISO3166-1'='KR'][admin_level=2]->.kr;
    (
      way['leisure'='golf_course'](area.kr);
      relation['leisure'='golf_course'](area.kr);
    );
    map_to_area->.courses;
    (
      way(area.courses)['golf'='tee'];
      way(area.courses)['golf'='green'];
      way(area.courses)['golf'='clubhouse'];
    );
    out geom;" \
  -o golf_features_geom.json
```

**결과**: tee 1316 + green 1057 + clubhouse 83개 등, 2.9 MB

### 3.4 한국 광역시도 boundary 수집

먼저 admin_level=4 relation 메타데이터를 받아 한국 17개 광역시도 ID를 추출:

```bash
curl -s -X POST "https://overpass-api.de/api/interpreter" \
  --data-urlencode "data=[out:json][timeout:300];
    relation['admin_level'='4']['boundary'='administrative'](32.0,124.0,39.0,132.0);
    out tags;" \
  -o admin4_meta.json
```

한국 광역시도 relation ID (2026-05 기준):

| 이름 | OSM Relation ID |
|------|-----------------|
| 서울특별시 | 2297418 |
| 인천광역시 | 2297419 |
| 경상북도 | 2304454 |
| 경기도 | 2306392 |
| 강원특별자치도 | 2308426 |
| 충청북도 | 2327258 |
| 충청남도 | 2327259 |
| 세종특별자치시 | 2349795 |
| 대전광역시 | 2349984 |
| 전북특별자치도 | 2355168 |
| 경상남도 | 2393403 |
| 대구광역시 | 2395674 |
| 울산광역시 | 2395867 |
| 부산광역시 | 2396450 |
| 전라남도 | 2398104 |
| 제주특별자치도 | 2398560 |
| 광주광역시 | 2399220 |

geometry 포함해 한 번에 받기:

```bash
curl -s -X POST "https://overpass-api.de/api/interpreter" \
  --data-urlencode "data=[out:json][timeout:300];
    (
      relation(2297418);relation(2297419);relation(2304454);relation(2306392);
      relation(2308426);relation(2327258);relation(2327259);relation(2349795);
      relation(2349984);relation(2355168);relation(2393403);relation(2395674);
      relation(2395867);relation(2396450);relation(2398104);relation(2398560);
      relation(2399220);
    );
    out geom;" \
  -o admin_boundaries.json
```

**결과**: 17개 boundary relation, 약 5 MB

---

## 4. Stage 2: 광역시도 polygon 빌드

OSM relation은 outer way가 조각조각 끊어진 LineString으로 들어오므로, `linemerge` + `polygonize`로 완전한 polygon을 만들어야 합니다.

```python
import json
from shapely.geometry import LineString, MultiLineString
from shapely.ops import polygonize, unary_union, linemerge

short_name = {
    '서울특별시': '서울', '인천광역시': '인천', '경상북도': '경북',
    '경기도': '경기', '강원특별자치도': '강원', '충청북도': '충북',
    '충청남도': '충남', '세종특별자치시': '세종', '대전광역시': '대전',
    '전북특별자치도': '전북', '경상남도': '경남', '대구광역시': '대구',
    '울산광역시': '울산', '부산광역시': '부산', '전라남도': '전남',
    '제주특별자치도': '제주', '광주광역시': '광주',
}

with open('admin_boundaries.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

regions = {}
for rel in data['elements']:
    name = rel.get('tags', {}).get('name')
    if name not in short_name:
        continue
    lines = []
    for m in rel.get('members', []):
        if m.get('type') == 'way' and m.get('role') == 'outer' and m.get('geometry'):
            coords = [(p['lon'], p['lat']) for p in m['geometry']]
            if len(coords) >= 2:
                lines.append(LineString(coords))
    merged = linemerge(MultiLineString(lines))
    polys = list(polygonize(merged))
    if polys:
        regions[short_name[name]] = unary_union(polys)

import pickle
with open('region_polygons.pkl', 'wb') as f:
    pickle.dump(regions, f)
```

**결과**: 17개 광역시도 polygon → `region_polygons.pkl` (캐시)

---

## 5. Stage 3: 골프장 단위 feature 매칭

### 5.1 골프장 polygon 추출

- `way` 타입: outer ring을 그대로 Polygon으로
- `relation` 타입: outer role way들의 outer ring을 모아 MultiPolygon

자기교차 polygon은 `buffer(0)`으로 보정.

### 5.2 feature → 골프장 매칭 (point-in-polygon)

각 hole/tee/green/clubhouse의 대표점(첫 노드)이 어느 골프장 polygon 안에 들어가는지 검사.

```python
from shapely.geometry import Point

def assign_features_to_courses(features_data, course_polygons):
    assignments = defaultdict(list)
    unassigned = 0
    for e in features_data['elements']:
        g = e.get('geometry', [])
        if not g:
            continue
        pt = Point(g[0]['lon'], g[0]['lat'])
        matched = None
        for cid, (poly, _) in course_polygons.items():
            if poly.contains(pt) or poly.touches(pt):
                matched = cid
                break
        if matched:
            assignments[matched].append({...})
        else:
            unassigned += 1
    return assignments, unassigned
```

**결과**:
- hole 매칭: 493개 / 미매칭: 48개
- feature 매칭: 1,990개 / 미매칭: 287개

### 5.3 hole 레코드 빌드

각 `golf=hole` way의 시작/끝 노드를 티/그린으로 사용하되, 100m 이내에 별도의 `golf=tee` 또는 `golf=green` polygon이 있으면 그 polygon의 centroid를 사용.

```python
def build_hole_record(hole_feat, tee_feats, green_feats):
    g = hole_feat['geometry']
    start = g[0]   # 티박스 방향
    end = g[-1]    # 그린 방향
    
    nearest_tee = find_nearest(start, tee_feats, max_dist=100)
    nearest_green = find_nearest(end, green_feats, max_dist=100)
    
    return {
        'number': int(hole_feat['ref']) if hole_feat.get('ref') else None,
        'par': int(hole_feat['par']) if hole_feat.get('par') else None,
        'tee': nearest_tee or {'lat': start['lat'], 'lng': start['lon']},
        'green': nearest_green or {'lat': end['lat'], 'lng': end['lon']},
    }
```

---

## 6. Stage 4: 시설 타입 분류 + 품질 평가

### 6.1 facilityType 분류 로직

```python
def classify_facility(name, hole_count, tags):
    if '스크린골프' in name: return 'screen'
    if '파크골프' in name or tags.get('golf') == 'park_golf': return 'park_golf'
    if '연습장' in name or tags.get('golf') == 'driving_range': return 'practice'
    if '실내골프' in name: return 'practice'
    if any(s in name for s in ['CC', '컨트리클럽', '골프클럽', 'GC', 'Country Club', 'Golf Club']):
        return 'course'
    return 'course'  # 기본값
```

### 6.2 dataQuality 평가

```python
n_holes = len(hole_records)
n_par = sum(1 for h in hole_records if h.get('par'))

if n_holes >= 18 and n_par >= 18:
    quality = 'complete'
elif n_holes >= 9:
    quality = 'partial'
elif n_holes > 0:
    quality = 'minimal'
else:
    quality = 'low'
```

---

## 7. 빌드 실행 방법

### 7.1 처음부터 전체 빌드

```bash
cd golf-db/

# 1) OSM 데이터 다운로드 (4개 파일)
bash fetch_osm.sh    # 또는 위 curl 명령들 순차 실행

# 2) 광역 polygon 빌드 (region_polygons.pkl 생성)
python3 build_regions.py

# 3) 메인 빌드
python3 build_db.py
```

### 7.2 OSM raw 파일이 이미 있는 경우

```bash
python3 build_db.py
```

### 7.3 출력 확인

> **참고**: 아래 출력 샘플은 v2 빌드(OSM 전용, 623개) 기준의 역사적 참조입니다. v3(2026-05-12)는 좌표 중복 통합 후 965개입니다 (공공데이터 통합 중간단계: 1,163곳 → 중복 제거 후 965곳).

```
[1/5] 골프장 polygon 로드...
  골프장 polygon 추출: 884개 (전체 922개 중)

[2/5] hole way geometry 로드 + 매칭...
  hole 매칭: 493개 / 미매칭: 48개

[3/5] tee/green/clubhouse 매칭...
  feature 매칭: 1990개 / 미매칭: 287개

[4/5] 골프장 레코드 빌드...
  최종 골프장 레코드: 623개  ← v2 OSM 전용 수치 (v3: 965개 — 좌표 중복 통합 후)

[5/5] JSON 저장...
  ✅ courses_kr.json 저장 완료

=== 데이터 품질 리포트 (v2 기준, 역사적 참조) ===
전체 골프장: 623개  ← v2 수치 (v3: 965개 — 좌표 중복 통합 후)

시설 타입 (v2):
  course: 546개  ← v2 수치 (v3에서는 공공데이터+카카오 enrichment + 중복 통합으로 965개)
  practice: 57개
  park_golf: 14개
  screen: 6개

품질 (v2):
  low: 601개
  partial: 11개
  minimal: 8개
  complete: 3개

지역별:
  경기: 188개
  경북: 66개
  ...
```

---

## 8. 데이터 품질 현황 (현실)

### 8.1 v3 데이터 품질 현황

**OSM에서 한국 골프장의 홀별 매핑은 매우 미진합니다.** 18홀 전체가 매핑된 골프장은 단 3곳입니다. v3는 공공데이터 + 카카오 enrichment 및 좌표 중복 통합으로 최종 965곳을 제공합니다.

| 상태 | 개수 | 비율 |
|------|------|------|
| 18홀 완전 매핑 (complete) | 3 | 0.31% |
| 9홀 이상 매핑 (partial) | 12 | 1.2% |
| 1~8홀 매핑 (minimal) | 9 | 0.9% |
| 골프장 위치만 (low) | 941 | 97.5% |

이는 OSM의 한국 매핑 우선순위가 도시/관광지 위주이고, 골프장 내부 디테일까지 매핑하는 매퍼가 적기 때문입니다.

### 8.2 실용성 평가 (v3 기준)

| 앱 기능 | 영향 |
|---------|------|
| F1 골프장 GPS 자동 매칭 | ✅ **모든 965곳에서 정상 작동** |
| F3 골프장+서브코스 GPS 감지 | ✅ 모든 965곳에서 골프장 단위 감지 동작 (홀 단위 자동 감지 미제공) |
| F4 타수 카운터 | ✅ 데이터와 무관, 항상 동작 |
| 수동 홀 진행 모드 | ✅ 모든 코스에서 디폴트 — 사용자가 스와이프/탭으로 다음 홀 이동 |

> MVP 출시에는 충분합니다. 서브코스 라벨 보강은 P2 단계에서 진행.

---

## 9. 향후 데이터 보강 방안

### 9.1 한국 공공데이터 통합 (완료 — v3에 반영)

**v3에서 문체부 + 행안부 + 카카오 로컬 API 다단계 통합 완료.** 546곳(OSM) → 965곳(v3, 좌표 중복 통합 후)으로 확대.  
카카오 enrichment: 664/965 골프장에 phone/kakaoPlaceUrl 채워짐.

| 데이터셋 | URL | 활용 |
|----------|-----|------|
| 행정안전부_골프장 | https://www.data.go.kr/data/15045080/fileData.do | 인허가 상태, 사업장명, 소재지, EPSG:5174 좌표 |
| 문화체육관광부_전국 골프장 현황 | https://www.data.go.kr/data/15118920/fileData.do | 업소명, 총면적, **홀수** |
| 국토교통부_골프장현황도 | https://www.data.go.kr/data/15015052/openapi.do | 추가 메타 정보 |

**좌표계 변환 (EPSG:5174 → WGS84)**:
```python
from pyproj import Transformer
t = Transformer.from_crs("EPSG:5174", "EPSG:4326", always_xy=True)
lng, lat = t.transform(x_5174, y_5174)
```

이걸 통합하면:
- OSM에 없는 골프장 보충 (전체 600-700개로 확대 추정)
- 홀 수 정보 보강 (대부분 18홀 또는 27홀, 36홀 등 명시)
- 영업 상태 (영업/폐업) 필터링

### 9.2 서브코스 라벨 보강 (우선순위 2 — 진행 예정)

27/36홀 골프장 387곳의 SubCourse.name을 카카오/네이버 또는 수동으로 채운다. v3에서는 SubCourse 구조체가 있으나 holes[]는 비어있음.  
카카오/네이버 맵 API 골프장 검색 → 코스명(동/서/남/북 또는 전반/후반) 추출 → subCourses[].name에 반영.

```python
# 카카오 로컬 API 예시
import requests
headers = {'Authorization': 'KakaoAK {REST_API_KEY}'}
res = requests.get(
    'https://dapi.kakao.com/v2/local/search/keyword.json',
    params={'query': '남서울컨트리클럽'},
    headers=headers
)
```

### 9.3 홀별 좌표 점진 매핑 (우선순위 3)

자체 어드민 도구(React + Leaflet) 제작 후, 위성 지도에 클릭으로 티/그린 좌표 찍기.

```
Course Admin Tool
├── 지도 표시 (Leaflet + 위성 타일)
├── 골프장 선택 → 화면 줌인
├── 클릭 → 티/그린 좌표 추가
├── 홀 번호 + 파 입력
└── JSON 다운로드 (build_db.py 입력으로 합류)
```

### 9.4 사용자 제보 반영 (우선순위 4, 지속)

앱에 두 가지 버튼:
- "이 골프장이 목록에 없어요" → 백엔드 큐에 저장
- "현재 홀이 잘못 인식돼요" → 사용자 GPS 좌표 + 골프장 ID 수집

월간 누적 데이터를 분석해 다음 빌드에 반영.

---

## 10. 빌드 캐시 / 재현성

### 10.1 입력 파일 버전 고정

OSM 데이터는 실시간 갱신되므로, 재현성을 위해 다운로드 시각을 기록합니다.

```json
{
  "version": "0.6",
  "generator": "Overpass API",
  "osm3s": {
    "timestamp_osm_base": "2026-05-11T02:26:15Z"
  }
}
```

각 JSON의 `osm3s.timestamp_osm_base` 필드를 확인.

### 10.2 결정론적 빌드

`build_db.py`는 입력이 동일하면 동일한 출력을 생성합니다 (순서는 OSM ID 순서로 정렬됨).

해시 검증:
```bash
sha256sum courses_kr_production.json
```

---

## 11. 트러블슈팅

### 11.1 Overpass API 504 Timeout

대용량 쿼리는 timeout 발생 가능. 해결:
- `[timeout:600]` 으로 늘림
- 광역시도별로 나눠서 쿼리 후 합치기
- 또는 https://overpass.kumi.systems/api/interpreter (mirror) 사용

### 11.2 region_polygons.pkl 호환성 문제

shapely 버전이 다르면 pickle 호환이 깨질 수 있음.

```bash
# 안전한 재빌드
rm region_polygons.pkl
python3 build_regions.py
```

### 11.3 한국 정부 사이트 접근 불가

```
curl: TLS_error_end
```

자동화 환경에서 한국 정부 사이트는 SSL handshake가 차단되는 경우가 있음. 브라우저로 직접 다운로드 필요.

---

## 12. 라이선스 / 출처 명시

### 12.1 OSM (ODbL)

이 데이터는 **OpenStreetMap 기여자들이 만든 데이터**를 가공한 결과물입니다.

```
Source: OpenStreetMap, ODbL 1.0
© OpenStreetMap contributors
https://www.openstreetmap.org/copyright
```

앱 내 표기 필수.

### 12.2 향후 추가 데이터 라이선스

- 공공데이터포털: 공공누리 1유형 (출처표시, 상업적 이용 가능)
- 카카오 로컬 API: 카카오 디벨로퍼스 약관 준수
- 사용자 제보 데이터: 앱 이용약관에 데이터 사용 동의 포함 필요

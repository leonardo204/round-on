# 40 - 한국 골프장 DB 스키마

> **관련 문서**: [../specs/01-SPEC.md](../specs/01-SPEC.md) · [../specs/21-DATA_MODEL.md](../specs/21-DATA_MODEL.md) · [41-COURSE_DB_PIPELINE.md](41-COURSE_DB_PIPELINE.md) · [README.md](README.md) · [../README.md](../README.md)

> **목적**: **라운드온 (Round-On)** 앱이 사용하는 한국 골프장 데이터 JSON 스키마 명세
> **버전**: 2026.05.12-v3  
> **데이터 소스**: OpenStreetMap (ODbL 라이선스) + 공공데이터 + 카카오 enrichment  
> **파일**: `courses_seed_v3.json`

---

## 1. 개요

이 문서는 골프 스코어 카운터 앱이 사용하는 **한국 골프장 데이터 JSON**의 스키마를 정의합니다.

- **앱 번들 파일명**: `courses.json` (`courses_seed_v3.json`을 이름만 변경)
- **크기**: 약 727 KB (minified 추정)
- **인코딩**: UTF-8
- **레코드 수**: 965개 (실제 코스, OSM + 공공데이터 + 카카오 enrichment, 좌표 중복 통합 후)

> **포함되지 않은 것**: 연습장(57개), 파크골프장(14개), 스크린골프(6개)는 별도 파일로 분리 가능하지만 MVP에서는 제외.

---

## 2. 최상위 구조

```typescript
interface CourseDB {
  version: string;          // "2026.05.12-v3"
  generatedAt: string;      // ISO8601, 빌드 시각
  source: string;           // "OpenStreetMap + 공공데이터 + 카카오 enrichment"
  license: string;          // ODbL 표기
  totalCourses: number;     // 965
  courses: Course[];
}
```

### 예시
```json
{
  "version": "2026.05.12-v3",
  "generatedAt": "2026-05-12T00:00:00.000000+00:00",
  "source": "OpenStreetMap via Overpass API + 공공데이터포털 + 카카오 로컬 API",
  "license": "Open Database License (ODbL) — © OpenStreetMap contributors",
  "totalCourses": 965,
  "courses": [ /* ... 965개 Course 객체 ... */ ]
}
```

---

## 3. Course 스키마

```typescript
interface Course {
  id: string;               // slug형 고유 ID (예: "남서울컨트리클럽")
  name: string;             // 한글 또는 영문 표시명
  region: string;           // 광역시도 단축명 ("경기", "서울", ...)
  address: string | null;   // OSM addr:* 조합 (대부분 null)
  website: string | null;   // 공식 홈페이지 URL
  phone: string | null;     // 전화번호 (카카오 enrichment — 664/965개 채워짐)
  holesCount: number | null; // 총 홀 수 (nil 638곳: 라운드 시작 시 사용자 입력)
  courseType: string | null; // "CC", "GC", "리조트", "퍼블릭" 등
  kakaoPlaceUrl: string | null; // 카카오 장소 URL (카카오 enrichment)
  clubhouse: LatLng;        // 클럽하우스 좌표 (없으면 polygon centroid)
  subCourses: SubCourse[];  // 서브코스 목록 (27/36홀 골프장 387곳 — v3에서는 name만 포함, holes 비어있음)
  holes: Hole[];            // 홀별 정보 (0~18개)
  dataQuality: "complete" | "partial" | "minimal" | "low" | "unknown";
}

interface SubCourse {
  name: string;             // 서브코스 라벨 (동/서/남/북 또는 전반/후반) — v3 후속 보강 필요
  holes: Hole[];            // 해당 서브코스 홀 정보 (v3에서는 빈 배열)
}

interface LatLng {
  lat: number;  // WGS84 위도 (소수점 6~7자리)
  lng: number;  // WGS84 경도
}

interface Hole {
  number: number | null;    // 홀 번호 1~18 (OSM ref 태그)
  par: number | null;       // 3 / 4 / 5 (OSM par 태그, 없으면 null)
  tee: LatLng;              // 티박스 좌표
  green: LatLng;            // 그린 좌표
}
```

### 실제 데이터 예시 (남서울컨트리클럽)

```json
{
  "id": "남서울컨트리클럽",
  "name": "남서울컨트리클럽",
  "region": "경기",
  "address": null,
  "website": null,
  "phone": null,
  "clubhouse": {
    "lat": 37.37994,
    "lng": 127.08534
  },
  "holes": [
    {
      "number": 1,
      "par": 4,
      "tee":   { "lat": 37.37830, "lng": 127.08037 },
      "green": { "lat": 37.38126, "lng": 127.08195 }
    },
    {
      "number": 2,
      "par": 4,
      "tee":   { "lat": 37.37808, "lng": 127.08134 },
      "green": { "lat": 37.37988, "lng": 127.08516 }
    }
  ],
  "dataQuality": "complete"
}
```

---

## 4. region 필드 - 광역시도 코드

```typescript
type Region = 
  | "서울" | "부산" | "대구" | "인천" | "광주" | "대전" | "울산" | "세종"
  | "경기" | "강원" | "충북" | "충남" | "전북" | "전남" | "경북" | "경남" | "제주"
  | "기타";  // 매우 드묾, polygon 매칭 실패
```

OSM의 광역시도 boundary polygon으로 정확하게 매칭됨 (point-in-polygon, 200m buffer).

### 지역별 분포 (실제 데이터)

| 지역 | 골프장 수 |
|------|----------|
| 경기 | 188 |
| 경북 | 66 |
| 전남 | 59 |
| 경남 | 49 |
| 강원 | 48 |
| 충북 | 45 |
| 전북 | 30 |
| 제주 | 28 |
| 충남 | 27 |
| 인천 | 17 |
| 광주 | 13 |
| 울산 | 11 |
| 대구 | 10 |
| 부산 | 10 |
| 서울 | 9 |
| 세종 | 7 |
| 대전 | 6 |

---

## 5. dataQuality 필드

홀별 정보의 완성도를 나타냅니다. 앱 로직에서 분기 처리에 사용. v3 기준 (965곳).

| 값 | 의미 | 개수 | 비율 | 앱 동작 |
|-----|------|------|------|---------|
| `complete` | 18홀 모두 매핑 + 모든 par 정보 | 3 | 0.31% | F3 골프장+서브코스 GPS 감지 + complete 3곳 (전체의 0.31%) |
| `partial` | 9홀 이상 매핑 | 12 | 1.2% | 수동 홀 진행, partial 코스 정보 참고 |
| `minimal` | 1~8홀 매핑 | 9 | 0.9% | 수동 홀 진행 |
| `low` | 홀 정보 없음 (clubhouse만) | 941 | 97.5% | F1(골프장+서브코스 GPS 감지)만 동작, 홀 전부 수동 |
| `unknown` | 분류 미정 | — | — | 안전 fallback, 수동 홀 진행 |

> F3 GPS 자동 감지 — 골프장 + 서브코스 단위 (홀 단위 자동 감지는 미제공, 수동 진행). 자세한 내용은 `41-COURSE_DB_PIPELINE.md` 참고.

---

## 6. Hole 매칭 상세

각 Hole 객체의 `tee`/`green` 좌표는 다음 우선순위로 결정됩니다.

### tee 좌표 결정 로직
1. `golf=hole` way의 시작 노드 좌표
2. 그 좌표에서 100m 이내에 `golf=tee` polygon이 있으면, tee polygon의 centroid로 교체
3. 그 외엔 hole way 시작 노드 그대로

### green 좌표 결정 로직
1. `golf=hole` way의 끝 노드 좌표
2. 그 좌표에서 100m 이내에 `golf=green` polygon이 있으면, green polygon의 centroid로 교체
3. 그 외엔 hole way 끝 노드 그대로

> `golf=hole` way는 OSM 위키 정의상 **티에서 그린까지의 정중앙 라인**이므로 시작/끝 노드가 각각 티/그린 위치에 가깝습니다.

---

## 7. 앱에서의 로딩 패턴

### 7.1 Swift / iOS

```swift
import Foundation

struct CourseDB: Decodable {
    let version: String
    let generatedAt: String
    let totalCourses: Int
    let courses: [Course]
}

struct Course: Decodable, Identifiable {
    let id: String
    let name: String
    let region: String
    let address: String?
    let website: String?
    let phone: String?            // 카카오 enrichment (664/965 채워짐)
    let holesCount: Int?          // nil 638곳 → 라운드 시작 시 사용자 입력
    let courseType: String?       // "CC", "GC" 등
    let kakaoPlaceUrl: String?    // 카카오 장소 URL
    let clubhouse: LatLng
    let subCourses: [SubCourse]?  // 서브코스 목록 (v3에서 holes 비어있음, 후속 보강)
    let holes: [Hole]
    let dataQuality: DataQuality
}

struct SubCourse: Decodable {
    let name: String              // 서브코스 라벨 (동/서/남/북 또는 전반/후반)
    let holes: [Hole]             // v3에서는 빈 배열
}

struct LatLng: Decodable, Hashable {
    let lat: Double
    let lng: Double
}

struct Hole: Decodable {
    let number: Int?
    let par: Int?
    let tee: LatLng
    let green: LatLng
}

enum DataQuality: String, Decodable {
    case complete  // 3곳 (전체의 0.31%)
    case partial   // 12곳
    case minimal   // 9곳
    case low       // 941곳
    case unknown   // 분류 미정 — 안전 fallback
}

// 앱 시작 시 1회 로드
final class CourseRepository {
    static let shared = CourseRepository()
    let db: CourseDB
    
    init() {
        guard let url = Bundle.main.url(forResource: "courses", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(CourseDB.self, from: data) else {
            fatalError("courses.json 로드 실패")
        }
        self.db = decoded
    }
}
```

### 7.2 골프장 자동 매칭 (F1)

```swift
import CoreLocation

extension CourseRepository {
    /// 현재 위치에서 가장 가까운 골프장 반환 (3km 이내).
    func nearestCourse(to location: CLLocation, maxDistanceMeters: Double = 3000) -> Course? {
        var nearest: (Course, Double)? = nil
        for course in db.courses {
            let courseLoc = CLLocation(
                latitude: course.clubhouse.lat,
                longitude: course.clubhouse.lng
            )
            let distance = location.distance(from: courseLoc)
            if distance <= maxDistanceMeters {
                if nearest == nil || distance < nearest!.1 {
                    nearest = (course, distance)
                }
            }
        }
        return nearest?.0
    }
}
```

### 7.3 서브코스 감지 (F3) — 홀 단위 자동 감지 미제공

> F3 GPS 자동 감지 — 골프장 + 서브코스 단위 (홀 단위 자동 감지는 미제공, 수동 진행)

```swift
extension CourseRepository {
    /// 현재 위치에서 가장 가까운 골프장 반환 — 모든 965곳에서 동작.
    /// holesCount > 18이고 subCourses 존재 시 SubCourseSelector UI를 표시한다.
    func nearestCourseWithSubCourse(to location: CLLocation,
                                    maxDistanceMeters: Double = 3000) -> Course? {
        return nearestCourse(to: location, maxDistanceMeters: maxDistanceMeters)
    }
    
    // nearestHole() 미제공 — 홀 단위 GPS 자동 감지는 구현하지 않음.
    // 모든 코스에서 수동 홀 진행 모드 사용.
}
```

### 7.4 dataQuality 분기

```swift
// 라운드 시작 시
let course = repository.nearestCourse(to: currentLocation)

// F3 GPS 자동 감지 — 골프장 + 서브코스 단위 (홀 단위 자동 감지는 미제공, 수동 진행)
switch course?.dataQuality {
case .complete:
    // complete 3곳 (전체의 0.26%): 홀 좌표 완비 — 수동 홀 진행 모드 (홀 단위 자동 감지는 미제공)
    break
case .partial, .minimal:
    // 일부 홀 좌표 보유 — 수동 홀 진행 모드
    break
case .low, .unknown:
    // 클럽하우스 매칭만 — 수동 홀 진행 모드
    break
case .none:
    // 매칭 실패
    break
}
// 모든 코스에서 공통: 수동 홀 진행 모드 — 사용자가 스와이프/탭으로 다음 홀 이동
// holesCount nil 처리: 라운드 시작 시 9/18/27/36 선택 프롬프트 표시
```

---

## 8. 갱신 정책

- **버전 관리**: `version` 필드에 빌드 날짜 명시 (예: `"2026.05.11"`)
- **갱신 주기**: 분기별 1회 재빌드 권장 (OSM 데이터가 점진 개선됨)
- **사용자 제보 반영**: 별도 백엔드 큐 또는 GitHub Issue로 받아 다음 빌드에 반영
- **앱 업데이트 시 갱신**: JSON은 앱 번들 포함이므로 별도 서버 호출 불필요 (오프라인 동작)
- **장기적 개선**: 차후 원격 갱신 (CDN에서 최신 JSON 다운로드) 옵션도 고려 가능

---

## 9. 라이선스 표기

OpenStreetMap 데이터를 사용하므로 **ODbL** 라이선스 조항에 따라 앱 내 어딘가에 다음 표기가 필요합니다.

### 권장 표기 위치
- 설정 → 정보 → "사용된 오픈소스 / 데이터"
- 앱스토어 설명의 마지막 부분

### 표기 예시
```
이 앱은 OpenStreetMap 기여자들의 데이터를 사용합니다.
© OpenStreetMap contributors, ODbL 1.0
https://www.openstreetmap.org/copyright
```

---

## 10. 검증 / 테스트

### 10.1 데이터 무결성 검증 스크립트

```python
import json
from pathlib import Path

def validate(path: Path):
    db = json.loads(path.read_text(encoding='utf-8'))
    
    assert db['totalCourses'] == len(db['courses'])
    
    for c in db['courses']:
        # 필수 필드
        assert c['id'], "id missing"
        assert c['name'], f"{c['id']}: name missing"
        assert c['region'], f"{c['id']}: region missing"
        assert -90 <= c['clubhouse']['lat'] <= 90
        assert -180 <= c['clubhouse']['lng'] <= 180
        
        # holes
        for h in c['holes']:
            if h.get('number') is not None:
                assert 1 <= h['number'] <= 18
            if h.get('par') is not None:
                assert h['par'] in (3, 4, 5)
            assert -90 <= h['tee']['lat'] <= 90
            assert -180 <= h['tee']['lng'] <= 180
            assert -90 <= h['green']['lat'] <= 90
            assert -180 <= h['green']['lng'] <= 180
        
        # dataQuality
        assert c['dataQuality'] in ('complete', 'partial', 'minimal', 'low')
    
    print(f"✅ {len(db['courses'])} courses validated")

validate(Path('courses.json'))
```

### 10.2 단위 테스트 케이스 (Swift)

```swift
import XCTest

final class CourseRepositoryTests: XCTestCase {
    func testLoadCourses() throws {
        let repo = CourseRepository.shared
        XCTAssertGreaterThan(repo.db.courses.count, 900)  // v3: 965곳
        XCTAssertEqual(repo.db.totalCourses, 965)
    }
    
    func testNearestCourseSeoul() {
        // 남서울CC 인근 좌표
        let loc = CLLocation(latitude: 37.380, longitude: 127.085)
        let course = CourseRepository.shared.nearestCourse(to: loc)
        XCTAssertEqual(course?.name, "남서울컨트리클럽")
    }
    
    func testCompleteCoursesHaveAll18Holes() {
        // complete 3곳 (전체의 0.31%)
        let complete = CourseRepository.shared.db.courses.filter {
            $0.dataQuality == .complete
        }
        XCTAssertEqual(complete.count, 3)
        for c in complete {
            XCTAssertEqual(c.holes.count, 18, "\(c.name) should have 18 holes")
            for h in c.holes {
                XCTAssertNotNil(h.par, "\(c.name) hole \(h.number ?? 0) missing par")
            }
        }
    }
    
    func testDataQualityDistribution() {
        let courses = CourseRepository.shared.db.courses
        let low = courses.filter { $0.dataQuality == .low }.count
        let partial = courses.filter { $0.dataQuality == .partial }.count
        let minimal = courses.filter { $0.dataQuality == .minimal }.count
        let complete = courses.filter { $0.dataQuality == .complete }.count
        // v3 기준 분포
        XCTAssertGreaterThan(low, 900)       // 약 941
        XCTAssertGreaterThan(partial, 10)    // 약 12
        XCTAssertGreaterThan(minimal, 7)     // 약 9
        XCTAssertEqual(complete, 3)
    }
}
```

---

## 11. 부록: v2 → v3 마이그레이션 노트 + 시설 타입 분류

### v2 → v3 마이그레이션 노트 (2026-05-12)

v2(`courses_seed_v2.json`, 546곳)에서 v3(`courses_seed_v3.json`, 965곳)으로의 주요 변경 사항:

| 항목 | v2 | v3 |
|------|----|----|
| 레코드 수 | 546곳 | 965곳 (좌표 중복 통합 후) |
| 빌드 날짜 | 2026.05.11 | 2026.05.12 |
| 데이터 소스 | OSM 단독 | OSM + 공공데이터 + 카카오 enrichment |
| 신규 필드 | — | `holesCount`, `courseType`, `phone`, `kakaoPlaceUrl`, `subCourses` |
| dataQuality 분포 | complete 3 / partial 11 / minimal 8 / low 524 (course 타입만) | complete 3 / partial 12 / minimal 9 / low 941 |
| DataQuality enum | `complete/partial/minimal/low` | `complete/partial/minimal/low/unknown` 추가 |
| 카카오 enrichment | 미적용 | 664/965 골프장에 phone/kakaoPlaceUrl 채워짐 |
| SubCourse | 미지원 | 27/36홀 골프장 387곳에 name 추가 (holes는 후속 보강) |

**앱 코드 마이그레이션 체크리스트**:
- `DataQuality` enum에 `.unknown` 케이스 추가
- `Course` struct에 신규 필드 5종 추가 (모두 Optional이므로 하위 호환)
- `SubCourse` struct 신규 추가
- `dataQuality` 분기 로직에서 `.high`/`.medium`/`.full` 등 v2 이전 케이스 제거

### 시설 타입 분류 (v2 기준 참고)

v2 원본에는 다음 4가지 시설 타입이 섞여 있었으며, v3 production JSON은 `course`만 포함합니다.

| facilityType | v2 개수 | 설명 |
|--------------|---------|------|
| `course` | 546 → v3: 965 | 정식 골프장 (18홀/9홀/27홀/36홀 등) ← MVP 타겟 |
| `practice` | 57 | 골프 연습장 (드라이빙 레인지) |
| `park_golf` | 14 | 파크골프장 (실버 골프) |
| `screen` | 6 | 스크린골프장 |

v3 이후 별도 필터로 노출 검토 가능.

---

## 12. v4 — aliases 필드 추가 (2026-05-27)

각 골프장에 영문 alias 1~4개를 부여한 검색 보조 필드.

### 스키마

```json
{
  "id": "벨라스톤cc_강원",
  "name": "벨라스톤컨트리클럽",
  "aliases": ["BELLASTONE", "BELRASEUTON"],
  "region": "강원",
  "clubhouse": { "lat": 37.453, "lng": 127.83 }
}
```

### 목적
- 사용자가 영문 "BELLA", "BELLASTONE" 등으로 라운드를 입력했을 때 매칭 가능하게
- `CourseNameMatcher.normalize` 후 양방향 contains 비교 대상에 포함
- `GolfCourse.searchableKeys()` → `CourseNameMatcher.matches(course:query:)` 연계

### 생성 방법
- 스크립트: `ref-docs/golf-db-pack/build_aliases.py` (idempotent)
- 한글 토큰 → 영문 사전 (도메인 특화) + 한글 자모 RR 음차 결합

### 마이그레이션
- Optional 필드. nil 또는 빈 배열도 정상
- 라이트마이그레이션 안전 (SwiftData 미사용, Codable 디코딩만 영향)
- `GolfCourse.aliases: [String]?` — 기존 memberwise init에 `aliases: [String]? = nil` 추가로 기존 호출자 호환

### v3 → v4 변경 요약

| 항목 | v3 | v4 |
|------|----|----|
| 레코드 수 | 965곳 | 979곳 |
| 신규 필드 | — | `aliases: [String]?` |
| 커버리지 | — | 969/979 골프장에 aliases 추가 |
| GolfCourse struct | — | `aliases`, `searchableKeys()` 추가 |
| CourseNameMatcher | — | `matches(course:query:)` 추가 |

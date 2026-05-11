# 40 - 한국 골프장 DB 스키마

> **목적**: **라운드온 (Round-On)** 앱이 사용하는 한국 골프장 데이터 JSON 스키마 명세
> **버전**: 2026.05.11  
> **데이터 소스**: OpenStreetMap (ODbL 라이선스)  
> **파일**: `courses_kr_production.json`

---

## 1. 개요

이 문서는 골프 스코어 카운터 앱이 사용하는 **한국 골프장 데이터 JSON**의 스키마를 정의합니다.

- **앱 번들 파일명**: `courses.json` (`courses_kr_production.json`을 이름만 변경)
- **크기**: 약 140 KB (minified) / 224 KB (pretty)
- **인코딩**: UTF-8
- **레코드 수**: 546개 (실제 코스, OSM `facilityType=course`)

> **포함되지 않은 것**: 연습장(57개), 파크골프장(14개), 스크린골프(6개)는 별도 파일로 분리 가능하지만 MVP에서는 제외.

---

## 2. 최상위 구조

```typescript
interface CourseDB {
  version: string;          // "2026.05.11"
  generatedAt: string;      // ISO8601, 빌드 시각
  source: string;           // "OpenStreetMap via Overpass API"
  license: string;          // ODbL 표기
  totalCourses: number;     // 546
  courses: Course[];
}
```

### 예시
```json
{
  "version": "2026.05.11",
  "generatedAt": "2026-05-11T02:34:12.345678+00:00",
  "source": "OpenStreetMap via Overpass API",
  "license": "Open Database License (ODbL) — © OpenStreetMap contributors",
  "totalCourses": 546,
  "courses": [ /* ... 546개 Course 객체 ... */ ]
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
  phone: string | null;     // 전화번호
  clubhouse: LatLng;        // 클럽하우스 좌표 (없으면 polygon centroid)
  holes: Hole[];            // 홀별 정보 (0~18개)
  dataQuality: "complete" | "partial" | "minimal" | "low";
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

홀별 정보의 완성도를 나타냅니다. 앱 로직에서 분기 처리에 사용.

| 값 | 의미 | 개수 | 앱 동작 |
|-----|------|------|---------|
| `complete` | 18홀 모두 매핑 + 모든 par 정보 | 3 | F3(홀 자동 감지) 완전 동작 |
| `partial` | 9홀 이상 매핑 | 11 | F3 부분 동작, 누락 홀은 수동 |
| `minimal` | 1~8홀 매핑 | 8 | F3 일부만, 권장 X |
| `low` | 홀 정보 없음 (clubhouse만) | 524 | F1(골프장 매칭)만 동작, 홀은 전부 수동 |

> 524개 골프장이 `low` 품질인 이유는 OSM의 한국 골프장 홀별 매핑률이 낮기 때문입니다. 자세한 내용은 `41-COURSE_DB_PIPELINE.md` 참고.

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
    let phone: String?
    let clubhouse: LatLng
    let holes: [Hole]
    let dataQuality: DataQuality
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
    case complete, partial, minimal, low
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

### 7.3 GPS 홀 자동 감지 (F3)

```swift
extension Course {
    /// 현재 위치에서 가장 가까운 홀 반환 (50m 이내).
    /// dataQuality가 low인 골프장에서는 항상 nil 반환.
    func nearestHole(to location: CLLocation) -> Hole? {
        guard dataQuality != .low else { return nil }
        
        var nearest: (Hole, Double)? = nil
        for hole in holes {
            // 티/그린 두 점 모두 후보 (라운드 시작/종료 어디서든 인식)
            let teeLoc = CLLocation(latitude: hole.tee.lat, longitude: hole.tee.lng)
            let greenLoc = CLLocation(latitude: hole.green.lat, longitude: hole.green.lng)
            let dTee = location.distance(from: teeLoc)
            let dGreen = location.distance(from: greenLoc)
            let d = min(dTee, dGreen)
            
            if d <= 50 {
                if nearest == nil || d < nearest!.1 {
                    nearest = (hole, d)
                }
            }
        }
        return nearest?.0
    }
}
```

### 7.4 dataQuality 분기

```swift
// 라운드 시작 시
let course = repository.nearestCourse(to: currentLocation)

switch course?.dataQuality {
case .complete:
    // 18홀 자동 감지 가능 — 풀 UX
    break
case .partial, .minimal:
    // 일부 홀만 자동 감지 — 안내 메시지
    showToast("이 골프장은 일부 홀만 자동 감지됩니다")
case .low:
    // 클럽하우스 매칭만 — 홀 입력은 전부 수동
    showToast("홀별 자동 감지는 지원되지 않습니다. 홀 번호는 수동으로 변경해주세요.")
case .none:
    // 매칭 실패
    break
}
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
        XCTAssertGreaterThan(repo.db.courses.count, 500)
    }
    
    func testNearestCourseSeoul() {
        // 남서울CC 인근 좌표
        let loc = CLLocation(latitude: 37.380, longitude: 127.085)
        let course = CourseRepository.shared.nearestCourse(to: loc)
        XCTAssertEqual(course?.name, "남서울컨트리클럽")
    }
    
    func testCompleteCoursesHaveAll18Holes() {
        let complete = CourseRepository.shared.db.courses.filter {
            $0.dataQuality == .complete
        }
        for c in complete {
            XCTAssertEqual(c.holes.count, 18, "\(c.name) should have 18 holes")
            for h in c.holes {
                XCTAssertNotNil(h.par, "\(c.name) hole \(h.number ?? 0) missing par")
            }
        }
    }
}
```

---

## 11. 부록: 시설 타입 분류

원본 `courses_kr.json` (623개 전체)에는 다음 4가지 시설 타입이 섞여 있으며, production JSON은 `course`만 포함합니다.

| facilityType | 개수 | 설명 |
|--------------|------|------|
| `course` | 546 | 정식 골프장 (18홀/9홀 등) ← MVP 타겟 |
| `practice` | 57 | 골프 연습장 (드라이빙 레인지) |
| `park_golf` | 14 | 파크골프장 (실버 골프) |
| `screen` | 6 | 스크린골프장 |

V2 이후 별도 필터로 노출 검토 가능.

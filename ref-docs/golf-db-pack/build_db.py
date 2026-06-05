#!/usr/bin/env python3
"""
한국 골프장 OSM 데이터 통합 스크립트

입력:
- golf_courses_geom.json   : 골프장 polygon (way/relation)
- golf_holes_geom.json     : golf=hole way (티→그린 라인)
- golf_features_geom.json  : golf=tee/green/clubhouse polygon들

출력:
- courses_kr.json          : 최종 통합 JSON (앱 번들용)
- courses_kr_report.json   : 수집 통계 및 품질 리포트
"""

import json
from collections import defaultdict
from statistics import mean
from shapely.geometry import Point, Polygon, MultiPolygon, LineString
from shapely.errors import GEOSException


def load_json(path):
    with open(path, 'r', encoding='utf-8') as f:
        return json.load(f)


def way_to_polygon(geom_list):
    """OSM way의 geometry 리스트를 Shapely Polygon으로 변환."""
    coords = [(p['lon'], p['lat']) for p in geom_list]
    if len(coords) < 3:
        return None
    # closed?
    if coords[0] != coords[-1]:
        coords.append(coords[0])
    try:
        return Polygon(coords)
    except Exception:
        return None


def relation_to_multipolygon(element):
    """OSM relation의 members로 MultiPolygon 구성 (outer ways만)."""
    polys = []
    for m in element.get('members', []):
        if m.get('type') == 'way' and m.get('role') == 'outer' and m.get('geometry'):
            poly = way_to_polygon(m['geometry'])
            if poly and poly.is_valid:
                polys.append(poly)
            elif poly:
                # 자기교차 등 → buffer(0) 보정
                fixed = poly.buffer(0)
                if not fixed.is_empty:
                    polys.append(fixed)
    if not polys:
        return None
    if len(polys) == 1:
        return polys[0]
    # 모두 Polygon이면 MultiPolygon, 아니면 첫 것
    if all(p.geom_type == 'Polygon' for p in polys):
        return MultiPolygon(polys)
    return polys[0]


def centroid_of(element):
    """way/relation의 중심 좌표 반환."""
    g = element.get('geometry')
    if g:
        lats = [p['lat'] for p in g]
        lons = [p['lon'] for p in g]
        return (mean(lats), mean(lons))
    # relation: bounds로 추정
    b = element.get('bounds')
    if b:
        return ((b['minlat'] + b['maxlat']) / 2, (b['minlon'] + b['maxlon']) / 2)
    c = element.get('center')
    if c:
        return (c['lat'], c['lon'])
    return None


def build_course_polygons(courses_data):
    """{course_id: (Polygon, raw_element)} 딕셔너리 생성."""
    polygons = {}
    for e in courses_data['elements']:
        cid = f"{e['type']}/{e['id']}"
        if e['type'] == 'way':
            poly = way_to_polygon(e.get('geometry', []))
        elif e['type'] == 'relation':
            poly = relation_to_multipolygon(e)
        else:
            continue
        if poly:
            polygons[cid] = (poly, e)
    return polygons


def assign_features_to_courses(features_data, course_polygons, hole_polygons=None):
    """feature(tee/green/hole/clubhouse)를 골프장에 할당.
    
    course_polygons: {course_id: (Polygon, raw)}
    return: {course_id: [feature_dict, ...]}
    """
    assignments = defaultdict(list)
    unassigned = 0

    for e in features_data['elements']:
        g = e.get('geometry', [])
        # 대표점 = 첫 노드 (또는 holes는 중간 노드)
        if not g:
            continue
        
        rep_lon = g[0]['lon']
        rep_lat = g[0]['lat']
        pt = Point(rep_lon, rep_lat)
        
        # 어느 골프장에 속하는지 찾기
        matched = None
        for cid, (poly, _) in course_polygons.items():
            try:
                if poly.contains(pt) or poly.touches(pt):
                    matched = cid
                    break
            except GEOSException:
                continue
        
        if matched:
            tags = e.get('tags', {})
            feat = {
                'osm_id': f"{e['type']}/{e['id']}",
                'golf': tags.get('golf'),
                'ref': tags.get('ref'),
                'par': tags.get('par'),
                'geometry': g,
            }
            assignments[matched].append(feat)
        else:
            unassigned += 1
    
    return assignments, unassigned


def haversine(lat1, lon1, lat2, lon2):
    """두 점 사이 거리 (미터)."""
    from math import radians, sin, cos, sqrt, atan2
    R = 6371000
    dlat = radians(lat2 - lat1)
    dlon = radians(lon2 - lon1)
    a = sin(dlat/2)**2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(dlon/2)**2
    return 2 * R * atan2(sqrt(a), sqrt(1-a))


def build_hole_record(hole_feat, tee_feats, green_feats):
    """hole way의 시작/끝과 가장 가까운 tee/green을 찾아 매칭."""
    g = hole_feat['geometry']
    if not g or len(g) < 2:
        return None
    
    start = g[0]      # 일반적으로 티박스 방향
    end = g[-1]       # 일반적으로 그린 방향
    
    # tee 중에서 start와 가장 가까운 것
    nearest_tee = None
    if tee_feats:
        best_d = float('inf')
        for tf in tee_feats:
            tg = tf['geometry']
            if not tg:
                continue
            # tee의 centroid
            tlat = mean(p['lat'] for p in tg)
            tlon = mean(p['lon'] for p in tg)
            d = haversine(start['lat'], start['lon'], tlat, tlon)
            if d < best_d and d < 100:  # 100m 이내만
                best_d = d
                nearest_tee = (tlat, tlon)
    
    # green 중에서 end와 가장 가까운 것
    nearest_green = None
    if green_feats:
        best_d = float('inf')
        for gf in green_feats:
            gg = gf['geometry']
            if not gg:
                continue
            glat = mean(p['lat'] for p in gg)
            glon = mean(p['lon'] for p in gg)
            d = haversine(end['lat'], end['lon'], glat, glon)
            if d < best_d and d < 100:
                best_d = d
                nearest_green = (glat, glon)
    
    # par 추정: 명시값 우선, 없으면 None
    par = None
    if hole_feat.get('par'):
        try:
            par = int(hole_feat['par'])
        except ValueError:
            pass
    
    # ref → 홀 번호
    number = None
    if hole_feat.get('ref'):
        try:
            number = int(hole_feat['ref'])
        except ValueError:
            pass
    
    return {
        'number': number,
        'par': par,
        'tee': {'lat': nearest_tee[0], 'lng': nearest_tee[1]} if nearest_tee else {'lat': start['lat'], 'lng': start['lon']},
        'green': {'lat': nearest_green[0], 'lng': nearest_green[1]} if nearest_green else {'lat': end['lat'], 'lng': end['lon']},
        'source': {
            'hole_osm': hole_feat['osm_id'],
            'tee_matched': nearest_tee is not None,
            'green_matched': nearest_green is not None,
        }
    }


def extract_address(tags):
    """tags에서 주소 문자열 조합."""
    parts = []
    for k in ['addr:city', 'addr:district', 'addr:province', 'addr:street', 'addr:housenumber', 'addr:full']:
        if k in tags:
            parts.append(tags[k])
    return ' '.join(parts) if parts else None


def load_region_polygons():
    """광역시도 polygon 로드. 경계선 근처 골프장을 위해 약간의 buffer 적용."""
    import pickle
    with open('region_polygons.pkl', 'rb') as f:
        polys = pickle.load(f)
    # 약 200m 정도 buffer (위경도 0.002 ≈ 220m)
    buffered = {name: poly.buffer(0.002) for name, poly in polys.items()}
    return buffered


REGION_POLYS = load_region_polygons()


def region_of(lat, lon):
    """위경도 → 광역시도 정확 매칭 (point-in-polygon, ~200m buffer).
    여러 광역에 걸치면 가장 가까운 것 선택. 매칭 실패 시 가장 가까운 광역."""
    pt = Point(lon, lat)
    candidates = []
    for name, poly in REGION_POLYS.items():
        try:
            if poly.contains(pt):
                # 광역시(buffer 없이도 포함)는 광역시 우선
                candidates.append((0, name))
            elif poly.intersects(pt.buffer(0.0001)):
                candidates.append((1, name))
        except GEOSException:
            continue
    if candidates:
        candidates.sort()
        return candidates[0][1]
    # 매칭 실패 시 가장 가까운 광역
    best = None
    best_d = float('inf')
    for name, poly in REGION_POLYS.items():
        try:
            d = poly.distance(pt)
            if d < best_d:
                best_d = d
                best = name
        except GEOSException:
            continue
    return best or '기타'


def classify_facility(name, hole_count, tags):
    """이름/태그/홀수로 시설 타입 분류.
    Returns: 'course' | 'practice' | 'screen' | 'park_golf' | 'short_course' | 'unknown'"""
    name_l = (name or '').lower()
    
    # 키워드 기반
    if any(s in name for s in ['스크린골프', '스크린 골프', 'screen golf']):
        return 'screen'
    if '파크골프' in name or 'park golf' in name_l or tags.get('golf') == 'park_golf':
        return 'park_golf'
    if any(s in name for s in ['연습장', '드라이빙 레인지', 'driving range']) or tags.get('golf') == 'driving_range':
        return 'practice'
    if any(s in name for s in ['실내골프', '인도어 골프', '실내 골프']):
        return 'practice'
    
    # 정규 18홀/9홀 코스 키워드
    if any(s in name for s in ['CC', 'C.C', '컨트리클럽', '컨트리 클럽', '골프클럽', '골프 클럽',
                                'GC', 'G.C', 'Golf Club', 'Country Club']):
        return 'course'
    
    # 기본
    return 'course'


def slugify(name, osm_id):
    """ID 생성용 slug."""
    import re
    if not name:
        return osm_id.replace('/', '-')
    # 영문/숫자/한글만 남기고 -로
    s = re.sub(r'[^0-9A-Za-z가-힣]+', '-', name).strip('-').lower()
    if not s:
        s = osm_id.replace('/', '-')
    return s[:50]


# ===================================================
# 메인 실행
# ===================================================
print("[1/5] 골프장 polygon 로드...")
courses_data = load_json('golf_courses_geom.json')
course_polys = build_course_polygons(courses_data)
print(f"  골프장 polygon 추출: {len(course_polys)}개 (전체 {len(courses_data['elements'])}개 중)")

print("\n[2/5] hole way geometry 로드 + 매칭...")
holes_data = load_json('golf_holes_geom.json')
hole_assignments, hole_unassigned = assign_features_to_courses(holes_data, course_polys)
print(f"  hole 매칭: {sum(len(v) for v in hole_assignments.values())}개 / 미매칭: {hole_unassigned}개")

print("\n[3/5] tee/green/clubhouse 매칭...")
features_data = load_json('golf_features_geom.json')
feat_assignments, feat_unassigned = assign_features_to_courses(features_data, course_polys)
print(f"  feature 매칭: {sum(len(v) for v in feat_assignments.values())}개 / 미매칭: {feat_unassigned}개")

print("\n[4/5] 골프장 레코드 빌드...")
courses_final = []
seen_names = set()  # 이름+지역 중복 방지 (relation/way 모두 같은 골프장일 수 있음)
relation_centers = []  # relation 골프장 좌표 (way와 중복 제거용)

# relation 먼저 처리 (멀티폴리곤이 더 정확)
priority_order = sorted(course_polys.items(), key=lambda kv: 0 if kv[0].startswith('relation') else 1)

for cid, (poly, raw) in priority_order:
    tags = raw.get('tags', {})
    name = tags.get('name') or tags.get('name:ko') or tags.get('name:en')
    if not name:
        # 이름 없는 골프장은 스킵
        continue
    
    # 중심 좌표
    centroid = poly.centroid
    lat, lon = centroid.y, centroid.x
    
    # 중복 제거: 같은 이름 + 1km 이내
    is_dup = False
    for prev_name, prev_lat, prev_lon in relation_centers:
        if prev_name == name and haversine(lat, lon, prev_lat, prev_lon) < 1000:
            is_dup = True
            break
    if is_dup:
        continue
    relation_centers.append((name, lat, lon))
    
    region = region_of(lat, lon)
    
    # 이 골프장의 hole/tee/green
    holes_here = [f for f in hole_assignments.get(cid, [])]
    tees_here = [f for f in feat_assignments.get(cid, []) if f['golf'] == 'tee']
    greens_here = [f for f in feat_assignments.get(cid, []) if f['golf'] == 'green']
    clubhouses_here = [f for f in feat_assignments.get(cid, []) if f['golf'] == 'clubhouse']
    
    # hole 레코드 빌드
    hole_records = []
    for h in holes_here:
        rec = build_hole_record(h, tees_here, greens_here)
        if rec and rec['number']:
            hole_records.append(rec)
    
    # 홀 번호 중복 제거 (가장 정보 많은 것 우선)
    by_num = {}
    for r in hole_records:
        n = r['number']
        if n not in by_num or (r['par'] and not by_num[n]['par']):
            by_num[n] = r
    hole_records = sorted(by_num.values(), key=lambda x: x['number'])
    
    # 클럽하우스 좌표
    clubhouse_coord = None
    if clubhouses_here and clubhouses_here[0].get('geometry'):
        cg = clubhouses_here[0]['geometry']
        clubhouse_coord = {
            'lat': mean(p['lat'] for p in cg),
            'lng': mean(p['lon'] for p in cg),
        }
    
    # 주소
    address = extract_address(tags)
    
    # 데이터 품질 레벨
    quality = 'low'
    n_holes_with_par = sum(1 for h in hole_records if h.get('par'))
    n_holes_with_tee = sum(1 for h in hole_records if h['source']['tee_matched'])
    if len(hole_records) >= 18 and n_holes_with_par >= 18:
        quality = 'complete'
    elif len(hole_records) >= 9:
        quality = 'partial'
    elif len(hole_records) > 0:
        quality = 'minimal'
    
    course_record = {
        'id': slugify(name, cid),
        'name': name,
        'nameKo': tags.get('name:ko'),
        'nameEn': tags.get('name:en'),
        'region': region,
        'address': address,
        'website': tags.get('website') or tags.get('contact:website'),
        'phone': tags.get('phone') or tags.get('contact:phone'),
        'osm_id': cid,
        'center': {'lat': lat, 'lng': lon},
        'clubhouse': clubhouse_coord or {'lat': lat, 'lng': lon},
        'facilityType': classify_facility(name, len(hole_records), tags),
        'totalHoles': len(hole_records) if hole_records else (int(tags.get('golf:course_size', 0)) if tags.get('golf:course_size', '').isdigit() else None),
        'holes': hole_records,
        'dataQuality': quality,
        'qualityStats': {
            'holesFound': len(hole_records),
            'holesWithPar': n_holes_with_par,
            'holesWithTeeMatched': n_holes_with_tee,
        }
    }
    courses_final.append(course_record)

print(f"  최종 골프장 레코드: {len(courses_final)}개")

print("\n[5/5] JSON 저장...")
output = {
    'version': '2026.05.11',
    'source': 'OpenStreetMap via Overpass API',
    'license': 'Open Database License (ODbL)',
    'totalCourses': len(courses_final),
    'courses': courses_final,
}

with open('courses_kr.json', 'w', encoding='utf-8') as f:
    json.dump(output, f, ensure_ascii=False, indent=2)

# 리포트
quality_counts = defaultdict(int)
region_counts = defaultdict(int)
facility_counts = defaultdict(int)
facility_x_quality = defaultdict(lambda: defaultdict(int))
for c in courses_final:
    quality_counts[c['dataQuality']] += 1
    region_counts[c['region']] += 1
    facility_counts[c['facilityType']] += 1
    facility_x_quality[c['facilityType']][c['dataQuality']] += 1

report = {
    'totalCourses': len(courses_final),
    'qualityBreakdown': dict(quality_counts),
    'facilityBreakdown': dict(facility_counts),
    'facilityXQuality': {k: dict(v) for k, v in facility_x_quality.items()},
    'regionBreakdown': dict(sorted(region_counts.items(), key=lambda x: -x[1])),
    'note': {
        'quality': 'complete=18홀+모든파, partial=9홀+, minimal=홀 일부, low=홀 정보 없음 (golf course polygon만)',
        'facility': 'course=일반 코스, practice=연습장, screen=스크린골프, park_golf=파크골프',
    }
}
with open('courses_kr_report.json', 'w', encoding='utf-8') as f:
    json.dump(report, f, ensure_ascii=False, indent=2)

print(f"  ✅ courses_kr.json 저장 완료")
print()
print("=== 데이터 품질 리포트 ===")
print(f"전체 골프장: {len(courses_final)}개")
print(f"\n시설 타입:")
for f, n in sorted(facility_counts.items(), key=lambda x: -x[1]):
    print(f"  {f}: {n}개")
print(f"\n품질:")
for q, n in sorted(quality_counts.items(), key=lambda x: -x[1]):
    print(f"  {q}: {n}개")
print(f"\n실제 코스 (facilityType=course)의 품질:")
for q, n in sorted(facility_x_quality['course'].items(), key=lambda x: -x[1]):
    print(f"  {q}: {n}개")
print(f"\n지역별:")
for r, n in sorted(region_counts.items(), key=lambda x: -x[1]):
    print(f"  {r}: {n}개")

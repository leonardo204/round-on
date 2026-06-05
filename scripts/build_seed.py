#!/usr/bin/env python3
"""
라운드온 골프장 시드 데이터 빌더
- 문체부 CSV (525곳) + 행안부 CSV (영업중 필터) + OSM courses.json 머지
- EPSG:5174 (TM 중부원점) → WGS84 좌표 변환 (pyproj)
- 1차: 정규화 이름 매칭
- 2차: 좌표 기반 매칭 (1.2km 이내) — 이름 표기 차이로 누락된 중복 제거
- 출력: ref-docs/golf-db-pack/courses_seed_v2.json (새 시나리오)
"""
from __future__ import annotations
import csv
import json
import math
import re
from collections import defaultdict
from pathlib import Path
from typing import Optional
from pyproj import Transformer

ROOT = Path(__file__).parent.parent
DATA_DIR = ROOT / "ref-docs" / "data"
DB_DIR = ROOT / "ref-docs" / "golf-db-pack"
OUT_PATH = DB_DIR / "courses_seed_v2.json"
REPORT_PATH = DB_DIR / "courses_seed_v2_report.json"

MCST_CSV = DATA_DIR / "문화체육관광부_전국 골프장 현황_20221231.csv"
MOIS_CSV = DATA_DIR / "생활_골프장.csv"
OSM_JSON = DB_DIR / "courses.json"

# 영업중 상태 (행안부) — 출시용 골프장만 채택
# 영업상태명 컬럼 기준 (상세영업상태명은 "영업"/"영업중" 등 비통일)
ACTIVE_STATUS = {"영업/정상", "영업/휴업"}

# 좌표 변환: EPSG:5174 (TM 중부원점, 한국 보정좌표계) → WGS84
transformer = Transformer.from_crs("EPSG:5174", "EPSG:4326", always_xy=True)


COORD_MATCH_THRESHOLD_KM = 1.2  # 좌표 기반 2차 매칭 임계값 (km)


def haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """두 WGS84 좌표 사이의 haversine 거리 (km). 외부 라이브러리 없이 math 모듈로 계산."""
    R = 6371.0  # 지구 반경 (km)
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlam = math.radians(lng2 - lng1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlam / 2) ** 2
    return 2 * R * math.asin(math.sqrt(a))


def normalize_name(name: str) -> str:
    """매칭용 정규화 — 공백/특수문자 제거, 소문자, 일반 약어 처리"""
    if not name:
        return ""
    s = name.strip().lower()
    s = re.sub(r"\s+", "", s)
    s = re.sub(r"[^\w가-힣]", "", s)
    # 흔한 변형 통일
    s = s.replace("컨트리클럽", "cc").replace("골프클럽", "gc").replace("골프장", "")
    s = s.replace("country", "cc").replace("club", "")
    return s


def parse_holes(holes_str: str) -> Optional[int]:
    """홀수 파싱: '18' / '27' / '36' 등"""
    if not holes_str:
        return None
    try:
        n = int(holes_str.strip())
        return n if 1 <= n <= 99 else None
    except ValueError:
        return None


def parse_coord_tm(x: str, y: str):
    """EPSG:5174 (TM) X, Y → WGS84 (lng, lat) 변환"""
    try:
        x_f = float(x.strip())
        y_f = float(y.strip())
        # 0 또는 비정상 값 필터
        if x_f == 0 or y_f == 0:
            return None
        # TM 중부원점 좌표 범위 대략 검증 (한국 영토)
        if not (100000 < x_f < 500000):
            return None
        if not (100000 < y_f < 700000):
            return None
        lng, lat = transformer.transform(x_f, y_f)
        # WGS84 한국 범위 검증 (33-39 lat, 124-132 lng)
        if not (33.0 <= lat <= 39.5):
            return None
        if not (124.0 <= lng <= 132.0):
            return None
        return {"lat": round(lat, 6), "lng": round(lng, 6)}
    except (ValueError, AttributeError):
        return None


def load_mcst() -> list[dict]:
    """문화체육관광부 CSV — 525곳, 홀수 정보 포함"""
    rows = []
    with open(MCST_CSV, encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        for r in reader:
            holes = parse_holes(r["홀수(홀)"])
            rows.append({
                "name": r["업소명"].strip(),
                "name_norm": normalize_name(r["업소명"]),
                "region": r["지역"].strip(),
                "address": r["소재지"].strip(),
                "owner": r["사업자명(대표자)"].strip(),
                "area_m2": int(r["총면적(제곱미터) "].strip()) if r["총면적(제곱미터) "].strip().isdigit() else None,
                "holes_count": holes,
                "course_type": r["세부종류"].strip(),  # 대중제 / 회원제
                "_source": "mcst_2022",
            })
    return rows


def load_mois() -> list[dict]:
    """행안부 LOCALDATA — 영업중만 필터, 좌표 변환. 인코딩: CP949."""
    rows = []
    with open(MOIS_CSV, encoding="cp949") as f:
        reader = csv.DictReader(f)
        for r in reader:
            status = r.get("영업상태명", "").strip()
            if status not in ACTIVE_STATUS:
                continue
            coord = parse_coord_tm(r.get("좌표정보(X)", ""), r.get("좌표정보(Y)", ""))
            rows.append({
                "name": r["사업장명"].strip(),
                "name_norm": normalize_name(r["사업장명"]),
                "road_address": r.get("도로명주소", "").strip() or None,
                "jibun_address": r.get("지번주소", "").strip() or None,
                "phone": r.get("전화번호", "").strip() or None,
                "owner_type": r.get("공사립구분명", "").strip(),  # 사립 / 공립
                "license_date": r.get("인허가일자", "").strip() or None,
                "clubhouse": coord,  # WGS84 변환됨 (None 가능)
                "status": status,
                "_source": "mois_localdata",
            })
    return rows


def load_osm() -> list[dict]:
    """기존 OSM courses.json — 클럽하우스 좌표 + complete 3곳 홀별 GPS"""
    with open(OSM_JSON, encoding="utf-8") as f:
        data = json.load(f)
    rows = []
    for c in data["courses"]:
        rows.append({
            "name": c["name"].strip(),
            "name_norm": normalize_name(c["name"]),
            "region": c.get("region", "").strip(),
            "clubhouse": c.get("clubhouse"),  # 이미 WGS84
            "holes": c.get("holes", []),  # complete=18, partial=9 등
            "data_quality": c.get("dataQuality", "low"),
            "_source": "osm",
        })
    return rows


def derive_course_id(name: str, region: str) -> str:
    """ID 생성: 정규화 이름 + 지역 — 중복 방지"""
    base = normalize_name(name) or "unknown"
    region_short = (region or "kr").lower()[:2]
    return f"{base}_{region_short}"


def coord_match_merged(
    candidate_coord: dict,
    merged: list[dict],
    already_matched_ids: set,
    threshold_km: float = COORD_MATCH_THRESHOLD_KM,
) -> Optional[dict]:
    """
    좌표 기반 2차 매칭 — merged 리스트에서 임계값 이내 가장 가까운 항목 반환.
    이미 다른 소스에서 매칭된 merged 항목은 제외.
    """
    clat = candidate_coord["lat"]
    clng = candidate_coord["lng"]
    best = None
    best_dist = threshold_km
    for m in merged:
        if id(m) in already_matched_ids:
            continue
        mch = m.get("clubhouse")
        if not mch:
            continue
        dist = haversine_km(clat, clng, mch["lat"], mch["lng"])
        if dist < best_dist:
            best_dist = dist
            best = m
    return best


def merge_sources(mcst: list[dict], mois: list[dict], osm: list[dict]) -> tuple[list[dict], dict]:
    """
    3소스 fuzzy 매칭 머지.
    1차: 정규화 이름 매칭
    2차: 좌표 기반 매칭 (1.2km 이내) — 이름 표기 차이 중복 제거

    반환값: (merged 리스트, 매칭 통계 dict)
    """
    # 인덱스 구성
    mois_by_name = {}
    for r in mois:
        if r["name_norm"]:
            mois_by_name.setdefault(r["name_norm"], []).append(r)
    osm_by_name = {}
    for r in osm:
        if r["name_norm"]:
            osm_by_name.setdefault(r["name_norm"], []).append(r)

    merged = []
    matched_mois = set()
    matched_osm = set()

    # MCST(문체부)를 기준으로 머지 (가장 신뢰할 수 있는 홀수 정보)
    for m in mcst:
        nn = m["name_norm"]
        mois_match = mois_by_name.get(nn, [])
        osm_match = osm_by_name.get(nn, [])

        # 좌표 우선순위: 행안부(EPSG:5174 변환) > OSM > 없음
        clubhouse = None
        if mois_match and mois_match[0].get("clubhouse"):
            clubhouse = mois_match[0]["clubhouse"]
        elif osm_match and osm_match[0].get("clubhouse"):
            clubhouse = osm_match[0]["clubhouse"]

        # 주소: 행안부 도로명 우선
        address = m["address"]  # 문체부 소재지
        road_addr = mois_match[0].get("road_address") if mois_match else None
        if road_addr:
            address = road_addr

        # 홀 GPS: OSM complete/partial만
        holes_gps = []
        data_quality = "low"
        if osm_match:
            holes_gps = osm_match[0].get("holes", [])
            data_quality = osm_match[0].get("data_quality", "low")

        entry = {
            "id": derive_course_id(m["name"], m["region"]),
            "name": m["name"],
            "region": m["region"],
            "address": address,
            "phone": mois_match[0].get("phone") if mois_match else None,
            "clubhouse": clubhouse,
            "holesCount": m["holes_count"],          # ⭐ 핵심 신규 필드 (18/27/36 등)
            "courseType": m["course_type"],          # 대중제 / 회원제
            "ownerType": mois_match[0].get("owner_type") if mois_match else None,
            "areaM2": m["area_m2"],
            "courses": [],                            # ⭐ 새 시나리오: 코스명(동/서) — 추후 보강
            "holes": holes_gps,                      # OSM 매칭된 곳만 (3 complete + 11 partial + 8 minimal)
            "dataQuality": data_quality,             # complete / partial / minimal / low
            "sources": ["mcst"] + (["mois"] if mois_match else []) + (["osm"] if osm_match else []),
        }
        merged.append(entry)

        for mm in mois_match:
            matched_mois.add(id(mm))
        for om in osm_match:
            matched_osm.add(id(om))

    # ──────────────────────────────────────────────────────────────
    # MOIS 2차 매칭: 이름 매칭 실패한 MOIS 항목을 좌표로 merged에 합병
    # ──────────────────────────────────────────────────────────────
    coord_matched_mois = 0
    # 좌표 기반 매칭을 위해 merged 중 이미 MOIS가 붙은 항목은 제외
    mois_coord_matched_merged = set()  # id(merged 항목) 집합

    remaining_mois = [r for r in mois if id(r) not in matched_mois]
    for r in remaining_mois:
        coord = r.get("clubhouse")
        if not coord:
            # 좌표 없으면 좌표 매칭 불가 — 이름 매칭도 실패했으므로 그냥 추가
            continue
        target = coord_match_merged(coord, merged, mois_coord_matched_merged)
        if target is not None:
            # 기존 merged 항목에 MOIS 정보 보강
            if not target.get("phone") and r.get("phone"):
                target["phone"] = r.get("phone")
            if not target.get("ownerType") and r.get("owner_type"):
                target["ownerType"] = r.get("owner_type")
            # 주소 보강 (도로명 우선)
            if r.get("road_address") and (
                not target.get("address") or "mois" not in target["sources"]
            ):
                target["address"] = r["road_address"]
            # 좌표 보강 (MOIS 좌표가 더 신뢰)
            if not target.get("clubhouse"):
                target["clubhouse"] = coord
            target["sources"] = sorted(set(target["sources"]) | {"mois_coord"})
            mois_coord_matched_merged.add(id(target))
            matched_mois.add(id(r))
            coord_matched_mois += 1

    # 좌표 매칭도 실패한 MOIS → 별도 항목
    for r in mois:
        if id(r) in matched_mois:
            continue
        # OSM과 추가 이름 매칭 시도
        osm_match = osm_by_name.get(r["name_norm"], [])
        clubhouse = r.get("clubhouse")
        if not clubhouse and osm_match:
            clubhouse = osm_match[0].get("clubhouse")
        holes_gps = osm_match[0].get("holes", []) if osm_match else []
        data_quality = osm_match[0].get("data_quality", "low") if osm_match else "low"

        merged.append({
            "id": derive_course_id(r["name"], "kr"),
            "name": r["name"],
            "region": "",  # 행안부에는 지역 컬럼 없음 — 도로명주소에서 추출 필요 (별도 작업)
            "address": r.get("road_address") or r.get("jibun_address"),
            "phone": r.get("phone"),
            "clubhouse": clubhouse,
            "holesCount": None,                       # 문체부 매칭 안 됨 — 카카오/홈페이지 보강 필요
            "courseType": None,
            "ownerType": r.get("owner_type"),
            "areaM2": None,
            "courses": [],
            "holes": holes_gps,
            "dataQuality": data_quality,
            "sources": ["mois"] + (["osm"] if osm_match else []),
        })
        for om in osm_match:
            matched_osm.add(id(om))

    # ──────────────────────────────────────────────────────────────
    # OSM 2차 매칭: 이름 매칭 실패한 OSM 항목을 좌표로 merged에 합병
    # ──────────────────────────────────────────────────────────────
    coord_matched_osm = 0
    osm_coord_matched_merged = set()  # id(merged 항목) 집합

    remaining_osm = [r for r in osm if id(r) not in matched_osm]
    for r in remaining_osm:
        coord = r.get("clubhouse")
        if not coord:
            continue
        target = coord_match_merged(coord, merged, osm_coord_matched_merged)
        if target is not None:
            # 홀 GPS 보강 (OSM 데이터 품질 그대로 반영)
            if not target.get("holes") or target["dataQuality"] == "low":
                holes = r.get("holes", [])
                if holes:
                    target["holes"] = holes
                    target["dataQuality"] = r.get("data_quality", "low")
            # 좌표 보강
            if not target.get("clubhouse"):
                target["clubhouse"] = coord
            target["sources"] = sorted(set(target["sources"]) | {"osm_coord"})
            osm_coord_matched_merged.add(id(target))
            matched_osm.add(id(r))
            coord_matched_osm += 1

    # 좌표 매칭도 실패한 OSM → 별도 항목
    for r in osm:
        if id(r) in matched_osm:
            continue
        merged.append({
            "id": derive_course_id(r["name"], r.get("region", "kr")),
            "name": r["name"],
            "region": r.get("region", ""),
            "address": None,
            "phone": None,
            "clubhouse": r.get("clubhouse"),
            "holesCount": None,
            "courseType": None,
            "ownerType": None,
            "areaM2": None,
            "courses": [],
            "holes": r.get("holes", []),
            "dataQuality": r.get("data_quality", "low"),
            "sources": ["osm"],
        })

    # ID 중복 처리 (같은 이름의 다른 골프장 — drop 또는 suffix)
    by_id = defaultdict(list)
    for m in merged:
        by_id[m["id"]].append(m)
    final = []
    for cid, items in by_id.items():
        if len(items) == 1:
            final.append(items[0])
        else:
            # 같은 이름이지만 다른 지역 — region suffix
            for i, item in enumerate(items):
                item["id"] = f"{cid}_{i+1}"
                final.append(item)

    stats = {
        "coordMatchedMois": coord_matched_mois,
        "coordMatchedOsm": coord_matched_osm,
    }
    return final, stats


def report(merged: list[dict], stats: dict) -> dict:
    """품질 리포트 — 좌표 기반 매칭 통계 포함"""
    from collections import Counter
    by_quality = Counter(m["dataQuality"] for m in merged)
    by_region = Counter(m["region"] or "(미상)" for m in merged)
    by_holes = Counter(m["holesCount"] or "미상" for m in merged)
    has_clubhouse = sum(1 for m in merged if m.get("clubhouse"))
    has_phone = sum(1 for m in merged if m.get("phone"))
    has_address = sum(1 for m in merged if m.get("address"))
    has_holesCount = sum(1 for m in merged if m.get("holesCount") is not None)
    by_sources = Counter(",".join(sorted(m["sources"])) for m in merged)
    return {
        "totalCourses": len(merged),
        "coordMatchedMois": stats["coordMatchedMois"],   # 좌표 2차 매칭으로 중복 제거된 MOIS 항목 수
        "coordMatchedOsm": stats["coordMatchedOsm"],     # 좌표 2차 매칭으로 중복 제거된 OSM 항목 수
        "byDataQuality": dict(by_quality),
        "byRegion": dict(sorted(by_region.items(), key=lambda x: -x[1])),
        "byHolesCount": {str(k): v for k, v in sorted(by_holes.items(), key=lambda x: str(x[0]))},
        "coverage": {
            "hasClubhouse": has_clubhouse,
            "hasPhone": has_phone,
            "hasAddress": has_address,
            "hasHolesCount": has_holesCount,
        },
        "bySources": dict(sorted(by_sources.items(), key=lambda x: -x[1])),
    }


def main():
    print("=== 라운드온 시드 데이터 빌더 v2 ===\n")

    print(f"1. MCST (문체부) 로딩: {MCST_CSV.name}")
    mcst = load_mcst()
    print(f"   → {len(mcst)}곳")

    print(f"2. MOIS (행안부) 로딩: {MOIS_CSV.name}")
    mois = load_mois()
    print(f"   → {len(mois)}곳 (영업/정상 + 휴업/정지 필터링)")
    with_coord = sum(1 for r in mois if r.get("clubhouse"))
    print(f"   → 좌표 변환 성공: {with_coord}곳")

    print(f"3. OSM 로딩: {OSM_JSON.name}")
    osm = load_osm()
    print(f"   → {len(osm)}곳")

    print(f"\n4. 머지 (정규화 이름 매칭 + 좌표 기반 2차 매칭)...")
    merged, stats = merge_sources(mcst, mois, osm)
    print(f"   → 최종 {len(merged)}곳")
    print(f"   → 좌표 2차 매칭: MOIS {stats['coordMatchedMois']}건, OSM {stats['coordMatchedOsm']}건 중복 제거")

    print(f"\n5. 출력")
    output = {
        "version": "2026.05.12",
        "generatedAt": "2026-05-12T00:00:00+00:00",
        "sources": [
            "문화체육관광부 전국 골프장 현황 (data.go.kr/15118920, 2022-12-31)",
            "행정안전부 LOCALDATA 생활 골프장 (data.go.kr/15045080)",
            "OpenStreetMap via Overpass API (ODbL 1.0)",
        ],
        "license": "Mixed (공공누리 제1유형 + ODbL 1.0)",
        "totalCourses": len(merged),
        "courses": merged,
    }
    OUT_PATH.write_text(json.dumps(output, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"   → {OUT_PATH} ({OUT_PATH.stat().st_size:,} bytes)")

    rpt = report(merged, stats)
    REPORT_PATH.write_text(json.dumps(rpt, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"   → {REPORT_PATH}")

    print(f"\n=== 리포트 ===")
    print(f"총: {rpt['totalCourses']}곳")
    print(f"품질: {rpt['byDataQuality']}")
    print(f"커버리지: {rpt['coverage']}")
    print(f"소스 조합 (상위 5): {dict(list(rpt['bySources'].items())[:5])}")


if __name__ == "__main__":
    main()

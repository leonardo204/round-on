#!/usr/bin/env python3
"""
카카오 로컬 검색 API로 골프장 정보 보강
- 매칭 못한 골프장(MOIS/OSM 단독)의 주소/좌표/전화 보강
- 코스에 기존 좌표가 있으면 카카오 5건 중 가장 가까운 것 채택 (1.5km 이내)
  → 동명이인 골프장 잘못 매칭 방지
- daily quota 30만건 (충분)
- 결과: courses_seed_v3.json
"""
from __future__ import annotations
import csv
import json
import math
import os
import re
import time
import urllib.parse
import urllib.request
from collections import Counter
from pathlib import Path
from typing import Optional

KAKAO_COORD_VERIFY_KM = 1.5  # 기존 좌표와 카카오 결과 거리 임계값 (km)


def haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """두 WGS84 좌표 사이의 haversine 거리 (km)."""
    R = 6371.0
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlam = math.radians(lng2 - lng1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlam / 2) ** 2
    return 2 * R * math.asin(math.sqrt(a))

ROOT = Path(__file__).parent.parent
DB_DIR = ROOT / "Ref-docs" / "golf-db-pack"
INPUT_PATH = DB_DIR / "courses_seed_v2.json"
OUTPUT_PATH = DB_DIR / "courses_seed_v3.json"
REPORT_PATH = DB_DIR / "courses_seed_v3_report.json"
CACHE_PATH = DB_DIR / ".kakao_cache.json"

# API 키 로드
KEY_PATH = ROOT / ".api-keys.local"
KAKAO_KEY = None
with open(KEY_PATH) as f:
    for line in f:
        if line.startswith("KAKAO_REST_API_KEY="):
            KAKAO_KEY = line.split("=", 1)[1].strip()
            break
if not KAKAO_KEY:
    raise SystemExit("KAKAO_REST_API_KEY not found")

# 캐시 (재실행 시 API 비용 절감)
cache = {}
if CACHE_PATH.exists():
    cache = json.loads(CACHE_PATH.read_text(encoding="utf-8"))
    print(f"Cache loaded: {len(cache)} entries")


def _is_golf_doc(d: dict) -> bool:
    """카카오 검색 결과가 골프장 문서인지 판별 (주차장/연습장/스크린 제외)"""
    name = d.get("place_name", "")
    cat = d.get("category_name", "")
    if "주차장" in name or "연습장" in name or "스크린" in name:
        return False
    return "골프장" in cat or "골프" in name or "CC" in name.upper() or "컨트리클럽" in name


def _doc_to_result(d: dict) -> dict:
    """카카오 document → 결과 dict"""
    return {
        "place_name": d.get("place_name"),
        "category": d.get("category_name"),
        "address": d.get("road_address_name") or d.get("address_name"),
        "phone": d.get("phone") or None,
        "lat": float(d["y"]) if d.get("y") else None,
        "lng": float(d["x"]) if d.get("x") else None,
        "place_url": d.get("place_url"),
    }


def kakao_search_raw(query: str) -> list[dict]:
    """
    카카오 로컬 검색 — 원본 documents 리스트 반환 (최대 5건).
    캐시는 최종 선택 결과(dict)를 저장하므로, raw는 캐시 미적용.
    캐시 적용은 호출부에서 처리.
    """
    q = urllib.parse.quote(query)
    url = f"https://dapi.kakao.com/v2/local/search/keyword.json?query={q}&size=5"
    req = urllib.request.Request(
        url,
        headers={"Authorization": f"KakaoAK {KAKAO_KEY}"},
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode("utf-8"))
        if "errorType" in data:
            print(f"  API err for '{query}': {data['errorType']}")
            return []
        return data.get("documents", [])
    except Exception as e:
        print(f"  Network err for '{query}': {e}")
        return []


def kakao_search(query: str, existing_coord: Optional[dict] = None) -> dict:
    """
    카카오 로컬 검색 — 골프장 1건 반환 (또는 빈 dict).

    existing_coord가 있으면: 5건 중 가장 가까운 결과 채택 (1.5km 이내).
    그렇지 않으면: 기존 로직 (골프장 카테고리 우선 첫 번째).

    캐시 키: query (좌표 검증은 후처리이므로 동일 쿼리는 동일 결과)
    """
    if query in cache:
        return cache[query]

    docs = kakao_search_raw(query)
    if not docs:
        cache[query] = {}
        return {}

    # ── 좌표 검증 모드: 기존 좌표가 있으면 가장 가까운 결과 채택 ──
    if existing_coord:
        elat = existing_coord["lat"]
        elng = existing_coord["lng"]
        best = None
        best_dist = KAKAO_COORD_VERIFY_KM
        for d in docs:
            if not d.get("y") or not d.get("x"):
                continue
            dlat = float(d["y"])
            dlng = float(d["x"])
            dist = haversine_km(elat, elng, dlat, dlng)
            if dist < best_dist:
                best_dist = dist
                best = d
        # 1.5km 이내 결과 없으면 기존 좌표 신뢰 (카카오 결과 무시)
        if best is None:
            cache[query] = {}
            return {}
        result = _doc_to_result(best)
        cache[query] = result
        return result

    # ── 기존 로직: 골프장 카테고리 우선, 첫 번째 결과 채택 ──
    best = None
    for d in docs:
        if _is_golf_doc(d):
            best = d
            break
    if not best and docs:
        best = docs[0]
    result = _doc_to_result(best) if best else {}
    cache[query] = result
    return result


def main():
    with open(INPUT_PATH, encoding="utf-8") as f:
        data = json.load(f)
    courses = data["courses"]

    # 보강 대상: 클럽하우스 좌표 없거나, 전화 없거나, 주소 없는 곳
    # 한도: API 호출 최소화를 위해 우선순위 적용
    targets = []
    for c in courses:
        missing = []
        if not c.get("clubhouse"):
            missing.append("coord")
        if not c.get("phone"):
            missing.append("phone")
        if not c.get("address"):
            missing.append("address")
        if missing:
            targets.append((c, missing))

    print(f"Total courses: {len(courses)}")
    print(f"Targets (need enrichment): {len(targets)}")

    # 카카오 검색
    enriched = 0
    api_calls = 0
    coord_rejected = 0  # 기존 좌표와 너무 멀어서 카카오 결과 무시한 건수
    for i, (c, missing) in enumerate(targets, 1):
        # 쿼리: 골프장 이름
        query = c["name"]
        # 기존 좌표가 있으면 카카오 결과 좌표 검증에 활용 (동명이인 잘못 매칭 방지)
        existing_coord = c.get("clubhouse")
        result = kakao_search(query, existing_coord=existing_coord)
        if not result:
            # existing_coord가 있었고 카카오 결과가 없으면 좌표 검증 거부로 카운트
            if existing_coord and query not in cache:
                coord_rejected += 1
            continue

        api_calls += 1
        # 보강
        if "coord" in missing and result.get("lat"):
            c["clubhouse"] = {"lat": round(result["lat"], 6), "lng": round(result["lng"], 6)}
            c.setdefault("sources", []).append("kakao_coord")
        if "phone" in missing and result.get("phone"):
            c["phone"] = result["phone"]
            c.setdefault("sources", []).append("kakao_phone")
        if "address" in missing and result.get("address"):
            c["address"] = result["address"]
            c.setdefault("sources", []).append("kakao_address")
        if result.get("place_url"):
            c["kakaoPlaceUrl"] = result["place_url"]

        enriched += 1

        # Rate limit 보호 (30만/day = 약 3.4 req/sec 안전 한도)
        if api_calls % 50 == 0:
            print(f"  Progress: {api_calls} API calls, {enriched} enriched")
            # 캐시 저장 중간
            CACHE_PATH.write_text(json.dumps(cache, ensure_ascii=False, indent=2), encoding="utf-8")
        time.sleep(0.05)  # 20 req/sec — 안전

    print(f"\nTotal API calls: {api_calls}, enriched: {enriched}, coord_rejected: {coord_rejected}")

    # sources 중복 제거
    for c in courses:
        if "sources" in c:
            c["sources"] = sorted(set(c["sources"]))

    # 출력
    data["version"] = "2026.05.12-v3"
    data["generatedAt"] = "2026-05-12T05:30:00+00:00"
    data["sources"] = data["sources"] + ["Kakao Local API (kakaodevelopers.com)"]

    OUTPUT_PATH.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    CACHE_PATH.write_text(json.dumps(cache, ensure_ascii=False, indent=2), encoding="utf-8")

    # 리포트
    has_clubhouse = sum(1 for c in courses if c.get("clubhouse"))
    has_phone = sum(1 for c in courses if c.get("phone"))
    has_address = sum(1 for c in courses if c.get("address"))
    has_kakao = sum(1 for c in courses if c.get("kakaoPlaceUrl"))

    report = {
        "totalCourses": len(courses),
        "apiCalls": api_calls,
        "enrichedCount": enriched,
        "coordRejected": coord_rejected,   # 기존 좌표와 달라 카카오 결과 무시한 건수
        "cacheSize": len(cache),
        "coverage": {
            "hasClubhouse": has_clubhouse,
            "hasPhone": has_phone,
            "hasAddress": has_address,
            "hasKakaoUrl": has_kakao,
        },
    }
    REPORT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"\n=== 결과 ===")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    print(f"\n출력:")
    print(f"  - {OUTPUT_PATH}")
    print(f"  - {REPORT_PATH}")
    print(f"  - {CACHE_PATH} (재실행 시 API 비용 절감)")


if __name__ == "__main__":
    main()

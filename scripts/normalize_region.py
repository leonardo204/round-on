#!/usr/bin/env python3
"""
골프장 Region(시/도) 자동 추출 스크립트
- 입력: courses_seed_v3.json (965곳)
- 대상: region이 빈 문자열이거나 None인 코스
- 방법: address 필드에서 시/도 접두어 파싱 (정규식)
- 출력: courses_seed_v3.json in-place 갱신 + 리포트 JSON
- 외부 라이브러리 금지 (re + json만)
"""
from __future__ import annotations
import json
import re
import shutil
import time
from pathlib import Path

ROOT = Path(__file__).parent.parent
DB_DIR = ROOT / "Ref-docs" / "golf-db-pack"
INPUT_PATH = DB_DIR / "courses_seed_v3.json"
OUTPUT_PATH = DB_DIR / "courses_seed_v3.json"
REPORT_PATH = DB_DIR / "courses_seed_v3_region_report.json"

# 17개 시/도 목록 (정규식 매칭 순서 — 특별/광역시 우선)
REGION_PREFIXES = [
    "서울", "부산", "대구", "인천", "광주", "대전", "울산", "세종",
    "경기", "강원", "충북", "충남", "전북", "전남", "경북", "경남", "제주",
]

# 단일 정규식으로 주소 앞에서 시/도 매칭
_REGION_RE = re.compile(
    r"^(" + "|".join(re.escape(r) for r in REGION_PREFIXES) + r")"
)


def extract_region(address: str) -> str:
    """address 앞부분에서 시/도를 추출. 매칭 없으면 빈 문자열 반환."""
    if not address:
        return ""
    m = _REGION_RE.match(address.strip())
    return m.group(1) if m else ""


def main() -> None:
    print(f"[로드] {INPUT_PATH}")
    with open(INPUT_PATH, encoding="utf-8") as f:
        data = json.load(f)

    courses = data["courses"] if isinstance(data, dict) else data

    # 보강 전 통계
    before_with_region = sum(1 for c in courses if c.get("region") and c["region"].strip())
    no_region_before = [c for c in courses if not c.get("region") or not c["region"].strip()]
    print(f"[현황] region 있음: {before_with_region} / 없음: {len(no_region_before)}")

    # 백업
    backup_path = OUTPUT_PATH.with_suffix(".json.bak3")
    shutil.copy2(OUTPUT_PATH, backup_path)
    print(f"[백업] {backup_path}")

    # 보강 실행
    filled = 0
    failed = 0
    pattern_dist: dict[str, int] = {}
    details: list[dict] = []

    for c in no_region_before:
        addr = c.get("address", "")
        region = extract_region(addr)

        if region:
            c["region"] = region
            filled += 1
            pattern_dist[region] = pattern_dist.get(region, 0) + 1
            details.append({
                "id": c.get("id", ""),
                "name": c.get("name", ""),
                "address": addr,
                "extractedRegion": region,
            })
        else:
            failed += 1

    # 보강 후 통계
    after_with_region = sum(1 for c in courses if c.get("region") and c["region"].strip())
    no_region_after = [c for c in courses if not c.get("region") or not c["region"].strip()]

    print(f"[결과] 채움: {filled} / 실패(빈 문자열 유지): {failed}")
    print(f"[결과] region 있음: {before_with_region} → {after_with_region}")
    print(f"[결과] region 없음: {len(no_region_before)} → {len(no_region_after)}")

    # 저장
    if isinstance(data, dict):
        data["courses"] = courses
    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print(f"[저장] {OUTPUT_PATH}")

    # 리포트
    report = {
        "generatedAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "totalCourses": len(courses),
        "beforeWithRegion": before_with_region,
        "afterWithRegion": after_with_region,
        "filled": filled,
        "failed": failed,
        "regionDistribution": pattern_dist,
        "remaining": [
            {"id": c.get("id", ""), "name": c.get("name", ""), "address": c.get("address", "")}
            for c in no_region_after[:50]
        ],
    }
    with open(REPORT_PATH, "w", encoding="utf-8") as f:
        json.dump(report, f, ensure_ascii=False, indent=2)
    print(f"[리포트] {REPORT_PATH}")

    print()
    print("=" * 50)
    print(f"region 없음: {len(no_region_before)} → {len(no_region_after)}")
    print(f"지역 분포: {pattern_dist}")


if __name__ == "__main__":
    main()

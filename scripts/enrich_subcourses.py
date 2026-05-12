#!/usr/bin/env python3
"""
골프장 SubCourse 라벨 보강 스크립트 v2
- 입력: courses_seed_v3.json (965곳)
- 대상: holesCount in {27, 36, 45, 54} AND kakaoPlaceUrl != null
- 방법: 네이버 검색 '{골프장명} 코스' HTML에서 코스명 패턴 추출
- 캐시: Ref-docs/golf-db-pack/.naver_html_cache/ (재실행 시 재크롤 없음)
- 출력: courses_seed_v3.json in-place 갱신 + 리포트 JSON
- Rate limit: 0.4초 간격
- 외부 라이브러리 금지 (urllib + re + json만)
"""
from __future__ import annotations
import json
import re
import time
import urllib.request
import ssl
import shutil
from collections import Counter
from pathlib import Path

# ── 경로 설정 ─────────────────────────────────────────────────────────────
ROOT = Path(__file__).parent.parent
DB_DIR = ROOT / "Ref-docs" / "golf-db-pack"
INPUT_PATH = DB_DIR / "courses_seed_v3.json"
OUTPUT_PATH = DB_DIR / "courses_seed_v3.json"
REPORT_PATH = DB_DIR / "courses_seed_v3_subcourse_report.json"
CACHE_DIR = DB_DIR / ".naver_html_cache"
CACHE_DIR.mkdir(exist_ok=True)

# SSL 컨텍스트
SSL_CTX = ssl.create_default_context()

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/120.0.0.0 Safari/537.36"
    ),
    "Accept-Language": "ko-KR,ko;q=0.9",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Referer": "https://search.naver.com/",
}

CONNECT_TIMEOUT = 20
RATE_LIMIT = 0.4  # 초

# ── 코스명 추출 패턴 (우선순위 순) ─────────────────────────────────────────
# (패턴이름, 컴파일된 정규식, 최소빈도)
PATTERNS: list[tuple[str, re.Pattern, int]] = [
    # 방위 코스: 동/서/남/북/중
    ("hanja",  re.compile(r"(동|서|남|북|중)\s*코스"), 2),
    # 숫자 코스: 1~5코스
    ("num",    re.compile(r"([1-5])\s*코스"), 2),
    # 신구/뉴올드 코스
    ("newold", re.compile(r"(신|구|뉴|올드|새)\s*코스"), 1),
    # 테마 코스 — 광범위
    ("theme",  re.compile(
        r"(레이크|마운틴|밸리|크릭|힐|파인|메도우|블루|레드|파라다이스"
        r"|가든|로얄|챔피언|클래식|골드|실버|포레스트|리버|오션"
        r"|나라사랑|호국보훈|사계|봄|여름|가을|겨울"
        r"|고구려|백제|신라|가야|조선"
        r"|예술|문화|자연|한국"
        r"|베어|크리크|버치|오크|파인|힐스|리지|파크|비스타"
        r"|레이크힐|마운틴힐|밸리힐"
        r"|레드|블루|화이트|블랙|퍼플|그린|골든|화이트"
        r"|이스트|웨스트|노스|사우스"
        r"|인터내셔널|챌린지|드림|비전|스카이|스타"
        r"|로즈|아이리스|라일락|코스모스|철쭉|진달래|목련|벚꽃"
        r")\s*코스"), 1),
    # A~D 알파벳 코스 (CC 이름 노이즈 제거 필요)
    ("alpha",  re.compile(r"([A-Da-d])\s*코스"), 2),
]


# ── 네이버 HTML 페치 (캐시 우선) ──────────────────────────────────────────
def fetch_naver(name: str) -> str:
    """'{name} 코스' 네이버 검색 결과 HTML 반환. 캐시 히트 시 재요청 없음."""
    safe = re.sub(r'[^\w가-힣]', '_', name)
    cache_file = CACHE_DIR / f"{safe}.html"

    if cache_file.exists():
        return cache_file.read_text(encoding="utf-8", errors="replace")

    from urllib.parse import quote
    url = f"https://search.naver.com/search.naver?query={quote(name + ' 코스')}"
    try:
        req = urllib.request.Request(url, headers=HEADERS)
        with urllib.request.urlopen(req, timeout=CONNECT_TIMEOUT, context=SSL_CTX) as resp:
            body = resp.read().decode("utf-8", errors="replace")
    except Exception as e:
        print(f"    [fetch 실패] {name}: {e}")
        return ""

    cache_file.write_text(body, encoding="utf-8")
    return body


# ── 코스명 추출 ────────────────────────────────────────────────────────────
def extract_courses(body: str, name: str, expected: int) -> tuple[list[str], str]:
    """
    HTML body에서 코스명을 추출한다.
    - name: 골프장명 (노이즈 필터용)
    - expected: holesCount // 9
    반환: (코스명 리스트, 사용된 패턴명) 또는 ([], None)
    """
    # 골프장명에 포함된 알파벳 — alpha 패턴 false positive 방지
    name_alpha = set(re.findall(r"[A-Da-d]", name))

    for pname, pat, min_freq in PATTERNS:
        raw = pat.findall(body)
        cnt = Counter(raw)

        if pname == "alpha":
            # 골프장명 알파벳 제거
            valid = {k for k, v in cnt.items()
                     if k.upper() not in {a.upper() for a in name_alpha}
                     and v >= min_freq}
        else:
            valid = {k for k, v in cnt.items() if v >= min_freq}

        if 2 <= len(valid) <= expected:
            return sorted(valid), pname

    return [], ""


# ── 메인 ──────────────────────────────────────────────────────────────────
def main() -> None:
    # 1. JSON 로드
    print(f"[로드] {INPUT_PATH}")
    with open(INPUT_PATH, encoding="utf-8") as f:
        data = json.load(f)

    courses = data if isinstance(data, list) else data.get("courses", [])

    # 2. 후보 필터링
    candidates = [
        c for c in courses
        if c.get("holesCount") in {27, 36, 45, 54}
        and c.get("kakaoPlaceUrl")
    ]
    print(f"[후보] {len(candidates)}건 (holesCount 27/36/45/54 + kakaoPlaceUrl)")

    # 3. 표본 30건 사전 테스트
    sample = candidates[:30]
    print(f"\n[표본 테스트] {len(sample)}건 시작...")
    sample_results = _run_batch(sample)
    sample_matched = sum(1 for r in sample_results if r["found"])
    sample_rate = sample_matched / len(sample_results) if sample_results else 0
    print(f"[표본 매칭률] {sample_matched}/{len(sample_results)} = {sample_rate:.1%}")

    if sample_rate < 0.30:
        print("[중단] 표본 매칭률 30% 미만 — 전체 실행 생략")
        _write_report(len(candidates), 0, 0, [], "샘플 매칭률 부족으로 조기 종료")
        return

    # 4. 전체 실행
    print(f"\n[전체 실행] {len(candidates)}건...")
    # 표본 결과 재활용 (캐시 덕에 재요청 없음)
    all_results = _run_batch(candidates, verbose=False)

    # 5. JSON 갱신
    backup_path = OUTPUT_PATH.with_suffix(".json.bak2")
    shutil.copy2(OUTPUT_PATH, backup_path)
    print(f"[백업] {backup_path}")

    result_map: dict[str, list[str]] = {
        r["id"]: r["found"] for r in all_results if r["found"]
    }

    updated = 0
    for c in courses:
        cid = c.get("id", "")
        if cid in result_map:
            names = result_map[cid]
            c["subCourses"] = [{"name": n} for n in names]
            updated += 1

    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print(f"[갱신] {OUTPUT_PATH} ({updated}건 subCourses 추가)")

    # 6. 번들 복사
    bundle_path = ROOT / "Shared" / "Resources" / "courses.json"
    if bundle_path.parent.exists():
        shutil.copy2(OUTPUT_PATH, bundle_path)
        print(f"[복사] {bundle_path}")
    else:
        print(f"[스킵] 번들 경로 없음: {bundle_path}")

    # 7. 리포트
    pattern_dist: dict[str, int] = Counter(
        r["pattern"] for r in all_results if r["found"]
    )
    _write_report(
        total_candidates=len(candidates),
        fetched=len(all_results),
        matched=updated,
        pattern_dist=pattern_dist,
        note="",
    )

    # 8. 요약 출력
    print(f"\n{'='*50}")
    print(f"전체 후보: {len(candidates)}")
    print(f"매칭 성공: {updated}")
    print(f"매칭률:    {updated/len(candidates):.1%}")
    print(f"패턴 분포: {dict(pattern_dist)}")
    print(f"리포트:    {REPORT_PATH}")


def _run_batch(
    candidates: list[dict],
    verbose: bool = True,
) -> list[dict]:
    results = []
    for i, c in enumerate(candidates):
        name = c.get("name", "")
        cid = c.get("id", "")
        holes = c.get("holesCount", 18)
        expected = holes // 9

        body = fetch_naver(name)
        found, pat = extract_courses(body, name, expected)

        if verbose:
            status = "OK  " if found else "FAIL"
            print(f"  [{status}] {name} ({holes}홀 예상{expected}): {found}")
        else:
            if (i + 1) % 20 == 0:
                print(f"  ... {i+1}/{len(candidates)}")

        results.append({"id": cid, "name": name, "found": found, "pattern": pat})

        # 캐시 미스인 경우에만 rate limit 적용
        safe_name = re.sub(r'[^\w가-힣]', '_', name)
        cache_file = CACHE_DIR / f"{safe_name}.html"
        if not cache_file.exists():
            time.sleep(RATE_LIMIT)

    return results


def _write_report(
    total_candidates: int,
    fetched: int,
    matched: int,
    pattern_dist,
    note: str,
) -> None:
    report = {
        "totalCandidates": total_candidates,
        "fetched": fetched,
        "matched": matched,
        "matchRate": round(matched / total_candidates, 4) if total_candidates else 0,
        "patternDistribution": dict(pattern_dist),
        "note": note,
        "fallbackUsed": "none",
        "generatedAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }
    with open(REPORT_PATH, "w", encoding="utf-8") as f:
        json.dump(report, f, ensure_ascii=False, indent=2)
    print(f"[리포트] {REPORT_PATH}")


if __name__ == "__main__":
    main()

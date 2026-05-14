#!/usr/bin/env python3
"""
골프장 holesCount 네이버 검색 HTML 파싱 보강 스크립트
- 입력: courses_seed_v3.json (965곳)
- 대상: holesCount가 None이고 clubhouse 좌표가 있는 코스
- 방법: 네이버 검색 '{골프장명} 홀' HTML에서 홀 수 정규식 추출
- 캐시: Ref-docs/golf-db-pack/.naver_holes_cache/ (재실행 무비용)
- 출력: courses_seed_v3.json in-place 갱신 + 리포트 JSON
- Rate limit: 0.4초/요청 (캐시 미스 시만)
- 외부 라이브러리 금지 (urllib + re + json만)
"""
from __future__ import annotations
import json
import re
import ssl
import time
import urllib.parse
import urllib.request
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).parent.parent
DB_DIR = ROOT / "Ref-docs" / "golf-db-pack"
INPUT_PATH = DB_DIR / "courses_seed_v3.json"
OUTPUT_PATH = DB_DIR / "courses_seed_v3.json"
REPORT_PATH = DB_DIR / "courses_seed_v3_holes_report.json"
CACHE_DIR = DB_DIR / ".naver_holes_cache"
CACHE_DIR.mkdir(exist_ok=True)

SSL_CTX = ssl.create_default_context()
RATE_LIMIT = 0.4  # 초

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

# 허용 홀 수
VALID_HOLES = {9, 18, 27, 36, 45, 54}

# 홀 수 추출 패턴 (우선순위 순)
_HOLE_PATTERNS: list[tuple[str, re.Pattern]] = [
    # '홀수: 18', '홀수：27'
    ("label_colon", re.compile(r"홀\s*수\s*[:：]\s*(\d+)")),
    # '18홀' 형식 (단어 경계)
    ("n_hol",       re.compile(r"\b(\d{1,2})\s*홀\b")),
    # '홀 18' 형식
    ("hol_n",       re.compile(r"홀\s+(\d{1,2})\b")),
]

# 네이버 desc 블록 추출 (정보 박스 설명)
_DESC_RE = re.compile(r'"desc":"([^"]{10,500})"')


def fetch_naver(name: str) -> str:
    """'{name} 홀' 네이버 검색 HTML 반환. 캐시 우선."""
    safe = re.sub(r"[^\w가-힣]", "_", name)[:80]
    cache_file = CACHE_DIR / f"{safe}.html"

    if cache_file.exists():
        return cache_file.read_text(encoding="utf-8", errors="replace")

    q = urllib.parse.quote(name + " 홀")
    url = f"https://search.naver.com/search.naver?query={q}"
    req = urllib.request.Request(url, headers=HEADERS)
    try:
        with urllib.request.urlopen(req, timeout=20, context=SSL_CTX) as resp:
            body = resp.read().decode("utf-8", errors="replace")
    except Exception as e:
        print(f"    [fetch 실패] {name}: {e}")
        return ""

    cache_file.write_text(body, encoding="utf-8")
    time.sleep(RATE_LIMIT)
    return body


def extract_holes(body: str) -> tuple[int | None, str]:
    """
    HTML에서 홀 수를 추출한다.
    - desc 블록 우선 (정확도 높음) → 전체 body
    - 각 패턴으로 VALID_HOLES 내 후보 수집
    - 빈도 최대인 값 선택 (동점 시 큰 값 우선)
    반환: (홀수 or None, 패턴명)
    """
    # desc 블록에서 우선 시도
    descs = _DESC_RE.findall(body)
    desc_text = " ".join(d for d in descs if "홀" in d)

    for pname, pat in _HOLE_PATTERNS:
        for search_text in ([desc_text, body] if desc_text else [body]):
            hits = pat.findall(search_text)
            valids = [int(h) for h in hits if h.isdigit() and int(h) in VALID_HOLES]
            if not valids:
                continue
            cnt = Counter(valids)
            best = max(cnt, key=lambda v: (cnt[v], v))
            return best, pname

    return None, ""


def main() -> None:
    print(f"[로드] {INPUT_PATH}")
    with open(INPUT_PATH, encoding="utf-8") as f:
        data = json.load(f)

    courses = data["courses"] if isinstance(data, dict) else data

    # 보강 대상
    candidates = [
        c for c in courses
        if not c.get("holesCount") and c.get("clubhouse")
    ]
    before_count = sum(1 for c in courses if c.get("holesCount"))
    print(f"[현황] holesCount: {before_count} / 대상: {len(candidates)}건")

    # ── 표본 30건 사전 테스트 ──────────────────────────────────────────────
    sample = candidates[:30]
    print(f"\n[표본 테스트] {len(sample)}건...")
    sample_ok = 0
    for c in sample:
        name = c.get("name", "")
        body = fetch_naver(name)
        holes, pat = extract_holes(body)
        status = "OK  " if holes else "FAIL"
        print(f"  [{status}] {name}: {holes}홀 (패턴:{pat})")
        if holes:
            sample_ok += 1

    sample_rate = sample_ok / len(sample)
    print(f"\n[표본 매칭률] {sample_ok}/{len(sample)} = {sample_rate:.1%}")

    if sample_rate < 0.30:
        print("[중단] 표본 매칭률 30% 미만 — 전체 실행 생략")
        _write_report(before_count, before_count, 0, {}, "샘플 매칭률 부족으로 조기 종료")
        return

    # ── 전체 실행 ──────────────────────────────────────────────────────────
    print(f"\n[전체 실행] {len(candidates)}건...")
    filled = 0
    pattern_dist: dict[str, int] = {}

    for i, c in enumerate(candidates):
        name = c.get("name", "")
        body = fetch_naver(name)
        holes, pat = extract_holes(body)

        if holes:
            c["holesCount"] = holes
            filled += 1
            pattern_dist[pat] = pattern_dist.get(pat, 0) + 1

        if (i + 1) % 50 == 0:
            print(f"  ... {i+1}/{len(candidates)} (채움: {filled})")

    after_count = sum(1 for c in courses if c.get("holesCount"))

    # ── 저장 ──────────────────────────────────────────────────────────────
    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print(f"[저장] {OUTPUT_PATH}")

    # ── 리포트 ────────────────────────────────────────────────────────────
    _write_report(before_count, after_count, filled, pattern_dist, "")

    print()
    print("=" * 50)
    print(f"holesCount: {before_count} → {after_count} (+{filled})")
    print(f"패턴 분포: {pattern_dist}")
    print(f"매칭률: {filled}/{len(candidates)} = {filled/len(candidates):.1%}")


def _write_report(
    before_count: int,
    after_count: int,
    filled: int,
    pattern_dist: dict,
    note: str,
) -> None:
    report = {
        "generatedAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "beforeHolesCount": before_count,
        "afterHolesCount": after_count,
        "filled": filled,
        "patternDistribution": pattern_dist,
        "validHoles": sorted(VALID_HOLES),
        "note": note,
    }
    with open(REPORT_PATH, "w", encoding="utf-8") as f:
        json.dump(report, f, ensure_ascii=False, indent=2)
    print(f"[리포트] {REPORT_PATH}")


if __name__ == "__main__":
    main()

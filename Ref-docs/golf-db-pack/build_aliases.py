#!/usr/bin/env python3
"""build_aliases.py — 979곳 골프장 alias 생성기

입력: Shared/Resources/courses.json
출력:
  - Ref-docs/golf-db-pack/aliases_v1.json (id → [alias...] 매핑)
  - Shared/Resources/courses.json (aliases 필드 머지, in-place)
  - Ref-docs/golf-db-pack/courses.json (동일하게 머지)

전략:
  1. 한글 토큰 → 영문 사전 (도메인 특화, 골프장명 빈도 분석 기반)
  2. 사전에 없는 한글은 자모 단위 로마자 표기법(RR) 음차
  3. 이미 영문 토큰이 있으면 그대로 보존
  4. alias 결과: 공백 포함/제거 두 형태 모두 생성 (BELLA STONE / BELLASTONE)

재실행 안전 (idempotent).
"""

from __future__ import annotations
import json
import re
from pathlib import Path
from typing import Iterable

# ─────────────────────────────────────────────────────────────
# 1. 도메인 사전 (한글 → 영문)
#    골프장명 빈도 분석 결과를 기반으로 작성.
#    좌측 한글 토큰이 골프장명에 나오면 우측 영문으로 치환.
#    가장 긴 키부터 매칭 (예: '스카이힐' 우선, 그 다음 '스카이')
# ─────────────────────────────────────────────────────────────

DOMAIN_DICT: dict[str, str] = {
    # === 자연물 / 풍경 ===
    "벨라스톤": "BELLASTONE",
    "벨라": "BELLA",
    "오크밸리": "OAK VALLEY",
    "오크빌리지": "OAK VILLAGE",
    "오크": "OAK",
    "베어크리크": "BEAR CREEK",
    "베어": "BEAR",
    "스카이힐": "SKY HILL",
    "스카이밸리": "SKY VALLEY",
    "스카이72": "SKY72",
    "스카이": "SKY",
    "레이크사이드": "LAKESIDE",
    "레이크": "LAKE",
    "리버": "RIVER",
    "비치": "BEACH",
    "오션": "OCEAN",
    "오션힐": "OCEAN HILL",
    "마운틴": "MOUNTAIN",
    "포레스트": "FOREST",
    "포레": "FORE",
    "밸리": "VALLEY",
    "힐": "HILL",
    "필드": "FIELD",
    "그린": "GREEN",
    "그린필드": "GREENFIELD",
    "블루원": "BLUE ONE",
    "블루": "BLUE",
    "블랙스톤": "BLACKSTONE",
    "블랙": "BLACK",
    "골든": "GOLDEN",
    "실버": "SILVER",
    "다이아": "DIA",
    "선": "SUN",
    "선힐": "SUN HILL",
    "스타": "STAR",
    "문": "MOON",
    "스톤": "STONE",
    "파인밸리": "PINE VALLEY",
    "파인크리크": "PINE CREEK",
    "파인": "PINE",
    "메이플": "MAPLE",
    "체리": "CHERRY",
    "라일락": "LILAC",
    "로즈": "ROSE",
    "솔라고": "SOLAGO",
    "솔라": "SOLA",
    "선힐스": "SUNHILLS",

    # === 골프 용어 ===
    "이글": "EAGLE",
    "버디": "BIRDIE",
    "알바트로스": "ALBATROSS",
    "퍼팅": "PUTTING",
    "그린필": "GREEN FIELD",
    "페어웨이": "FAIRWAY",
    "라운드": "ROUND",

    # === 동물 / 신화 / 캐릭터 ===
    "타이거": "TIGER",
    "이글스": "EAGLES",
    "팰콘": "FALCON",
    "팔콘": "FALCON",
    "피닉스": "PHOENIX",
    "휘닉스": "PHOENIX",
    "드래곤": "DRAGON",
    "유니콘": "UNICORN",
    "페가수스": "PEGASUS",
    "피에스타": "FIESTA",

    # === 색상 / 분위기 ===
    "로얄": "ROYAL",
    "임페리얼": "IMPERIAL",
    "엘리트": "ELITE",
    "프리미엄": "PREMIUM",
    "그랜드": "GRAND",
    "프레스티지": "PRESTIGE",
    "메이저": "MAJOR",
    "퍼블릭": "PUBLIC",
    "프라이빗": "PRIVATE",
    "노블": "NOBLE",
    "베스트": "BEST",
    "뉴": "NEW",
    "더": "THE",

    # === 위치 / 방향 ===
    "이스트": "EAST",
    "웨스트": "WEST",
    "사우스스프링스": "SOUTH SPRINGS",
    "사우스": "SOUTH",
    "노스": "NORTH",
    "센트럴": "CENTRAL",
    "코리아": "KOREA",

    # === 한국 골프장 고유명 (LLM 도메인 지식) ===
    "안양": "ANYANG",
    "한양": "HANYANG",
    "한원": "HANWON",
    "양지파인": "YANGJI PINE",
    "양지": "YANGJI",
    "양평": "YANGPYEONG",
    "여주": "YEOJU",
    "수원": "SUWON",
    "용인": "YONGIN",
    "이천": "ICHEON",
    "안성": "ANSEONG",
    "남촌": "NAMCHON",
    "동촌": "DONGCHON",
    "제주": "JEJU",
    "강원": "GANGWON",
    "춘천": "CHUNCHEON",
    "원주": "WONJU",
    "평창": "PYEONGCHANG",
    "부산": "BUSAN",
    "대구": "DAEGU",
    "광주": "GWANGJU",
    "대전": "DAEJEON",
    "인천": "INCHEON",
    "울산": "ULSAN",
    "세종": "SEJONG",
    "전남": "JEONNAM",
    "전북": "JEONBUK",
    "경남": "GYEONGNAM",
    "경북": "GYEONGBUK",
    "충남": "CHUNGNAM",
    "충북": "CHUNGBUK",
    "구미": "GUMI",
    "포항": "POHANG",
    "경주": "GYEONGJU",
    "여수": "YEOSU",
    "순천": "SUNCHEON",
    "목포": "MOKPO",
    "군산": "GUNSAN",
    "전주": "JEONJU",
    "익산": "IKSAN",
    "청주": "CHEONGJU",
    "충주": "CHUNGJU",
    "안동": "ANDONG",
    "통영": "TONGYEONG",
    "거제": "GEOJE",
    "남해": "NAMHAE",
    "동해": "DONGHAE",
    "강릉": "GANGNEUNG",
    "속초": "SOKCHO",
    "평택": "PYEONGTAEK",

    # === 알려진 골프장 영문 표기 ===
    "아난티": "ANANTI",
    "해비치": "HAEVICHI",
    "엘리시안": "ELYSIAN",
    "엘리시": "ELYSI",
    "핀크스": "PINX",
    "비발디": "VIVALDI",
    "휘닉스파크": "PHOENIX PARK",
    "휘닉스": "PHOENIX",
    "라데나": "LA DENA",
    "떼제베": "TGV",
    "라비돌": "LA VIE D'OR",
    "라헨느": "LAHENNE",
    "레인보우": "RAINBOW",
    "레인보": "RAINBOW",
    "렉스필드": "LEXFIELD",
    "마이다스": "MIDAS",
    "샤인빌": "SHINEVILLE",
    "샤인": "SHINE",
    "롯데스카이힐": "LOTTE SKY HILL",
    "롯데": "LOTTE",
    "소노펠리체": "SONO FELICE",
    "소노": "SONO",
    "시그너스": "CYGNUS",
    "시그니처": "SIGNATURE",
    "시그": "SIG",
    "에콜리안": "ECOLIAN",
    "에버리치": "EVERLY",
    "에버": "EVER",
    "에스원": "S ONE",
    "에스": "S",
    "올데이": "ALL DAY",
    "캐슬렉스": "CASTLEX",
    "캐슬": "CASTLE",
    "코오롱": "KOLON",
    "현대": "HYUNDAI",
    "삼성": "SAMSUNG",
    "LG": "LG",
    "신세계": "SHINSEGAE",
    "한솔": "HANSOL",
    "한화": "HANWHA",
    "골든베이": "GOLDEN BAY",
    "골든": "GOLDEN",
    "오라": "ORA",
    "오라CC": "ORA",
    "아덴힐": "ARDEN HILL",
    "아덴": "ARDEN",
    "오라컨트리클럽": "ORA COUNTRY CLUB",
    "그랜드코리아": "GRAND KOREA",
    "그랜드오크": "GRAND OAK",
    "테디": "TEDDY",
    "베벌리": "BEVERLY",
    "센추리": "CENTURY",
    "센트럴": "CENTRAL",
    "캐년힐스": "CANYON HILLS",
    "캐년": "CANYON",
    "선힐": "SUN HILL",
    "선힐스": "SUNHILLS",
    "선플라워": "SUNFLOWER",
    "오크밸리리조트": "OAK VALLEY RESORT",
    "엘리시안강촌": "ELYSIAN GANGCHON",
    "프리미엄": "PREMIUM",
    "원주오크밸리": "WONJU OAK VALLEY",
    "버드우드": "BIRDWOOD",
    "이스턴": "EASTERN",
    "웨스턴": "WESTERN",
    "센추럴": "CENTRAL",
    "휘슬링락": "WHISTLING ROCK",
    "휘슬링": "WHISTLING",
    "헤븐힐": "HEAVEN HILL",
    "헤븐": "HEAVEN",
    "프린스": "PRINCE",
    "프린세스": "PRINCESS",
    "에덴": "EDEN",
    "이든": "EDEN",
    "오스카": "OSCAR",
    "메르세데스": "MERCEDES",
    "킹스": "KINGS",
    "킹": "KING",
    "퀸": "QUEEN",
    "올림픽": "OLYMPIC",
    "올림피아": "OLYMPIA",
    "골든타워": "GOLDEN TOWER",
    "타워": "TOWER",
    "메이저리그": "MAJOR LEAGUE",
    "베르힐": "BEAR HILL",
    "베어밸리": "BEAR VALLEY",
    "베르사이유": "VERSAILLES",
    "베르사유": "VERSAILLES",
    "베르": "BEAR",
    "사이프러스": "CYPRESS",
    "사이프": "CYPRESS",
    "스프링베일": "SPRING VALE",
    "스프링": "SPRING",
    "발리오": "VALI O",
    "나인브릿지": "NINE BRIDGES",
    "나인": "NINE",
    "원": "ONE",
    "투": "TWO",
    "쓰리": "THREE",
    "포": "FOUR",
    "파이브": "FIVE",
    "리츠": "RITZ",
    "라마다": "RAMADA",
    "힐튼": "HILTON",
    "팰리스": "PALACE",
    "제이드팰리스": "JADE PALACE",
    "제이드": "JADE",
    "옥": "JADE",
    "다이아몬드": "DIAMOND",
    "에메랄드": "EMERALD",
    "사파이어": "SAPPHIRE",
    "루비": "RUBY",
    "오팔": "OPAL",
    "크리스탈": "CRYSTAL",
    "크리스털": "CRYSTAL",
    "글로벌": "GLOBAL",
    "월드": "WORLD",
    "메가": "MEGA",
    "유토피아": "UTOPIA",
    "파라다이스": "PARADISE",
    "헤리티지": "HERITAGE",
    "리츠칼튼": "RITZ CARLTON",
    "베스트웨스턴": "BEST WESTERN",
    "포시즌": "FOUR SEASONS",
    "포시즌스": "FOUR SEASONS",
    "임피리얼": "IMPERIAL",
    "리젠시": "REGENCY",
    "보스턴": "BOSTON",
    "맨하탄": "MANHATTAN",
    "헐리우드": "HOLLYWOOD",
    "할리우드": "HOLLYWOOD",
    "라스베가스": "LAS VEGAS",
    "라스": "LAS",
    "올스타": "ALL STAR",
    "퍼스트": "FIRST",
    "세컨드": "SECOND",
    "베리타스": "VERITAS",
    "글로리": "GLORY",
    "퓨처": "FUTURE",
    "헤리": "HERITAGE",
    "에덴힐": "EDEN HILL",
    "버치힐": "BIRCH HILL",
    "버치": "BIRCH",
    "팜": "PALM",
    "팜스프링스": "PALM SPRINGS",
    "데이": "DAY",
    "데이즈": "DAYS",
    "체스터": "CHESTER",
    "체스터필드": "CHESTERFIELD",
    "리버사이드": "RIVERSIDE",
    "포로스": "POROS",
    "리츠칼튼": "RITZ CARLTON",
    "라온": "RAON",
    "라온힐스": "RAON HILLS",
    "라온": "RAON",
    "더서밋": "THE SUMMIT",
    "서밋": "SUMMIT",
    "엠브로": "EMBRO",
    "엠브로컨트리클럽": "EMBRO COUNTRY CLUB",
    "클럽디": "CLUB-D",
    "클럽": "CLUB",
    "마운트": "MOUNT",
    "버치우드": "BIRCHWOOD",
    "케리야": "KELLY YA",
    "케이": "K",
    "노블레스": "NOBLESSE",
    "프리스틴": "PRISTINE",
    "비전": "VISION",
    "비전힐스": "VISION HILLS",
    "ECO": "ECO",
    "에코": "ECO",
    "친환경": "ECO",

    # === 기타 자주 나오는 한국어 단어 ===
    "마루": "MARU",
    "한가람": "HANGARAM",
    "가람": "GARAM",
    "한솔": "HANSOL",
    "샛별": "SAEBYEOL",
    "은하수": "EUNHASU",
    "한울": "HANUL",
    "참": "CHAM",
    "푸른": "PUREUN",
    "맑은": "MALGEUN",
    "고운": "GOUN",
    "밝은": "BALGEUN",
    "큰솔": "KEUNSOL",
    "솔": "SOL",
    "솔뫼": "SOLMOE",
    "뫼": "MOE",
    "마실": "MASIL",
    "들": "DEUL",
    "벌": "BEOL",
    "골": "GOL",
    "터": "TEO",
    "마을": "MAUL",
    "동산": "DONGSAN",
    "산": "SAN",
    "강": "GANG",
    "바다": "BADA",
    "해": "HAE",
    "달": "DAL",
    "별": "BYEOL",
    "꽃": "KKOT",
    "나무": "NAMU",
    "잎": "IP",
    "숲": "SUP",
}

# 가장 긴 키부터 매칭 (그리디 토큰화)
_SORTED_KEYS = sorted(DOMAIN_DICT.keys(), key=len, reverse=True)

# ─────────────────────────────────────────────────────────────
# 2. 한국어 자모 → 로마자 (RR 표기법, 간략화)
# ─────────────────────────────────────────────────────────────

INITIAL = {
    'ㄱ': 'g', 'ㄲ': 'kk', 'ㄴ': 'n', 'ㄷ': 'd', 'ㄸ': 'tt',
    'ㄹ': 'r', 'ㅁ': 'm', 'ㅂ': 'b', 'ㅃ': 'pp', 'ㅅ': 's',
    'ㅆ': 'ss', 'ㅇ': '', 'ㅈ': 'j', 'ㅉ': 'jj', 'ㅊ': 'ch',
    'ㅋ': 'k', 'ㅌ': 't', 'ㅍ': 'p', 'ㅎ': 'h',
}
MEDIAL = {
    'ㅏ': 'a', 'ㅐ': 'ae', 'ㅑ': 'ya', 'ㅒ': 'yae', 'ㅓ': 'eo',
    'ㅔ': 'e', 'ㅕ': 'yeo', 'ㅖ': 'ye', 'ㅗ': 'o', 'ㅘ': 'wa',
    'ㅙ': 'wae', 'ㅚ': 'oe', 'ㅛ': 'yo', 'ㅜ': 'u', 'ㅝ': 'wo',
    'ㅞ': 'we', 'ㅟ': 'wi', 'ㅠ': 'yu', 'ㅡ': 'eu', 'ㅢ': 'ui',
    'ㅣ': 'i',
}
FINAL = {
    '': '', 'ㄱ': 'k', 'ㄲ': 'k', 'ㄳ': 'k', 'ㄴ': 'n', 'ㄵ': 'n',
    'ㄶ': 'n', 'ㄷ': 't', 'ㄹ': 'l', 'ㄺ': 'k', 'ㄻ': 'm',
    'ㄼ': 'l', 'ㄽ': 'l', 'ㄾ': 'l', 'ㄿ': 'p', 'ㅀ': 'l',
    'ㅁ': 'm', 'ㅂ': 'p', 'ㅄ': 'p', 'ㅅ': 't', 'ㅆ': 't',
    'ㅇ': 'ng', 'ㅈ': 't', 'ㅊ': 't', 'ㅋ': 'k', 'ㅌ': 't',
    'ㅍ': 'p', 'ㅎ': 't',
}
INIT_LIST = ['ㄱ', 'ㄲ', 'ㄴ', 'ㄷ', 'ㄸ', 'ㄹ', 'ㅁ', 'ㅂ', 'ㅃ', 'ㅅ',
             'ㅆ', 'ㅇ', 'ㅈ', 'ㅉ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ']
MED_LIST = ['ㅏ', 'ㅐ', 'ㅑ', 'ㅒ', 'ㅓ', 'ㅔ', 'ㅕ', 'ㅖ', 'ㅗ', 'ㅘ',
            'ㅙ', 'ㅚ', 'ㅛ', 'ㅜ', 'ㅝ', 'ㅞ', 'ㅟ', 'ㅠ', 'ㅡ', 'ㅢ', 'ㅣ']
FIN_LIST = ['', 'ㄱ', 'ㄲ', 'ㄳ', 'ㄴ', 'ㄵ', 'ㄶ', 'ㄷ', 'ㄹ', 'ㄺ',
            'ㄻ', 'ㄼ', 'ㄽ', 'ㄾ', 'ㄿ', 'ㅀ', 'ㅁ', 'ㅂ', 'ㅄ', 'ㅅ',
            'ㅆ', 'ㅇ', 'ㅈ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ']


def romanize_char(ch: str) -> str:
    """단일 한글 글자를 RR 로마자로."""
    if not ('가' <= ch <= '힣'):
        return ch
    code = ord(ch) - ord('가')
    fi = code % 28
    mi = (code // 28) % 21
    ii = code // 28 // 21
    return INITIAL[INIT_LIST[ii]] + MEDIAL[MED_LIST[mi]] + FINAL[FIN_LIST[fi]]


def romanize(text: str) -> str:
    """문자열을 글자 단위 로마자로. 빈 음절(ㅇ 자음) 처리."""
    return ''.join(romanize_char(c) for c in text)


# ─────────────────────────────────────────────────────────────
# 3. 토큰화 + 알리아스 생성
# ─────────────────────────────────────────────────────────────

SUFFIX_RE = re.compile(
    r'(컨트리클럽|골프클럽|골프장|골프리조트|골프앤리조트|골프앤스파|골프&리조트|골프&스파|골프호텔|골프타운'
    r'|리조트|Country\s*Club|Golf\s*Club|Resort|CC|GC|cc|gc)\b',
    re.IGNORECASE,
)
SUBTYPE_RE = re.compile(r'\(?(?:대중제|대중형|회원제|9홀|18홀|27홀|36홀|퍼블릭|public)\)?', re.IGNORECASE)
HANGUL_RE = re.compile(r'[가-힣]+')
ASCII_RE = re.compile(r'[A-Za-z][A-Za-z0-9]*')
NUMBER_RE = re.compile(r'\d+')


def strip_suffixes(name: str) -> str:
    """접미사 / 회원형 표시 제거."""
    s = name
    for _ in range(5):
        before = s
        s = SUFFIX_RE.sub('', s)
        s = SUBTYPE_RE.sub('', s)
        s = re.sub(r'\s+', ' ', s).strip()
        s = s.strip(' -·,()[]')
        if s == before:
            break
    return s


def tokenize(stripped: str) -> list[str]:
    """한글 토큰 + 영문 토큰 + 숫자 토큰 분리."""
    # 한글 연속 / 영문 연속 / 숫자 연속을 각각 토큰으로
    tokens: list[tuple[int, str, str]] = []  # (pos, type, text)
    for m in HANGUL_RE.finditer(stripped):
        tokens.append((m.start(), 'h', m.group()))
    for m in ASCII_RE.finditer(stripped):
        tokens.append((m.start(), 'a', m.group()))
    for m in NUMBER_RE.finditer(stripped):
        tokens.append((m.start(), 'n', m.group()))
    tokens.sort()
    return [f"{typ}:{txt}" for _, typ, txt in tokens]


def translate_hangul(token: str) -> list[str]:
    """한글 토큰을 영문 후보 1~2개로. 사전 우선 + 음차 폴백."""
    candidates: set[str] = set()

    # 1) 사전 그리디 분절
    s = token
    pieces: list[str] = []
    while s:
        matched = None
        for key in _SORTED_KEYS:
            if s.startswith(key):
                matched = key
                pieces.append(DOMAIN_DICT[key])
                s = s[len(key):]
                break
        if not matched:
            # 한 글자 음차 후 다음 글자로
            pieces.append(romanize_char(s[0]).upper())
            s = s[1:]

    # 사전 매칭 결과 (단어 사이 공백)
    if pieces:
        dict_form = ' '.join(p for p in pieces if p).strip()
        if dict_form:
            candidates.add(dict_form)
            # 공백 제거 형태도 추가
            candidates.add(dict_form.replace(' ', ''))

    # 2) 전체 음차 (사전 무시)
    rr = romanize(token).upper()
    if rr:
        candidates.add(rr)

    return [c for c in candidates if c]


def build_aliases(name: str) -> list[str]:
    """골프장명 → alias 후보 리스트."""
    stripped = strip_suffixes(name)
    if not stripped:
        return []

    tokens = tokenize(stripped)
    if not tokens:
        return []

    # 토큰별 영문 후보 생성
    per_token: list[list[str]] = []
    for tok in tokens:
        typ, txt = tok.split(':', 1)
        if typ == 'h':
            per_token.append(translate_hangul(txt))
        elif typ == 'a':
            per_token.append([txt.upper()])
        elif typ == 'n':
            per_token.append([txt])

    # 조합 생성 (최대 카드inality 제한)
    # 첫 후보로만 조합 + 한 토큰만 두 번째 후보 사용 (조합 폭주 방지)
    aliases: set[str] = set()

    primary = ' '.join(opts[0] for opts in per_token if opts)
    if primary:
        aliases.add(primary)
        aliases.add(primary.replace(' ', ''))

    # 한 토큰만 두 번째 후보로 바꾼 변형 (최대 2개)
    for i, opts in enumerate(per_token):
        if len(opts) > 1:
            variant = list(per_token)
            variant[i] = [opts[1]]
            v_str = ' '.join(v[0] for v in variant if v)
            if v_str and v_str != primary:
                aliases.add(v_str)
                aliases.add(v_str.replace(' ', ''))

    # 중복 제거 + 빈 문자열 제거 + 너무 짧은 것 제외
    result = sorted({a.strip() for a in aliases if a.strip() and len(a.strip()) >= 2})

    # 최대 4개로 제한
    return result[:4]


# ─────────────────────────────────────────────────────────────
# 4. 메인 처리
# ─────────────────────────────────────────────────────────────

PROJECT_ROOT = Path(__file__).resolve().parents[2]
SHARED_COURSES = PROJECT_ROOT / "Shared" / "Resources" / "courses.json"
DBPACK_COURSES = PROJECT_ROOT / "Ref-docs" / "golf-db-pack" / "courses.json"
ALIASES_OUTPUT = PROJECT_ROOT / "Ref-docs" / "golf-db-pack" / "aliases_v1.json"


def main():
    print(f"reading {SHARED_COURSES}")
    with SHARED_COURSES.open() as f:
        data = json.load(f)

    courses = data if isinstance(data, list) else data.get("courses", [])
    print(f"total courses: {len(courses)}")

    # alias 생성
    aliases_map: dict[str, list[str]] = {}
    samples_shown = 0
    skipped = 0

    for c in courses:
        cid = c.get("id", "")
        name = c.get("name", "")
        if not cid or not name:
            skipped += 1
            continue
        aliases = build_aliases(name)
        if aliases:
            aliases_map[cid] = aliases
            if samples_shown < 12:
                print(f"  {cid:40s} '{name}' → {aliases}")
                samples_shown += 1
        else:
            skipped += 1

    print(f"\ngenerated aliases for {len(aliases_map)} courses (skipped: {skipped})")

    # aliases_v1.json 저장
    with ALIASES_OUTPUT.open("w") as f:
        json.dump(aliases_map, f, ensure_ascii=False, indent=2, sort_keys=True)
    print(f"wrote {ALIASES_OUTPUT}")

    # courses.json 패치 (두 곳)
    patched = 0
    for c in courses:
        cid = c.get("id", "")
        if cid in aliases_map:
            c["aliases"] = aliases_map[cid]
            patched += 1
        elif "aliases" not in c:
            c["aliases"] = []

    output_data = courses if isinstance(data, list) else {**data, "courses": courses}
    for target in (SHARED_COURSES, DBPACK_COURSES):
        with target.open("w") as f:
            json.dump(output_data, f, ensure_ascii=False, indent=2)
        print(f"patched {target} ({patched} entries)")

    print("\nDONE")


if __name__ == "__main__":
    main()

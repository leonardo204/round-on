/**
 * 라운드온 Worker 공통 타입 정의
 * 30-API_SPEC §9.3, 32-CLOUDFLARE_SETUP §5 기반
 */

// ── Cloudflare 환경 바인딩 ─────────────────────────────────────────────────

export interface Env {
  // KV 네임스페이스 (32-CLOUDFLARE_SETUP §3)
  KV_META: KVNamespace;       // shortId → 메타 JSON, pinHash
  KV_RATELIMIT: KVNamespace;  // Rate limit 카운터 (33-SECURITY §6)
  KV_PINLOCK: KVNamespace;    // PIN 오답 잠금 카운터 (33-SECURITY §5)
  KV_SESSION: KVNamespace;    // viewer 세션 쿠키 검증값 (33-SECURITY §5.4)
  KV_COURSES: KVNamespace;    // courses/course-pars 데이터 (코스 DB 동기화)
  KV_STATS: KVNamespace;      // 통계 공유 페이로드 저장 (7일 TTL, v1 2026-05-27)

  // vars
  ENVIRONMENT: string;         // "development" | "production"
  VIEWER_DOMAIN: string;       // "golf.zerolive.co.kr"

  // secrets (wrangler secret put으로 등록 — wrangler.toml에 없음)
  BCRYPT_PEPPER?: string;       // bcrypt 추가 보안 pepper (선택)
  SESSION_HMAC_KEY?: string;    // HMAC-SHA256 세션 쿠키 서명 키 (필수)
  COURSES_API_KEY?: string;     // GET /v1/courses, /v1/course-pars Bearer 키
  REFRESH_HMAC_SECRET?: string; // POST /v1/courses/refresh HMAC-SHA256 시크릿
  TELEGRAM_BOT_TOKEN?: string;  // Telegram 알림 봇 토큰
  TELEGRAM_CHAT_ID?: string;    // Telegram 알림 채팅 ID
}

// ── 공유 라운드 데이터 ──────────────────────────────────────────────────────

/**
 * 플레이어 1명의 와이어 표현
 * nameVisibility에 따라 name 필드가 실명 또는 A/B/C/D로 치환된다
 */
export interface Player {
  id: string;
  name: string;
  totalScore: number;
}

/**
 * 홀 스코어 (플레이어별)
 */
export interface HoleScore {
  playerId: string;
  shots: number;
  putts?: number;
  penalties?: number;
}

/**
 * 홀 정보
 */
export interface Hole {
  number: number;     // 1~18
  par: number;        // 3/4/5
  scores: HoleScore[];
}

/**
 * 라운드 와이어 페이로드 (30-API §9.3 권장 최소 필드)
 * SwiftData Round → 와이어 직렬화 시 사용
 */
export interface Round {
  id: string;
  courseName: string;
  courseId?: string;
  dataQuality?: "low" | "high";
  date: string;           // ISO 8601 날짜 (YYYY-MM-DD)
  startedAt?: string;     // ISO 8601 UTC
  finishedAt?: string;    // ISO 8601 UTC
  totalHoles?: number;    // 9 | 18
  players: Player[];
  holes: Hole[];
  notes?: string;
}

/**
 * 공유 옵션
 */
export interface ShareOptions {
  nameVisibility: "real" | "anonymous";
  accessControl: "public" | "pin";
  pin?: string;           // accessControl == "pin"일 때만, 4자리 숫자
}

/**
 * POST /api/share 요청 바디
 */
export interface SharePayload {
  deviceToken: string;    // 익명 UUID — Rate limiting 기준
  round: Round;
  options: ShareOptions;
  idempotencyKey?: string; // 중복 방지용 (30-API §9.7)
}

/**
 * KV에 저장되는 share 메타 객체 (share:{shortId})
 * (2026-05-18) photos 필드 제거 — 사진 공유 기능 폐기
 */
export interface ShareMeta {
  shortId: string;
  editToken: string;      // 평문 (클라이언트에 최초 1회 반환 후 비밀 유지)
  round: Round;
  options: Omit<ShareOptions, "pin">;  // PIN은 별도 키(pinHash)에 저장
  createdAt: string;      // ISO 8601 UTC
  expiresAt: string;      // ISO 8601 UTC (createdAt + 7일)
}

/**
 * PIN 잠금 카운터 (KV_PINLOCK)
 */
export interface PinLockEntry {
  attempts: number;
  firstAttemptAt: number; // unix timestamp (ms)
}

// ── 에러 코드 열거 (30-API §9.4) ───────────────────────────────────────────

export type ErrorCode =
  | "PIN_REQUIRED"
  | "PIN_INVALID"
  | "PIN_LOCKED"
  | "PIN_INVALID_FORMAT"
  | "EDIT_TOKEN_INVALID"
  | "EXPIRED"
  | "NOT_FOUND"
  | "RATE_LIMITED"
  | "PAYLOAD_TOO_LARGE"
  | "PII_REJECTED"
  | "INTERNAL_ERROR"
  | "VALIDATION_ERROR";

export interface ApiError {
  error: ErrorCode;
  message: string;
}

// ── 통계 공유 타입 (iOS StatsSharePayload 1:1 대응 — v1 2026-05-27) ─────────

/** 시그니처 카드 종류 */
export type StatsCardKind = "pr" | "hcp" | "trend";

/** C안 미니 통계 셀 1개 */
export interface StatsSignatureMiniStat {
  value: string;   // 예: "82", "+10"
  label: string;   // 예: "이전 PR", "Even 대비"
}

/** 시그니처 카드 데이터 */
export interface StatsSignature {
  headline: string;
  bigNumber: string;
  bigUnit: string;
  deltaText?: string | null;
  metaPrimary?: string | null;
  metaSecondary?: string | null;
  footerLabel: string;
  // C안 추가 필드 (Optional — 기존 호환)
  playerName?: string | null;
  miniStats?: StatsSignatureMiniStat[] | null;
  tagText?: string | null;
  scoreBlockLabel?: string | null;
}

/** 요약 수치 */
export interface StatsSummary {
  totalRounds: number;
  recentAverageScore?: number | null;
  averageVsPar?: number | null;
}

/** 스코어 분포 */
export interface StatsDistribution {
  eagleOrBetter: number;
  birdie: number;
  par: number;
  bogey: number;
  doubleOrWorse: number;
  totalHoles: number;
  comment: string;
}

/** Par별 평균 */
export interface StatsParAverage {
  par: number;         // 3 | 4 | 5
  averageScore: number;
  vsPar: number;
  holeCount: number;
}

/** 최근 흐름 */
export interface StatsTrend {
  direction: string;        // "improving" | "stable" | "worsening"
  directionLabel: string;   // "↘ 좋아지는 중"
  previousAverage: number;
  currentAverage: number;
  delta: number;
  scoreTrend: number[];     // 최근 N라운드 총타 배열 (sparkline)
  sigmaText?: string | null;
}

/** 베스트 라운드 */
export interface StatsBestRound {
  courseName: string;
  dateISO: string;
  totalScore: number;
  isPersonalRecord: boolean;
}

/** 시도별 지역 (centroid 좌표 포함) */
export interface StatsRegionShare {
  displayName: string;  // "경기도"
  roundCount: number;
  centroidLat: number;  // 시도 centroid (클럽하우스 X)
  centroidLng: number;
}

/** 골프장별 정확한 위치 (통계 공유 v1 — 명시 공유 동의, 33-SECURITY §7.7) */
export interface StatsRoundLocationShare {
  courseName: string;   // "레이크사이드 동코스"
  lat: number;          // 클럽하우스 위도
  lng: number;          // 클럽하우스 경도
  roundCount: number;   // 같은 골프장 라운드 횟수 (dedupe 후)
}

/** 최근 라운드 항목 */
export interface StatsRecentEntryShare {
  courseName: string;
  dateISO: string;
  totalScore: number;
  vsPar?: number | null;
  holeCount: number;
}

/**
 * 통계 공유 viewer 전체 페이로드
 * iOS StatsSharePayload 와 JSON 스키마 1:1 동일
 */
export interface StatsSharePayload {
  cardKind: StatsCardKind;
  signature: StatsSignature;
  summary: StatsSummary;
  scoreDistribution: StatsDistribution;
  parAverages: StatsParAverage[];
  trend?: StatsTrend | null;
  bestRound?: StatsBestRound | null;
  regions: StatsRegionShare[];
  recentRounds: StatsRecentEntryShare[];
  displayName: string;
  createdAtISO: string;
  periodLabel: string;
  /** 골프장별 정확한 위치 (Optional — 기존 호환). 있으면 Leaflet 핀 좌표로 우선 사용. */
  roundLocations?: StatsRoundLocationShare[] | null;
}

/**
 * KV_STATS 에 저장되는 메타
 * 키: stats:{shortId}
 */
export interface StatsShareMeta {
  shortId: string;        // 's_' + 8자 base62
  payload: StatsSharePayload;
  editToken: string;      // 32자 random hex
  pinHash?: string;       // bcrypt (선택)
  createdAt: number;      // epoch ms
  expiresAt: number;      // createdAt + 7 * 86400 * 1000
  deviceToken?: string;   // rate-limit 추적
  /**
   * og:image({shortId}:og) 저장 여부 (Optional — v1 메타 하위 호환).
   * viewer 렌더 시 KV 추가 조회 없이 og 메타 출력 여부를 판정하기 위한 플래그.
   * PIN 이 설정된 공유는 og 를 저장하지 않으므로 항상 false/undefined 다 (통계 공유 v2).
   */
  hasOgImage?: boolean;
}

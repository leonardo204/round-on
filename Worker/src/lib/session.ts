/**
 * HMAC-SHA256 세션 쿠키 관리
 * 33-SECURITY §5.4, §5.5
 *
 * 쿠키 이름: viewer_session
 * 서명 형식: {shortId}:{iat}:{random} + HMAC-SHA256
 */

const COOKIE_NAME = "viewer_session";
const SESSION_MAX_AGE = 900; // 15분 (33-SECURITY §5.4)

// ── HMAC 유틸 ──────────────────────────────────────────────────────────────

/**
 * HMAC-SHA256 서명 생성
 */
async function sign(data: string, key: string): Promise<string> {
  const encoder = new TextEncoder();
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    encoder.encode(key),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    cryptoKey,
    encoder.encode(data)
  );
  // base64url 인코딩
  const bytes = new Uint8Array(signature);
  const binary = Array.from(bytes, (b) => String.fromCharCode(b)).join("");
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");
}

/**
 * HMAC-SHA256 서명 검증 (timing-safe)
 */
async function verify(data: string, signature: string, key: string): Promise<boolean> {
  const expected = await sign(data, key);
  // 타이밍 공격 방지: 길이 비교 후 문자별 비교
  if (expected.length !== signature.length) return false;
  let diff = 0;
  for (let i = 0; i < expected.length; i++) {
    diff |= expected.charCodeAt(i) ^ signature.charCodeAt(i);
  }
  return diff === 0;
}

// ── 세션 토큰 생성/검증 ────────────────────────────────────────────────────

interface SessionPayload {
  shortId: string;
  iat: number;      // 발급 시각 (unix timestamp ms)
  random: string;   // 16바이트 무작위 base64url
}

/**
 * 세션 토큰 문자열 생성 및 서명
 * 형식: base64url({shortId}:{iat}:{random}).{signature}
 */
async function createSessionToken(
  shortId: string,
  hmacKey: string
): Promise<string> {
  const randomBytes = new Uint8Array(16);
  crypto.getRandomValues(randomBytes);
  const random = btoa(Array.from(randomBytes, (b) => String.fromCharCode(b)).join(""))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=/g, "");

  const payload: SessionPayload = {
    shortId,
    iat: Date.now(),
    random,
  };

  const data = JSON.stringify(payload);
  const dataB64 = btoa(data).replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");
  const sig = await sign(data, hmacKey);
  return `${dataB64}.${sig}`;
}

/**
 * 세션 토큰 검증 및 페이로드 파싱
 * @returns shortId (유효) | null (무효/만료)
 */
async function verifySessionToken(
  token: string,
  hmacKey: string
): Promise<string | null> {
  const parts = token.split(".");
  if (parts.length !== 2) return null;

  const [dataB64, sig] = parts;

  let data: string;
  try {
    data = atob(dataB64.replace(/-/g, "+").replace(/_/g, "/"));
  } catch {
    return null;
  }

  const valid = await verify(data, sig, hmacKey);
  if (!valid) return null;

  let payload: SessionPayload;
  try {
    payload = JSON.parse(data) as SessionPayload;
  } catch {
    return null;
  }

  // 15분 만료 검사
  const elapsed = Date.now() - payload.iat;
  if (elapsed > SESSION_MAX_AGE * 1000) return null;

  return payload.shortId;
}

// ── 공개 API ───────────────────────────────────────────────────────────────

/**
 * 세션 쿠키 Set-Cookie 헤더 값 생성
 * 33-SECURITY §5.4 속성 표 기준
 */
export async function createSessionCookie(
  shortId: string,
  hmacKey: string
): Promise<string> {
  const token = await createSessionToken(shortId, hmacKey);
  // Path=/{shortId}: 다른 shortId viewer와 쿠키 범위 분리 (33-SECURITY §5.4)
  return [
    `${COOKIE_NAME}=${token}`,
    `HttpOnly`,
    `Secure`,
    `SameSite=Strict`,
    `Max-Age=${SESSION_MAX_AGE}`,
    `Path=/${shortId}`,
  ].join("; ");
}

/**
 * 요청의 세션 쿠키에서 shortId 추출 + 검증
 * @returns shortId (유효) | null (없음/무효)
 */
export async function getSessionShortId(
  request: Request,
  hmacKey: string
): Promise<string | null> {
  const cookieHeader = request.headers.get("Cookie");
  if (!cookieHeader) return null;

  const cookies = Object.fromEntries(
    cookieHeader.split(";").map((c) => {
      const [k, ...v] = c.trim().split("=");
      return [k.trim(), v.join("=")];
    })
  );

  const token = cookies[COOKIE_NAME];
  if (!token) return null;

  return verifySessionToken(token, hmacKey);
}

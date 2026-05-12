/**
 * editToken 생성
 * 33-SECURITY §3.1: crypto.getRandomValues(Uint8Array(24)) → base64url → 'tok_' prefix
 * 결과 예시: tok_AbCdEfGhIjKlMnOpQrStUvWx (36자)
 */

/**
 * Uint8Array를 base64url 문자열로 변환
 */
function toBase64url(bytes: Uint8Array): string {
  // btoa는 바이너리 문자열을 입력받으므로 변환
  const binary = Array.from(bytes, (b) => String.fromCharCode(b)).join("");
  return btoa(binary)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=/g, "");
}

/**
 * 신규 editToken 생성
 * 형식: tok_ + base64url(24바이트 무작위) = 4 + 32 = 36자
 */
export function generateEditToken(): string {
  const bytes = new Uint8Array(24);
  crypto.getRandomValues(bytes);
  return "tok_" + toBase64url(bytes);
}

/**
 * editToken 기본 형식 검증 (tok_ 접두어 + 최소 길이)
 */
export function isValidEditTokenFormat(token: string): boolean {
  return token.startsWith("tok_") && token.length >= 20;
}

/**
 * shortId 생성 — base62 8자
 * 33-SECURITY §2: crypto.getRandomValues(Uint8Array(6)) → base62 인코딩 → 8자
 * 경우의 수: 62^8 = 약 218조
 */

const BASE62_CHARS = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";
const BASE62 = BigInt(62);

/**
 * 6바이트(48비트) 무작위 바이트를 base62 8자로 인코딩한다
 */
export function generateShortId(): string {
  const bytes = new Uint8Array(6);
  crypto.getRandomValues(bytes);

  // 6바이트를 BigInt로 변환
  let num = BigInt(0);
  for (const byte of bytes) {
    num = (num << BigInt(8)) | BigInt(byte);
  }

  // base62 인코딩 (8자 고정)
  const chars: string[] = [];
  for (let i = 0; i < 8; i++) {
    chars.unshift(BASE62_CHARS[Number(num % BASE62)]);
    num = num / BASE62;
  }

  return chars.join("");
}

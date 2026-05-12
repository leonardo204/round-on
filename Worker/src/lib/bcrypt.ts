/**
 * bcrypt 래퍼 — bcryptjs 사용
 * 33-SECURITY §4: cost factor 12, pure-JS 구현 (Workers 환경 호환)
 */

import bcryptjs from "bcryptjs";

const COST = 12;

/**
 * 평문 PIN을 bcrypt 해시로 변환
 * pepper가 있으면 PIN + pepper를 조합하여 해싱 (33-SECURITY §4 보강)
 */
export async function hashPin(pin: string, pepper?: string): Promise<string> {
  const input = pepper ? pin + pepper : pin;
  return bcryptjs.hash(input, COST);
}

/**
 * 평문 PIN과 저장된 해시 비교
 * Timing Attack 방지: 33-SECURITY §4.3에 따라 호출측에서 300ms 지연 처리를 해야 한다
 */
export async function verifyPin(
  pin: string,
  hash: string,
  pepper?: string
): Promise<boolean> {
  const input = pepper ? pin + pepper : pin;
  return bcryptjs.compare(input, hash);
}

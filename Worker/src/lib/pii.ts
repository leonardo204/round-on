/**
 * PII 마스킹 — 4종 정규식 + Luhn 알고리즘
 * 33-SECURITY §7: 차단 X, 서버측 마스킹 후 저장
 */

// ── 정규식 4종 ─────────────────────────────────────────────────────────────

const PATTERNS = {
  // 한국 휴대전화: 010-1234-5678, 010 9876 5432
  phone: /01[016789][-\s]?\d{3,4}[-\s]?\d{4}/g,
  // 이메일
  email: /[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}/g,
  // 주민등록번호: 123456-1234567
  rrn: /\d{6}[-\s]?[1-4]\d{6}/g,
  // 신용카드 16자리 (Luhn 추가 검증)
  card: /(?:\d[ -]*?){13,16}/g,
} as const;

// ── Luhn 알고리즘 ───────────────────────────────────────────────────────────

/**
 * 숫자만 추출 후 Luhn 알고리즘으로 유효성 검사
 * false positive(골프 점수 시퀀스 등)를 막기 위해 카드번호 패턴에만 적용
 */
function luhn(numStr: string): boolean {
  const digits = numStr.replace(/\D/g, "");
  if (digits.length < 13 || digits.length > 16) return false;

  let sum = 0;
  let alternate = false;
  for (let i = digits.length - 1; i >= 0; i--) {
    let n = parseInt(digits[i], 10);
    if (alternate) {
      n *= 2;
      if (n > 9) n -= 9;
    }
    sum += n;
    alternate = !alternate;
  }
  return sum % 10 === 0;
}

// ── 마스킹 치환 ─────────────────────────────────────────────────────────────

/**
 * 문자열에서 PII를 감지하고 마스킹 처리한다
 * 33-SECURITY §7.2: 차단하지 않고 마스킹 후 저장
 */
export function maskPii(text: string): string {
  if (!text) return text;

  let result = text;

  // 1. 한국 휴대전화 마스킹
  result = result.replace(PATTERNS.phone, "***-****-****");

  // 2. 이메일 마스킹
  result = result.replace(PATTERNS.email, "***@***.***");

  // 3. 주민등록번호 마스킹
  result = result.replace(PATTERNS.rrn, "******-*******");

  // 4. 신용카드 — Luhn 검증 통과한 경우에만 마스킹 (33-SECURITY §7.3 주석)
  result = result.replace(PATTERNS.card, (match) => {
    if (luhn(match)) {
      return "****-****-****-****";
    }
    return match; // Luhn 실패 → 원본 유지
  });

  return result;
}

/**
 * 플레이어 이름 배열에 PII 마스킹 적용
 * 33-SECURITY §7.1: players[].name 필드가 검사 대상
 */
export function maskPlayerNames(names: string[]): string[] {
  return names.map((name) => maskPii(name));
}

/**
 * PII가 감지되었는지 확인 (로깅용 — 원본 값 미저장)
 */
export function hasPii(text: string): boolean {
  if (!text) return false;

  return (
    PATTERNS.phone.test(text) ||
    PATTERNS.email.test(text) ||
    PATTERNS.rrn.test(text) ||
    (PATTERNS.card.test(text) &&
      // 카드 패턴 매칭 결과 중 Luhn 통과 여부
      (() => {
        const matches = text.match(/(?:\d[ -]*?){13,16}/g) ?? [];
        return matches.some(luhn);
      })())
  );
}

/**
 * HTML 이스케이프 헬퍼
 * viewer HTML 생성 시 XSS 방지를 위해 모든 동적 문자열에 적용한다
 */

const ESCAPE_MAP: Record<string, string> = {
  "&": "&amp;",
  "<": "&lt;",
  ">": "&gt;",
  '"': "&quot;",
  "'": "&#x27;",
  "`": "&#x60;",
};

const ESCAPE_RE = /[&<>"'`]/g;

/**
 * HTML 특수문자 이스케이프
 */
export function escapeHtml(str: string): string {
  return str.replace(ESCAPE_RE, (ch) => ESCAPE_MAP[ch] ?? ch);
}

/**
 * JSON을 HTML 스크립트 블록에 안전하게 삽입하기 위한 이스케이프
 * </script> 태그 삽입 방지
 */
export function escapeJsonForScript(obj: unknown): string {
  return JSON.stringify(obj)
    .replace(/</g, "\\u003c")
    .replace(/>/g, "\\u003e")
    .replace(/&/g, "\\u0026")
    .replace(/'/g, "\\u0027");
}

/**
 * STORE 모드 ZIP 스트리밍 구현 (~200줄, CRC32 포함)
 * Cloudflare Workers Streams API 활용
 * 30-API §6.4: GET /:shortId/photos.zip 용
 *
 * ZIP 규격 참조: https://pkware.cachefly.net/webdocs/casestudies/APPNOTE.TXT
 * STORE 모드(압축 없음)를 사용하므로 Worker CPU 시간을 최소화
 */

// ── CRC32 테이블 ────────────────────────────────────────────────────────────

const CRC32_TABLE = (() => {
  const table = new Uint32Array(256);
  for (let i = 0; i < 256; i++) {
    let c = i;
    for (let j = 0; j < 8; j++) {
      c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    }
    table[i] = c;
  }
  return table;
})();

/**
 * CRC32 계산
 */
function crc32(data: Uint8Array): number {
  let crc = 0xffffffff;
  for (const byte of data) {
    crc = CRC32_TABLE[(crc ^ byte) & 0xff] ^ (crc >>> 8);
  }
  return (crc ^ 0xffffffff) >>> 0;
}

// ── 리틀 엔디언 쓰기 헬퍼 ─────────────────────────────────────────────────

function writeUint16LE(view: DataView, offset: number, value: number): void {
  view.setUint16(offset, value, true);
}

function writeUint32LE(view: DataView, offset: number, value: number): void {
  view.setUint32(offset, value, true);
}

// ── ZIP 구조체 빌더 ────────────────────────────────────────────────────────

interface ZipEntry {
  filename: string;
  data: Uint8Array;
  crc: number;
  offset: number;   // 이 엔트리의 로컬 헤더 시작 오프셋
}

const ZIP_LOCAL_SIGNATURE = 0x04034b50;   // PK\x03\x04
const ZIP_CENTRAL_SIGNATURE = 0x02014b50; // PK\x01\x02
const ZIP_EOCD_SIGNATURE = 0x06054b50;    // PK\x05\x06

/**
 * 로컬 파일 헤더 + 파일 데이터 생성
 * STORE 모드 (compressionMethod = 0)
 */
function buildLocalHeader(entry: ZipEntry): Uint8Array {
  const nameBytes = new TextEncoder().encode(entry.filename);
  const headerSize = 30 + nameBytes.length;
  const buf = new ArrayBuffer(headerSize + entry.data.length);
  const view = new DataView(buf);
  const bytes = new Uint8Array(buf);

  // 로컬 파일 헤더 시그니처
  writeUint32LE(view, 0, ZIP_LOCAL_SIGNATURE);
  writeUint16LE(view, 4, 20);                    // 버전 (2.0)
  writeUint16LE(view, 6, 0);                     // 일반 플래그
  writeUint16LE(view, 8, 0);                     // 압축 방법: STORE
  writeUint16LE(view, 10, 0);                    // 최종 수정 시각 (DOS)
  writeUint16LE(view, 12, 0);                    // 최종 수정 날짜 (DOS)
  writeUint32LE(view, 14, entry.crc);            // CRC-32
  writeUint32LE(view, 18, entry.data.length);    // 압축 크기
  writeUint32LE(view, 22, entry.data.length);    // 원본 크기
  writeUint16LE(view, 26, nameBytes.length);     // 파일명 길이
  writeUint16LE(view, 28, 0);                    // 추가 필드 길이

  // 파일명
  bytes.set(nameBytes, 30);
  // 파일 데이터
  bytes.set(entry.data, headerSize);

  return bytes;
}

/**
 * 센트럴 디렉토리 엔트리 생성
 */
function buildCentralEntry(entry: ZipEntry): Uint8Array {
  const nameBytes = new TextEncoder().encode(entry.filename);
  const buf = new ArrayBuffer(46 + nameBytes.length);
  const view = new DataView(buf);
  const bytes = new Uint8Array(buf);

  writeUint32LE(view, 0, ZIP_CENTRAL_SIGNATURE);
  writeUint16LE(view, 4, 20);                    // 버전 (생성자)
  writeUint16LE(view, 6, 20);                    // 필요 버전
  writeUint16LE(view, 8, 0);                     // 일반 플래그
  writeUint16LE(view, 10, 0);                    // 압축 방법: STORE
  writeUint16LE(view, 12, 0);                    // 최종 수정 시각
  writeUint16LE(view, 14, 0);                    // 최종 수정 날짜
  writeUint32LE(view, 16, entry.crc);            // CRC-32
  writeUint32LE(view, 20, entry.data.length);    // 압축 크기
  writeUint32LE(view, 24, entry.data.length);    // 원본 크기
  writeUint16LE(view, 28, nameBytes.length);     // 파일명 길이
  writeUint16LE(view, 30, 0);                    // 추가 필드 길이
  writeUint16LE(view, 32, 0);                    // 파일 설명 길이
  writeUint16LE(view, 34, 0);                    // 디스크 번호
  writeUint16LE(view, 36, 0);                    // 내부 속성
  writeUint32LE(view, 38, 0);                    // 외부 속성
  writeUint32LE(view, 42, entry.offset);         // 로컬 헤더 오프셋

  bytes.set(nameBytes, 46);
  return bytes;
}

/**
 * End of Central Directory 레코드 생성
 */
function buildEocd(
  numEntries: number,
  centralDirSize: number,
  centralDirOffset: number
): Uint8Array {
  const buf = new ArrayBuffer(22);
  const view = new DataView(buf);

  writeUint32LE(view, 0, ZIP_EOCD_SIGNATURE);
  writeUint16LE(view, 4, 0);                    // 디스크 번호
  writeUint16LE(view, 6, 0);                    // 센트럴 디렉토리 시작 디스크
  writeUint16LE(view, 8, numEntries);           // 이 디스크의 엔트리 수
  writeUint16LE(view, 10, numEntries);          // 전체 엔트리 수
  writeUint32LE(view, 12, centralDirSize);      // 센트럴 디렉토리 크기
  writeUint32LE(view, 16, centralDirOffset);    // 센트럴 디렉토리 오프셋
  writeUint16LE(view, 20, 0);                   // 설명 길이

  return new Uint8Array(buf);
}

// ── 공개 API ───────────────────────────────────────────────────────────────

export interface ZipFile {
  filename: string;
  data: Uint8Array;
}

/**
 * 여러 파일을 STORE 모드 ZIP으로 조합하여 반환
 * Cloudflare Workers 메모리 제한(128MB)을 고려하여 전체 버퍼를 조합
 * 사진 30장 × 10MB = 최대 300MB는 이론값이며, 실제 업로드는 건당 검증되므로
 * 스트리밍보다 버퍼 조합이 구현이 단순하고 안정적
 */
export async function buildZip(files: ZipFile[]): Promise<Uint8Array> {
  const entries: ZipEntry[] = [];
  const localChunks: Uint8Array[] = [];
  let offset = 0;

  // 1단계: 로컬 헤더 + 데이터 조합
  for (const file of files) {
    const crc = crc32(file.data);
    const entry: ZipEntry = {
      filename: file.filename,
      data: file.data,
      crc,
      offset,
    };
    entries.push(entry);

    const localChunk = buildLocalHeader(entry);
    localChunks.push(localChunk);
    offset += localChunk.length;
  }

  // 2단계: 센트럴 디렉토리 조합
  const centralChunks: Uint8Array[] = [];
  let centralDirSize = 0;
  const centralDirOffset = offset;

  for (const entry of entries) {
    const centralChunk = buildCentralEntry(entry);
    centralChunks.push(centralChunk);
    centralDirSize += centralChunk.length;
  }

  // 3단계: EOCD
  const eocd = buildEocd(entries.length, centralDirSize, centralDirOffset);

  // 4단계: 전체 버퍼 조합
  const allChunks = [...localChunks, ...centralChunks, eocd];
  const totalSize = allChunks.reduce((sum, c) => sum + c.length, 0);
  const result = new Uint8Array(totalSize);
  let pos = 0;
  for (const chunk of allChunks) {
    result.set(chunk, pos);
    pos += chunk.length;
  }

  return result;
}

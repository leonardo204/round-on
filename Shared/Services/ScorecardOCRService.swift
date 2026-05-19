import Vision
import UIKit

// MARK: - OCR 결과 타입

public struct OCRTextLine: Sendable {
    public let text: String
    public let boundingBox: CGRect  // 정규화 좌표 (0~1, 좌상단 원점 변환 완료)
    public let topLeftY: CGFloat    // 행 정렬용 Y (작을수록 위)
    public let leftX: CGFloat

    public init(text: String, boundingBox: CGRect) {
        self.text = text
        self.boundingBox = boundingBox
        // Vision 좌표계는 좌하단 원점 → 상단 원점으로 변환
        self.topLeftY = 1.0 - boundingBox.maxY
        self.leftX = boundingBox.minX
    }
}

public struct OCRPlayer: Sendable {
    public let name: String
    public var scores: [Int]        // 9 또는 18 길이
    public var total: Int?
    public let isOwnerCandidate: Bool  // 마스킹 없는 첫 번째 플레이어

    public init(name: String, scores: [Int], total: Int?, isOwnerCandidate: Bool) {
        self.name = name
        self.scores = scores
        self.total = total
        self.isOwnerCandidate = isOwnerCandidate
    }
}

public struct ScorecardOCRResult: Sendable {
    public let courseName: String?
    public let date: Date?
    public let teeOffTime: String?
    public let frontCourseName: String?
    public let backCourseName: String?
    public let pars: [Int]          // 9 또는 18 길이
    public let players: [OCRPlayer]
    public let rawLines: [OCRTextLine]
    /// 부분 인식 경고 — 편집 화면 상단에 사용자 안내용으로 표시
    public let warnings: [ScorecardOCRWarning]

    public init(
        courseName: String?,
        date: Date?,
        teeOffTime: String?,
        frontCourseName: String?,
        backCourseName: String?,
        pars: [Int],
        players: [OCRPlayer],
        rawLines: [OCRTextLine],
        warnings: [ScorecardOCRWarning] = []
    ) {
        self.courseName = courseName
        self.date = date
        self.teeOffTime = teeOffTime
        self.frontCourseName = frontCourseName
        self.backCourseName = backCourseName
        self.pars = pars
        self.players = players
        self.rawLines = rawLines
        self.warnings = warnings
    }
}

// MARK: - 에러 타입

public enum ScorecardOCRError: LocalizedError {
    case noTextFound
    case insufficientData(reason: String)
    case imageProcessingFailed

    public var errorDescription: String? {
        switch self {
        case .noTextFound:
            return "이미지에서 텍스트를 찾을 수 없어요. 사진이 흐리거나 글자가 작아 보일 수 있어요."
        case .insufficientData(let reason):
            return "스코어카드를 충분히 인식하지 못했어요. (\(reason))\n사진을 다시 찍어 보거나 직접 입력해 보세요."
        case .imageProcessingFailed:
            return "이미지 처리에 실패했어요. 다른 사진으로 시도해 주세요."
        }
    }
}

/// 부분 인식 경고 — par는 잡혔으나 일부 필드가 누락된 경우 사용자에게 알림용.
public enum ScorecardOCRWarning: String, Sendable, CaseIterable {
    case missingCourseName        // 골프장명 인식 못함
    case missingDate              // 날짜 인식 못함
    case missingFrontCourseName   // 전반 코스명
    case missingBackCourseName    // 후반 코스명 (18홀 케이스에서)
    case onlyHalfRound            // 9홀만 인식 (18홀일 수도)
    case noPlayers                // 플레이어 행 0개
    case fewPlayers               // 플레이어 1명 (동반자 인식 못함)

    public var message: String {
        switch self {
        case .missingCourseName:     return "골프장명을 인식하지 못했어요 — 직접 선택해 주세요"
        case .missingDate:           return "날짜를 인식하지 못했어요 — 오늘 날짜로 설정됐어요"
        case .missingFrontCourseName: return "전반 코스명을 인식하지 못했어요"
        case .missingBackCourseName:  return "후반 코스명을 인식하지 못했어요"
        case .onlyHalfRound:         return "9홀만 인식됐어요 — 18홀이라면 후반 정보를 추가해 주세요"
        case .noPlayers:             return "플레이어 점수를 인식하지 못했어요 — 직접 입력해 주세요"
        case .fewPlayers:            return "본인 외 동반자가 인식되지 않았어요 — 필요하면 추가해 주세요"
        }
    }
}

// MARK: - ScorecardOCRService

@MainActor
public enum ScorecardOCRService {

    /// 스코어카드 이미지에서 OCR로 라운드 데이터를 추출합니다.
    /// - Parameter image: UIImage (스마트스코어 정밀 표 형식 권장)
    /// - Returns: ScorecardOCRResult
    public static func recognize(image: UIImage) async throws -> ScorecardOCRResult {
        guard let cgImage = image.cgImage else {
            throw ScorecardOCRError.imageProcessingFailed
        }

        // 1. VNRecognizeTextRequest 실행
        let lines = try await runOCR(on: cgImage)

        guard !lines.isEmpty else {
            throw ScorecardOCRError.noTextFound
        }

        // 2. 파싱
        let result = parse(lines: lines)

        // 3. 최소 데이터 검증
        if result.pars.count < 9 {
            throw ScorecardOCRError.insufficientData(reason: "PAR 정보 \(result.pars.count)개 (최소 9개 필요)")
        }

        return result
    }

    // MARK: - OCR 실행

    private static func runOCR(on cgImage: CGImage) async throws -> [OCRTextLine] {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                var lines: [OCRTextLine] = []
                for obs in observations {
                    guard let topCandidate = obs.topCandidates(1).first else { continue }
                    let line = OCRTextLine(text: topCandidate.string, boundingBox: obs.boundingBox)
                    lines.append(line)
                }

                // Y 좌표 오름차순 (위에서 아래)
                lines.sort { $0.topLeftY < $1.topLeftY }
                continuation.resume(returning: lines)
            }

            request.recognitionLanguages = ["ko-KR", "en-US"]
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false  // 숫자 인식 정확도 우선

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - 파싱 로직

    private static func parse(lines: [OCRTextLine]) -> ScorecardOCRResult {
        // Y 좌표로 행 군집화 (tolerance ±2%)
        let rows = groupIntoRows(lines: lines, tolerance: 0.02)

        var courseName: String? = nil
        var dateFound: Date? = nil
        var teeOffTime: String? = nil
        var frontCourseName: String? = nil
        var backCourseName: String? = nil
        var parRows: [[Int]] = []           // [전반par[], 후반par[]]
        var parRowIndices: [Int] = []       // rows 내 PAR 행 인덱스
        var courseLabels: [String] = []     // PAR 행 위의 라벨 (코스명 후보)
        var players: [OCRPlayer] = []

        // --- 1. 날짜/시간/골프장명 추출 ---
        for row in rows {
            let merged = row.map { $0.text }.joined(separator: " ")

            // DATE 토큰 처리
            if merged.contains("DATE") || merged.contains("date") {
                if let d = extractDate(from: merged) { dateFound = d }
            }
            // 날짜 패턴 직접 탐색 (yyyy/MM/dd 또는 yyyy.MM.dd)
            if dateFound == nil, let d = extractDate(from: merged) {
                dateFound = d
            }

            // TEE OFF 시간
            if merged.contains("TEE") || merged.contains("tee") || merged.contains("티오프") {
                teeOffTime = extractTeeOffTime(from: merged)
            }

            // 골프장명: CC / GC / 컨트리클럽 / 골프장 / 리조트 포함
            if courseName == nil {
                if let cn = extractCourseName(from: merged) {
                    courseName = cn
                }
            }
        }

        // --- 2. PAR 행 탐색 ---
        for (rowIdx, row) in rows.enumerated() {
            let tokens = row.map { $0.text }
            let isParRow = tokens.contains(where: { $0.uppercased() == "PAR" || $0 == "파" })

            if isParRow {
                let nums = extractNineNumbers(from: tokens)
                if nums.count >= 9 {
                    parRows.append(Array(nums.prefix(9)))
                    parRowIndices.append(rowIdx)
                }
            }
        }

        // --- 3. 코스명 (PAR 행 바로 위 행의 첫 토큰) ---
        for parIdx in parRowIndices {
            // PAR 행 위 1~2행에서 코스 라벨 탐색
            for offset in 1...min(3, parIdx) {
                let prevRow = rows[parIdx - offset]
                let prevTokens = prevRow.map { $0.text }
                // TOTAL, PAR 등 예약어 아니면서 한글 1~6자 또는 영문
                if let label = prevTokens.first(where: { isCourseLabelCandidate($0) }) {
                    courseLabels.append(label)
                    break
                }
            }
        }

        if courseLabels.count >= 1 { frontCourseName = courseLabels[0] }
        if courseLabels.count >= 2 { backCourseName = courseLabels[1] }

        // --- 4. 플레이어 행 추출 ---
        // PAR 행 아래 연속되는 숫자 행들 → 플레이어
        var processedPlayerNames: Set<String> = []

        for (pIdx, parRowIdx) in parRowIndices.enumerated() {
            let parNums = parRows[pIdx]  // 이 코스의 par
            var localPlayers: [(name: String, scores: [Int], total: Int?)] = []

            var scanIdx = parRowIdx + 1
            while scanIdx < rows.count {
                let row = rows[scanIdx]
                let tokens = row.map { $0.text }

                // 다음 PAR 행이거나 빈 행이면 중단
                if tokens.contains(where: { $0.uppercased() == "PAR" || $0 == "파" }) { break }
                // 숫자가 3개 미만이면 플레이어 행이 아님
                let nums = extractNineNumbers(from: tokens)
                if nums.count < 3 { break }

                // 첫 토큰이 플레이어 이름 (숫자 아님, 길이 1~8)
                guard let nameToken = tokens.first(where: { isPlayerName($0) }) else {
                    scanIdx += 1
                    continue
                }

                // total: 마지막 숫자 (TOTAL 열 = 9번 인덱스 이후)
                let allNums = extractAllScoreNumbers(from: tokens)
                let scores9 = allNums.count >= 9 ? Array(allNums.prefix(9)) : Array(allNums.prefix(allNums.count))
                let total = allNums.count >= 10 ? allNums[9] : nil

                localPlayers.append((name: nameToken, scores: scores9, total: total))
                _ = parNums  // suppress unused warning
                scanIdx += 1
            }

            // localPlayers를 players에 병합 (이름 기준 중복 제거 + 후반 스코어 합산)
            for lp in localPlayers {
                if processedPlayerNames.contains(lp.name) {
                    // 후반 스코어를 기존 플레이어에 append
                    if let idx = players.firstIndex(where: { $0.name == lp.name }) {
                        let existing = players[idx]
                        let merged9 = existing.scores + lp.scores
                        let newTotal = (existing.total ?? 0) + (lp.total ?? lp.scores.reduce(0, +))
                        players[idx] = OCRPlayer(
                            name: existing.name,
                            scores: merged9,
                            total: newTotal,
                            isOwnerCandidate: existing.isOwnerCandidate
                        )
                    }
                } else {
                    processedPlayerNames.insert(lp.name)
                    // 첫 번째 비마스킹 이름이 owner 후보
                    let isOwner = players.isEmpty || (!lp.name.contains("*") && players.allSatisfy { !$0.isOwnerCandidate })
                    players.append(OCRPlayer(
                        name: lp.name,
                        scores: lp.scores,
                        total: lp.total,
                        isOwnerCandidate: isOwner
                    ))
                }
            }
        }

        // --- 5. pars 합산 ---
        let pars: [Int]
        if parRows.count == 1 {
            pars = parRows[0]
        } else if parRows.count >= 2 {
            pars = parRows[0] + parRows[1]
        } else {
            pars = []
        }

        // 부분 인식 경고 진단
        var warnings: [ScorecardOCRWarning] = []
        if courseName == nil { warnings.append(.missingCourseName) }
        if dateFound == nil { warnings.append(.missingDate) }
        if frontCourseName == nil { warnings.append(.missingFrontCourseName) }
        if pars.count == 9 { warnings.append(.onlyHalfRound) }
        if pars.count >= 18 && backCourseName == nil { warnings.append(.missingBackCourseName) }
        if players.isEmpty {
            warnings.append(.noPlayers)
        } else if players.count == 1 {
            warnings.append(.fewPlayers)
        }

        return ScorecardOCRResult(
            courseName: courseName,
            date: dateFound,
            teeOffTime: teeOffTime,
            frontCourseName: frontCourseName,
            backCourseName: backCourseName,
            pars: pars,
            players: players,
            rawLines: lines,
            warnings: warnings
        )
    }

    // MARK: - 행 군집화

    /// Y 좌표 tolerance 이내 라인들을 하나의 행으로 묶음
    private static func groupIntoRows(lines: [OCRTextLine], tolerance: CGFloat) -> [[OCRTextLine]] {
        guard !lines.isEmpty else { return [] }

        var rows: [[OCRTextLine]] = []
        var currentRow: [OCRTextLine] = [lines[0]]
        var currentY = lines[0].topLeftY

        for line in lines.dropFirst() {
            if abs(line.topLeftY - currentY) <= tolerance {
                currentRow.append(line)
            } else {
                // X 좌표 기준으로 정렬 후 저장
                rows.append(currentRow.sorted { $0.leftX < $1.leftX })
                currentRow = [line]
                currentY = line.topLeftY
            }
        }
        rows.append(currentRow.sorted { $0.leftX < $1.leftX })
        return rows
    }

    // MARK: - 숫자 추출

    /// 토큰 배열에서 0~15 범위 정수 9개 추출 (PAR 행용)
    private static func extractNineNumbers(from tokens: [String]) -> [Int] {
        tokens
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            .filter { $0 >= 2 && $0 <= 6 }  // par는 2~6 범위
    }

    /// 토큰 배열에서 0~20 범위 정수 추출 (스코어용, TOTAL 포함)
    private static func extractAllScoreNumbers(from tokens: [String]) -> [Int] {
        tokens
            .compactMap { token -> Int? in
                let trimmed = token.trimmingCharacters(in: .whitespaces)
                guard let n = Int(trimmed) else { return nil }
                return (0...99).contains(n) ? n : nil
            }
    }

    // MARK: - 날짜 추출

    private static func extractDate(from text: String) -> Date? {
        // yyyy/MM/dd 또는 yyyy.MM.dd 또는 yyyy-MM-dd
        let patterns = [
            #"(\d{4})[/.\-](\d{1,2})[/.\-](\d{1,2})"#
        ]
        for pattern in patterns {
            if let match = text.range(of: pattern, options: .regularExpression) {
                let sub = String(text[match])
                let sep = sub.first(where: { "/.-".contains($0) }) ?? "/"
                let parts = sub.components(separatedBy: String(sep))
                if parts.count == 3,
                   let year = Int(parts[0]),
                   let month = Int(parts[1]),
                   let day = Int(parts[2]) {
                    var comps = DateComponents()
                    comps.year = year
                    comps.month = month
                    comps.day = day
                    return Calendar.current.date(from: comps)
                }
            }
        }
        return nil
    }

    private static func extractTeeOffTime(from text: String) -> String? {
        // AM/PM HH:mm 또는 HH:mm 패턴
        let pattern = #"(AM|PM|am|pm)?\s*(\d{1,2}:\d{2})"#
        if let match = text.range(of: pattern, options: .regularExpression) {
            return String(text[match]).trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    // MARK: - 골프장명 추출

    private static func extractCourseName(from text: String) -> String? {
        let keywords = ["CC", "GC", "컨트리클럽", "골프클럽", "골프장", "리조트", "밸리", "힐스", "파크"]
        for keyword in keywords {
            if text.contains(keyword) {
                // 해당 키워드를 포함한 첫 단어 집합 추출
                let tokens = text.components(separatedBy: .whitespaces)
                // 키워드가 포함된 토큰 또는 그 앞 토큰들 합산
                for (i, token) in tokens.enumerated() {
                    if token.contains(keyword) {
                        // 앞 토큰 + 현재 토큰 (예: "진양밸리 CC" → "진양밸리CC")
                        if i > 0 {
                            let combined = tokens[i-1] + token
                            if combined.count <= 20 { return combined }
                        }
                        if token.count <= 20 { return token }
                    }
                }
            }
        }
        return nil
    }

    // MARK: - 코스 라벨 판별

    private static func isCourseLabelCandidate(_ text: String) -> Bool {
        let reserved = ["PAR", "Par", "파", "TOTAL", "합", "합계", "DATE", "TEE", "OFF"]
        guard !reserved.contains(text) else { return false }
        guard text.count >= 1 && text.count <= 8 else { return false }
        // 순수 숫자면 제외
        if Int(text) != nil { return false }
        return true
    }

    // MARK: - 플레이어 이름 판별

    private static func isPlayerName(_ text: String) -> Bool {
        guard text.count >= 2 && text.count <= 8 else { return false }
        // 순수 숫자면 제외
        if Int(text) != nil { return false }
        let reserved = ["PAR", "Par", "파", "TOTAL", "합", "합계", "DATE", "TEE", "OFF", "힐", "크리크", "동", "서", "남", "북"]
        if reserved.contains(text) { return false }
        return true
    }
}

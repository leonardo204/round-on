import Foundation
import ImageIO

// MARK: - GeminiScorecardAdapter
// GeminiScorecard → Scorecard(기존 모델) 변환.
//
// ★ 계획서의 "GeminiScorecard→Round 직접 매핑"은 틀렸다.
//   기존 파이프라인: Scorecard → ScorecardImportDraft → Round
//   이 어댑터는 GeminiScorecard를 Scorecard로 변환해 기존 ScorecardMapper를 재사용한다.
//
// 변환 규칙:
//   - par행이 있으면: values(delta) + par[i] = 실제 타수로 ScoreRow 구성
//   - par행이 없으면(앱스샷): 홀별 상세 없이 out/inScore/total만 신뢰하는 단순 Scorecard
//   - owner: isOwner==true인 행 → leadPlayerName/leadPlayerTotal
//   - courseName, date 매핑
//   - 날짜 정규화: . / → - 치환 후 파싱, 실패 시 EXIF 폴백
//
// 어댑터 목표 타입: Scorecard(Shared/OCR/Models.swift)
//   ScoreTable(sectionName, columns, rows)
//   ScoreRow(label, kind: .par/.player, values: [ScoreValue?])
//   ScoreColumn(key, title, kind: .label/.hole/.subtotal/.total)

public enum GeminiScorecardAdapter {

    // MARK: - 공개 API

    /// GeminiScorecard → Scorecard 변환.
    /// - Parameters:
    ///   - gemini: Gemini 응답 파싱 결과
    ///   - imageData: EXIF 날짜 폴백용 원본 이미지 데이터 (nil이면 EXIF 폴백 생략)
    /// - Returns: 기존 ScorecardMapper와 호환되는 Scorecard
    public static func adapt(
        _ gemini: GeminiScorecard,
        imageData: Data? = nil
    ) -> Scorecard {
        let resolvedDate = resolveDateText(gemini.date, imageData: imageData)
        let hasParRow = gemini.parRow != nil

        let tables: [ScoreTable]
        if hasParRow {
            tables = buildTablesWithPar(gemini)
        } else {
            // 앱스샷: par행 없음 → 합계 중심 단순 테이블
            tables = buildTablesSummaryOnly(gemini)
        }

        return Scorecard(
            clubName: gemini.courseName.isEmpty ? nil : gemini.courseName,
            dateText: resolvedDate,
            tables: tables,
            warnings: []
        )
    }

    // MARK: - par행 있을 때: 홀별 실타수 구성

    /// par행이 있는 경우 전반/후반을 분리해 두 개의 ScoreTable로 구성한다.
    private static func buildTablesWithPar(_ gemini: GeminiScorecard) -> [ScoreTable] {
        guard let parRow = gemini.parRow else { return [] }
        let parValues = parRow.values
        let holeCount = parValues.count
        let sections = holeCount == 18 ? 2 : 1  // 18홀이면 전/후반 분리

        var tables: [ScoreTable] = []

        for section in 0..<sections {
            let startHole = section * 9
            let endHole = min(startHole + 9, holeCount)
            let sectionPars = Array(parValues[startHole..<endHole])
            let sectionHoleCount = sectionPars.count
            let sectionName = sections == 2 ? (section == 0 ? "전반" : "후반") : "전반"

            // 컬럼 구성: 라벨 + 홀 번호들 + 소계
            var columns: [ScoreColumn] = [
                ScoreColumn(key: "label", title: "", kind: .label)
            ]
            for h in 0..<sectionHoleCount {
                let holeNum = startHole + h + 1
                columns.append(ScoreColumn(key: "h\(holeNum)", title: "\(holeNum)", kind: .hole))
            }
            columns.append(ScoreColumn(key: "out", title: section == 0 ? "OUT" : "IN", kind: .subtotal))

            // par행 구성
            var parSectionValues: [ScoreValue?] = sectionPars.map {
                ScoreValue(raw: "\($0)", intValue: $0)
            }
            // 소계 컬럼 값 (par합)
            let parSubtotal = sectionPars.reduce(0, +)
            parSectionValues.append(ScoreValue(raw: "\(parSubtotal)", intValue: parSubtotal))
            let parScoreRow = ScoreRow(label: "PAR", kind: .par, values: parSectionValues)

            // player행 구성
            var playerRows: [ScoreRow] = []
            for player in gemini.players {
                let playerDeltas: [Int]
                if player.values.count == holeCount {
                    playerDeltas = Array(player.values[startHole..<endHole])
                } else if player.values.count == sectionHoleCount {
                    // 섹션 크기만 있는 경우
                    playerDeltas = player.values
                } else {
                    // 데이터 없으면 0으로 패딩
                    playerDeltas = Array(repeating: 0, count: sectionHoleCount)
                }

                // delta → 실제 타수 (par + delta)
                var rowValues: [ScoreValue?] = zip(sectionPars, playerDeltas).map { par, delta in
                    let actual = par + delta
                    return ScoreValue(raw: "\(actual)", intValue: actual)
                }
                // 소계: section별 실제 타수 합
                let subtotal = section == 0 ? player.out : player.inScore
                rowValues.append(ScoreValue(raw: "\(subtotal)", intValue: subtotal))

                playerRows.append(ScoreRow(label: player.label, kind: .player, values: rowValues))
            }

            let rows: [ScoreRow] = [parScoreRow] + playerRows
            tables.append(ScoreTable(sectionName: sectionName, columns: columns, rows: rows))
        }

        return tables
    }

    // MARK: - par행 없을 때: 합계만 신뢰 (앱스샷 기본 경로)

    /// 앱스샷처럼 par행이 없으면 out/inScore/total 합계값만으로 단순 테이블 구성.
    /// 홀별 실타수는 만들 수 없으므로 ScoreRow.values에 nil 채움.
    /// ScorecardMapper.makeDraft는 parRow가 nil일 때 holes를 nil 취급하므로 호환된다.
    private static func buildTablesSummaryOnly(_ gemini: GeminiScorecard) -> [ScoreTable] {
        // 9홀 vs 18홀 판별: ScorecardValidator.inferHoleCount와 동일한 기준을 사용한다.
        // par행이 없는 경우 inScore==0 + values.count<=9 를 9홀로 강등하지 않는다.
        // (IMG_1358 back9 누락 시그니처와 실제 9홀 앱스샷이 동일하게 보이기 때문)
        // → par행 없으면 18홀 가정. 실제 9홀 라운드는 par행 9개로 buildTablesWithPar 경로를 탄다.
        let is9hole = gemini.parRow.map { $0.values.count == 9 } ?? false

        // 전반 섹션 (항상)
        let frontSection = buildSummarySection(
            name: "전반",
            players: gemini.players,
            sectionIndex: 0,
            is9hole: is9hole
        )

        if is9hole {
            return [frontSection]
        }

        // 후반 섹션
        let backSection = buildSummarySection(
            name: "후반",
            players: gemini.players,
            sectionIndex: 1,
            is9hole: false
        )

        return [frontSection, backSection]
    }

    private static func buildSummarySection(
        name: String,
        players: [GeminiRow],
        sectionIndex: Int,
        is9hole: Bool
    ) -> ScoreTable {
        // 합계 컬럼만 (홀 상세 없음)
        let columns: [ScoreColumn] = [
            ScoreColumn(key: "label", title: "", kind: .label),
            ScoreColumn(key: "subtotal", title: sectionIndex == 0 ? "OUT" : "IN", kind: .subtotal)
        ]

        var rows: [ScoreRow] = []
        for player in players {
            let subtotal = sectionIndex == 0 ? player.out : player.inScore
            let row = ScoreRow(
                label: player.label,
                kind: .player,
                values: [ScoreValue(raw: "\(subtotal)", intValue: subtotal)]
            )
            rows.append(row)
        }

        return ScoreTable(sectionName: name, columns: columns, rows: rows)
    }

    // MARK: - 날짜 정규화 + EXIF 폴백

    /// Gemini date 정규화: . / → - 치환 후 YYYY-MM-DD 파싱.
    /// 실패 시 이미지 EXIF DateTimeOriginal 폴백.
    /// Returns: "yyyy/MM/dd" 형식 문자열 (ScorecardMapper.parseDate 호환)
    public static func resolveDateText(_ geminiDate: String, imageData: Data?) -> String? {
        // . 또는 / → - 로 정규화
        let normalized = geminiDate
            .replacingOccurrences(of: ".", with: "-")
            .replacingOccurrences(of: "/", with: "-")

        // YYYY-MM-DD 파싱 시도
        let iso = DateFormatter()
        iso.dateFormat = "yyyy-MM-dd"
        iso.locale = Locale(identifier: "en_US_POSIX")

        if let date = iso.date(from: normalized) {
            // ScorecardMapper.parseDate 가 "yyyy/MM/dd" 를 기대하므로 변환
            let out = DateFormatter()
            out.dateFormat = "yyyy/MM/dd"
            out.locale = Locale(identifier: "en_US_POSIX")
            return out.string(from: date)
        }

        // EXIF 폴백
        if let data = imageData, let exifDate = exifDateFromImageData(data) {
            let out = DateFormatter()
            out.dateFormat = "yyyy/MM/dd"
            out.locale = Locale(identifier: "en_US_POSIX")
            return out.string(from: exifDate)
        }

        return nil
    }

    /// ImageIO를 사용해 이미지 데이터에서 EXIF DateTimeOriginal을 추출한다.
    private static func exifDateFromImageData(_ data: Data) -> Date? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
              let exif = props["{Exif}"] as? [String: Any],
              let dateStr = exif["DateTimeOriginal"] as? String else {
            return nil
        }
        // EXIF 형식: "2026:05:25 10:30:00"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: dateStr)
    }
}

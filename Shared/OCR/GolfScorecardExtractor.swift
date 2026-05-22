import CoreGraphics
import CoreImage
import Foundation
import ImageIO

public final class GolfScorecardExtractor {
    private let recognizer: TextRecognizing
    private let options: ScorecardExtractorOptions
    private let ciContext = CIContext(options: nil)

    public init(
        recognizer: TextRecognizing = VisionTextRecognizer(),
        options: ScorecardExtractorOptions = .init()
    ) {
        self.recognizer = recognizer
        self.options = options
    }

    public func extract(from imageURL: URL) throws -> Scorecard {
        let image = try loadCGImage(from: imageURL)
        return try extract(from: image, sourceImagePath: imageURL.path)
    }

    public func extract(from image: CGImage, sourceImagePath: String? = nil) throws -> Scorecard {
        let scoreRegion = detectScoreRegion(in: image)
        let scoreImage = image.cropping(to: scoreRegion.integral) ?? image
        let tokens = try recognizeTableTokens(in: scoreImage)
        let rows = clusterRows(from: tokens)
        let sectionBounds = rows.compactMap { row -> CGFloat? in
            isHeaderRow(row) ? row.bounds.minY : nil
        }
        let metadata = extractMetadata(from: rows, firstSectionTop: sectionBounds.min() ?? CGFloat(scoreImage.height))
        let tables = try parseTables(from: rows, in: scoreImage)

        var warnings: [String] = []
        if tables.isEmpty {
            warnings.append("No score tables were reconstructed from OCR tokens.")
            warnings.append(
                "OCR rows: " + rows
                    .prefix(18)
                    .map(\.text)
                    .joined(separator: " || ")
            )
        }

        return Scorecard(
            sourceImagePath: sourceImagePath,
            clubName: metadata.clubName,
            dateText: metadata.dateText,
            teeOffText: metadata.teeOffText,
            leadPlayerName: metadata.leadPlayerName,
            leadPlayerTotal: metadata.leadPlayerTotal,
            tables: tables,
            warnings: warnings
        )
    }
}

private extension GolfScorecardExtractor {
    struct RowCluster {
        var tokens: [RecognizedToken]
        var bounds: CGRect

        var text: String {
            tokens.map(\.text).joined(separator: " ")
        }
    }

    struct Metadata {
        var clubName: String?
        var dateText: String?
        var teeOffText: String?
        var leadPlayerName: String?
        var leadPlayerTotal: Int?
        var ownerClubCandidate: String?
    }

    struct SectionParseResult {
        var table: ScoreTable
        var nextIndex: Int
    }

    struct GridLayout {
        var valueCenters: [CGFloat]
        var labelRightEdge: CGFloat
        var columnRects: [ClosedRange<CGFloat>]
    }

    func loadCGImage(from url: URL) throws -> CGImage {
        guard
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw NSError(domain: "GolfScorecardOCR", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Unable to decode image at \(url.path)"
            ])
        }

        return image
    }

    func recognizeTableTokens(in image: CGImage) throws -> [RecognizedToken] {
        let config = OCRConfiguration(
            languages: options.languages,
            usesLanguageCorrection: false,
            minimumTextHeight: 0.012,
            recognitionLevel: .accurate
        )

        return try recognizer
            .recognizeText(in: image, configuration: config)
            .map { token in
                var cleaned = token
                cleaned.text = normalizeWhitespace(in: token.text)
                return cleaned
            }
            .filter { !$0.text.isEmpty && $0.confidence >= options.minimumTokenConfidence }
            .sorted {
                if abs($0.midY - $1.midY) > 2 {
                    return $0.midY < $1.midY
                }
                return $0.midX < $1.midX
            }
    }

    func detectScoreRegion(in image: CGImage) -> CGRect {
        guard let detector = BlueBandDetector(image: image) else {
            return CGRect(
                x: 0,
                y: 0,
                width: CGFloat(image.width) * options.scoreRegionFallbackLeftRatio,
                height: CGFloat(image.height)
            )
        }

        if let detected = detector.detectScoreRegion(leftRatioLimit: 0.62) {
            return detected
        }

        return CGRect(
            x: 0,
            y: 0,
            width: CGFloat(image.width) * options.scoreRegionFallbackLeftRatio,
            height: CGFloat(image.height)
        )
    }

    func clusterRows(from tokens: [RecognizedToken]) -> [RowCluster] {
        guard !tokens.isEmpty else { return [] }

        let heights = tokens.map { max($0.rect.height, 1) }.sorted()
        let medianHeight = heights[heights.count / 2]
        let threshold = max(12, medianHeight * 0.8)

        var rows: [[RecognizedToken]] = []

        for token in tokens {
            if var last = rows.last {
                let centers = last.map(\.midY)
                let rowCenter = centers.reduce(0, +) / CGFloat(centers.count)
                if abs(token.midY - rowCenter) <= threshold {
                    last.append(token)
                    rows[rows.count - 1] = last
                    continue
                }
            }
            rows.append([token])
        }

        return rows.map { rowTokens in
            let sortedTokens = rowTokens.sorted { $0.midX < $1.midX }
            let bounds = sortedTokens.dropFirst().reduce(sortedTokens[0].rect) { partial, token in
                partial.union(token.rect)
            }
            return RowCluster(tokens: sortedTokens, bounds: bounds)
        }
    }

    func parseTables(from rows: [RowCluster], in image: CGImage) throws -> [ScoreTable] {
        var tables: [ScoreTable] = []
        var index = 0

        while index < rows.count {
            if let parsed = try parseTable(startingAt: index, rows: rows, image: image) {
                tables.append(parsed.table)
                index = parsed.nextIndex
            } else {
                index += 1
            }
        }

        return tables
    }

    func parseTable(startingAt index: Int, rows: [RowCluster], image: CGImage) throws -> SectionParseResult? {
        let headerRow = rows[index]
        guard isHeaderRow(headerRow) else {
            return nil
        }

        var endIndex = index + 1
        while endIndex < rows.count {
            if isHeaderRow(rows[endIndex]) {
                break
            }

            if isBannerRow(rows[endIndex]) {
                break
            }

            endIndex += 1
        }

        let candidateRows = Array(rows[(index + 1)..<endIndex])
        guard !candidateRows.isEmpty else {
            return nil
        }
        let holeCount = inferHoleCount(from: headerRow)
        guard holeCount >= options.minimumHeaderHoleCount else {
            return nil
        }

        let maxNumericCount = candidateRows.map { numericTokens(in: $0).count }.max() ?? holeCount
        let summaryCount = max(0, maxNumericCount - holeCount)
        let columns = buildColumns(for: holeCount, summaryCount: summaryCount)
        let gridLayout = buildGridLayout(
            headerRow: headerRow,
            candidateRows: candidateRows,
            expectedValueCount: holeCount + summaryCount
        )

        var parsedRows: [ScoreRow] = []
        for rowIndex in (index + 1)..<endIndex {
            let row = rows[rowIndex]
            guard let parsedRow = try parseScoreRow(
                row,
                kind: rowIndex == index + 1 ? .par : .player,
                expectedValueCount: holeCount + summaryCount,
                gridLayout: gridLayout,
                image: image
            ) else {
                continue
            }
            parsedRows.append(parsedRow)
        }

        let table = ScoreTable(
            sectionName: sanitizeSectionName(labelText(for: headerRow)),
            columns: columns,
            rows: parsedRows
        )

        return SectionParseResult(table: table, nextIndex: endIndex)
    }

    func buildColumns(for holeCount: Int, summaryCount: Int) -> [ScoreColumn] {
        var columns: [ScoreColumn] = [
            ScoreColumn(key: "label", title: "label", kind: .label)
        ]

        for index in 1...holeCount {
            columns.append(ScoreColumn(key: "hole_\(index)", title: "\(index)", kind: .hole))
        }

        if summaryCount == 1 {
            columns.append(ScoreColumn(key: "total", title: "TOTAL", kind: .total))
        } else if summaryCount == 2 {
            columns.append(ScoreColumn(key: "subtotal", title: "SUBTOTAL", kind: .subtotal))
            columns.append(ScoreColumn(key: "total", title: "TOTAL", kind: .total))
        } else if summaryCount > 2 {
            for index in 0..<summaryCount {
                let kind: ScoreColumn.Kind = index == summaryCount - 1 ? .total : .extra
                columns.append(ScoreColumn(key: "summary_\(index + 1)", title: "SUMMARY\(index + 1)", kind: kind))
            }
        }

        return columns
    }

    func buildGridLayout(
        headerRow: RowCluster,
        candidateRows: [RowCluster],
        expectedValueCount: Int
    ) -> GridLayout? {
        var buckets = Array(repeating: [CGFloat](), count: expectedValueCount)
        let usefulRows = [headerRow] + candidateRows

        for row in usefulRows {
            let tokens = numericTokens(in: row)
            guard tokens.count >= expectedValueCount else { continue }
            for (index, token) in tokens.prefix(expectedValueCount).enumerated() {
                buckets[index].append(token.midX)
            }
        }

        let centers = buckets.compactMap { bucket -> CGFloat? in
            guard !bucket.isEmpty else { return nil }
            return median(bucket)
        }

        guard centers.count == expectedValueCount else {
            return nil
        }

        let labelEdges = ([headerRow] + candidateRows).compactMap { row -> CGFloat? in
            let nonNumeric = row.tokens.prefix { parseNumericValue(from: $0.text) == nil }
            return nonNumeric.last?.rect.maxX
        }
        let labelRightEdge = labelEdges.max() ?? 0

        var ranges: [ClosedRange<CGFloat>] = []
        for index in centers.indices {
            let left: CGFloat
            let right: CGFloat

            if index == 0 {
                let nextGap = centers.count > 1 ? (centers[1] - centers[0]) / 2 : 20
                left = max(labelRightEdge + 4, centers[0] - nextGap)
            } else {
                left = (centers[index - 1] + centers[index]) / 2
            }

            if index == centers.count - 1 {
                let prevGap = centers.count > 1 ? (centers[index] - centers[index - 1]) / 2 : 20
                right = centers[index] + prevGap
            } else {
                right = (centers[index] + centers[index + 1]) / 2
            }

            ranges.append(left...right)
        }

        return GridLayout(valueCenters: centers, labelRightEdge: labelRightEdge, columnRects: ranges)
    }

    func parseScoreRow(
        _ row: RowCluster,
        kind: ScoreRow.Kind,
        expectedValueCount: Int,
        gridLayout: GridLayout?,
        image: CGImage
    ) throws -> ScoreRow? {
        let baseLabel = sanitizeLabel(labelText(for: row))
        let label = kind == .par
            ? ((baseLabel.isEmpty || parseNumericValue(from: baseLabel) != nil) ? "PAR" : baseLabel)
            : baseLabel
        guard !label.isEmpty else { return nil }

        if kind == .player && numericTokens(in: row).isEmpty {
            return nil
        }

        var values = Array<ScoreValue?>(repeating: nil, count: expectedValueCount)
        let orderedNumericTokens = numericTokens(in: row).sorted { $0.midX < $1.midX }

        if let gridLayout {
            for token in orderedNumericTokens {
                guard let value = parseNumericValue(from: token.text) else { continue }
                if let slot = slotIndex(for: token.midX, in: gridLayout.columnRects) {
                    values[slot] = ScoreValue(raw: "\(value)", intValue: value)
                }
            }

            if options.performCellRecognition {
                let rowRect = row.bounds.insetBy(dx: -4, dy: -4)
                for index in values.indices where values[index] == nil {
                    if let recognized = try recognizeCellValue(
                        at: index,
                        rowRect: rowRect,
                        layout: gridLayout,
                        in: image
                    ) {
                        values[index] = recognized
                    }
                }
            }
        } else {
            for (index, token) in orderedNumericTokens.prefix(expectedValueCount).enumerated() {
                guard let value = parseNumericValue(from: token.text) else { continue }
                values[index] = ScoreValue(raw: "\(value)", intValue: value)
            }
        }

        return ScoreRow(label: label, kind: kind, values: values)
    }

    func recognizeCellValue(
        at columnIndex: Int,
        rowRect: CGRect,
        layout: GridLayout,
        in image: CGImage
    ) throws -> ScoreValue? {
        guard columnIndex < layout.columnRects.count else { return nil }

        let xRange = layout.columnRects[columnIndex]
        let cellRect = CGRect(
            x: xRange.lowerBound,
            y: rowRect.minY,
            width: xRange.upperBound - xRange.lowerBound,
            height: rowRect.height
        )
        .insetBy(dx: -2, dy: -2)
        .intersection(CGRect(x: 0, y: 0, width: CGFloat(image.width), height: CGFloat(image.height)))

        guard cellRect.width > 6, cellRect.height > 6, let cropped = image.cropping(to: cellRect.integral) else {
            return nil
        }

        let variants = [cropped, makeHighContrastImage(from: cropped)].compactMap { $0 }
        let config = OCRConfiguration(
            languages: ["en-US"],
            usesLanguageCorrection: false,
            minimumTextHeight: 0.1,
            recognitionLevel: .accurate
        )

        var bestCandidate: (Int, Float)?

        for variant in variants {
            let tokens = try recognizer.recognizeText(in: variant, configuration: config)
            for token in tokens {
                guard let value = parseNumericValue(from: token.text) else { continue }
                if bestCandidate == nil || token.confidence > bestCandidate!.1 {
                    bestCandidate = (value, token.confidence)
                }
            }
        }

        guard let bestCandidate else { return nil }
        return ScoreValue(raw: "\(bestCandidate.0)", intValue: bestCandidate.0)
    }

    func makeHighContrastImage(from image: CGImage) -> CGImage? {
        let ciImage = CIImage(cgImage: image)
            .applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: 0,
                kCIInputContrastKey: 1.9,
                kCIInputBrightnessKey: 0.08
            ])
            .applyingFilter("CIExposureAdjust", parameters: [
                kCIInputEVKey: 0.5
            ])

        return ciContext.createCGImage(ciImage, from: ciImage.extent)
    }

    func extractMetadata(from rows: [RowCluster], firstSectionTop: CGFloat) -> Metadata {
        let topRows = rows.filter { $0.bounds.minY < firstSectionTop - 10 }
        var metadata = Metadata()

        if let dateRow = topRows.first(where: { normalizedText($0.text).contains("DATE") }) {
            metadata.dateText = dateRow.tokens
                .compactMap { token in
                    let value = token.text.replacingOccurrences(of: " ", with: "")
                    return value.range(of: #"\d{4}/\d{1,2}/\d{1,2}"#, options: .regularExpression) != nil ? value : nil
                }
                .first
        }

        if let teeRow = topRows.first(where: {
            let value = normalizedText($0.text)
            return value.contains("TEEOFF") || value.contains("TEEOFF")
        }) {
            metadata.teeOffText = teeRow.tokens
                .map(\.text)
                .filter { parseClockText(from: $0) != nil || normalizedText($0).contains("AM") || normalizedText($0).contains("PM") }
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespaces)
        }

        if let ownerRow = topRows
            .filter({ numericTokens(in: $0).count == 1 })
            .max(by: { $0.bounds.height < $1.bounds.height })
        {
            let labelTokens = ownerRow.tokens.filter { parseNumericValue(from: $0.text) == nil }.map(\.text)
            metadata.leadPlayerName = sanitizeLabel(labelTokens.last ?? "")
            metadata.ownerClubCandidate = sanitizeLabel(labelTokens.dropLast().joined(separator: " "))
            metadata.leadPlayerTotal = numericTokens(in: ownerRow).compactMap { parseNumericValue(from: $0.text) }.first
        }

        let leftTopRows = topRows.filter { $0.bounds.minX < 360 }
        let clubNameParts = leftTopRows
            .filter {
                let value = normalizedText($0.text)
                return !value.contains("SMARTSCORE") && !value.contains("DATE") && !value.contains("TEEOFF")
            }
            .prefix(2)
            .map(\.text)
            .map { sanitizeLabel($0) }
            .filter { !$0.isEmpty }
        metadata.clubName = clubNameParts.isEmpty ? nil : clubNameParts.joined(separator: " ")
        if let ownerClubCandidate = metadata.ownerClubCandidate, !ownerClubCandidate.isEmpty {
            if metadata.clubName == nil || metadata.clubName == metadata.leadPlayerName || metadata.clubName?.contains(metadata.leadPlayerName ?? "") == true {
                metadata.clubName = ownerClubCandidate
            }
        }

        return metadata
    }

    func inferHoleCount(from headerRow: RowCluster) -> Int {
        let numericTokens = numericTokens(in: headerRow)
        var expected = 1
        var count = 0

        for token in numericTokens {
            guard let value = parseNumericValue(from: token.text) else { continue }
            if value == expected {
                count += 1
                expected += 1
            }
        }

        return count
    }

    func isHeaderRow(_ row: RowCluster) -> Bool {
        guard row.tokens.count >= 7 else { return false }
        guard numericTokens(in: row).count >= options.minimumHeaderHoleCount else { return false }

        let ascendingHoleCount = inferHoleCount(from: row)
        if ascendingHoleCount < options.minimumHeaderHoleCount {
            return false
        }

        let normalized = normalizedText(row.text)
        return !normalized.contains("DATE") && !normalized.contains("TEEOFF")
    }

    func isParRow(_ row: RowCluster?) -> Bool {
        guard let row else { return false }
        let normalized = normalizedText(row.text)
        return normalized.contains("PAR") && numericTokens(in: row).count >= options.minimumHeaderHoleCount
    }

    func isBannerRow(_ row: RowCluster) -> Bool {
        let normalized = normalizedText(row.text)
        return normalized.contains("SMARTSCORE")
    }

    func numericTokens(in row: RowCluster) -> [RecognizedToken] {
        row.tokens.filter { parseNumericValue(from: $0.text) != nil }
    }

    func labelText(for row: RowCluster) -> String {
        let prefixTokens = row.tokens.prefix { parseNumericValue(from: $0.text) == nil }
        let label = prefixTokens.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespaces)
        return label.isEmpty ? row.tokens.first?.text ?? "" : label
    }

    func slotIndex(for x: CGFloat, in ranges: [ClosedRange<CGFloat>]) -> Int? {
        for (index, range) in ranges.enumerated() where range.contains(x) {
            return index
        }

        guard let nearest = ranges.enumerated().min(by: {
            abs(x - midpoint(of: $0.element)) < abs(x - midpoint(of: $1.element))
        }) else {
            return nil
        }

        return nearest.offset
    }

    func sanitizeSectionName(_ value: String) -> String {
        let text = sanitizeLabel(value)
        return text.isEmpty ? "Section" : text
    }

    func sanitizeLabel(_ value: String) -> String {
        normalizeWhitespace(in: value)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-_:| "))
    }

    func normalizeWhitespace(in value: String) -> String {
        value.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    func normalizedText(_ value: String) -> String {
        value
            .uppercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "|", with: "I")
    }

    func parseNumericValue(from value: String) -> Int? {
        let uppercased = value.uppercased()
        let mapped = uppercased.map { character -> Character in
            switch character {
            case "O", "D", "Q":
                return "0"
            case "I", "L", "|", "!":
                return "1"
            case "S":
                return "5"
            case "B":
                return "8"
            case "Z":
                return "2"
            default:
                return character
            }
        }

        let digits = String(mapped).filter(\.isNumber)
        guard !digits.isEmpty, let number = Int(digits) else {
            return nil
        }

        return number
    }

    func parseClockText(from value: String) -> String? {
        let compact = value.replacingOccurrences(of: " ", with: "")
        guard compact.range(of: #"(AM|PM)?\d{1,2}[:.]\d{2}"#, options: .regularExpression) != nil else {
            return nil
        }
        return compact.replacingOccurrences(of: ".", with: ":")
    }

    func safeRow(_ rows: [RowCluster], _ index: Int) -> RowCluster? {
        guard rows.indices.contains(index) else { return nil }
        return rows[index]
    }

    func median(_ values: [CGFloat]) -> CGFloat {
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }

    func midpoint(of range: ClosedRange<CGFloat>) -> CGFloat {
        (range.lowerBound + range.upperBound) / 2
    }
}

private struct BlueBandDetector {
    private let width: Int
    private let height: Int
    private let bytesPerRow: Int
    private let data: [UInt8]
    private let scaleX: CGFloat
    private let scaleY: CGFloat

    init?(image: CGImage) {
        let targetWidth = min(420, image.width)
        let targetHeight = max(1, Int(CGFloat(targetWidth) * CGFloat(image.height) / CGFloat(image.width)))

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixels = [UInt8](repeating: 0, count: targetWidth * targetHeight * 4)

        guard let context = CGContext(
            data: &pixels,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: targetWidth * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))

        self.width = targetWidth
        self.height = targetHeight
        self.bytesPerRow = targetWidth * 4
        self.data = pixels
        self.scaleX = CGFloat(image.width) / CGFloat(targetWidth)
        self.scaleY = CGFloat(image.height) / CGFloat(targetHeight)
    }

    func detectScoreRegion(leftRatioLimit: CGFloat) -> CGRect? {
        let scanWidth = Int(CGFloat(width) * leftRatioLimit)
        var rowHits: [(row: Int, minX: Int, maxX: Int)] = []

        for y in 0..<height {
            var hitCount = 0
            var minX = scanWidth
            var maxX = 0

            for x in 0..<scanWidth {
                if isHeaderBlue(x: x, y: y) {
                    hitCount += 1
                    minX = min(minX, x)
                    maxX = max(maxX, x)
                }
            }

            if hitCount > Int(CGFloat(scanWidth) * 0.22), minX < Int(CGFloat(scanWidth) * 0.16) {
                rowHits.append((row: y, minX: minX, maxX: maxX))
            }
        }

        guard !rowHits.isEmpty else { return nil }

        var segments: [(start: Int, end: Int, minX: Int, maxX: Int)] = []
        for hit in rowHits {
            if var last = segments.last, hit.row <= last.end + 2 {
                last.end = hit.row
                last.minX = min(last.minX, hit.minX)
                last.maxX = max(last.maxX, hit.maxX)
                segments[segments.count - 1] = last
            } else {
                segments.append((start: hit.row, end: hit.row, minX: hit.minX, maxX: hit.maxX))
            }
        }

        let usefulSegments = segments.filter { $0.end - $0.start >= 5 && $0.maxX - $0.minX > Int(CGFloat(scanWidth) * 0.35) }
        guard let maxX = usefulSegments.map(\.maxX).max() else { return nil }

        return CGRect(
            x: 0,
            y: 0,
            width: min(CGFloat(width), CGFloat(maxX + 16)) * scaleX,
            height: CGFloat(height) * scaleY
        )
    }

    func isHeaderBlue(x: Int, y: Int) -> Bool {
        let offset = y * bytesPerRow + x * 4
        let red = Int(data[offset])
        let green = Int(data[offset + 1])
        let blue = Int(data[offset + 2])

        return blue > 110 &&
            green > 80 &&
            blue > red * 2 &&
            green * 10 > red * 12
    }
}

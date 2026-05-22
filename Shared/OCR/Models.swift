import CoreGraphics
import Foundation

public struct Scorecard: Codable, Sendable {
    public var sourceImagePath: String?
    public var clubName: String?
    public var dateText: String?
    public var teeOffText: String?
    public var leadPlayerName: String?
    public var leadPlayerTotal: Int?
    public var tables: [ScoreTable]
    public var warnings: [String]

    public init(
        sourceImagePath: String? = nil,
        clubName: String? = nil,
        dateText: String? = nil,
        teeOffText: String? = nil,
        leadPlayerName: String? = nil,
        leadPlayerTotal: Int? = nil,
        tables: [ScoreTable],
        warnings: [String] = []
    ) {
        self.sourceImagePath = sourceImagePath
        self.clubName = clubName
        self.dateText = dateText
        self.teeOffText = teeOffText
        self.leadPlayerName = leadPlayerName
        self.leadPlayerTotal = leadPlayerTotal
        self.tables = tables
        self.warnings = warnings
    }
}

public struct ScoreTable: Codable, Sendable {
    public var sectionName: String
    public var columns: [ScoreColumn]
    public var rows: [ScoreRow]

    public init(sectionName: String, columns: [ScoreColumn], rows: [ScoreRow]) {
        self.sectionName = sectionName
        self.columns = columns
        self.rows = rows
    }

    public func as2DArray(includeHeader: Bool = true) -> [[String]] {
        var output: [[String]] = []
        if includeHeader {
            output.append(columns.map(\.title))
        }
        output.append(contentsOf: rows.map(\.asArray))
        return output
    }
}

public struct ScoreColumn: Codable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case label
        case hole
        case subtotal
        case total
        case extra
    }

    public var key: String
    public var title: String
    public var kind: Kind

    public init(key: String, title: String, kind: Kind) {
        self.key = key
        self.title = title
        self.kind = kind
    }
}

public struct ScoreRow: Codable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case par
        case player
        case unknown
    }

    public var label: String
    public var kind: Kind
    public var values: [ScoreValue?]

    public init(label: String, kind: Kind, values: [ScoreValue?]) {
        self.label = label
        self.kind = kind
        self.values = values
    }

    public var asArray: [String] {
        [label] + values.map { $0?.raw ?? "" }
    }
}

public struct ScoreValue: Codable, Sendable {
    public var raw: String
    public var intValue: Int?

    public init(raw: String, intValue: Int? = nil) {
        self.raw = raw
        self.intValue = intValue
    }
}

public struct ScorecardExtractorOptions: Sendable {
    public var scoreRegionFallbackLeftRatio: CGFloat
    public var minimumTokenConfidence: Float
    public var minimumHeaderHoleCount: Int
    public var languages: [String]
    public var performCellRecognition: Bool

    public init(
        scoreRegionFallbackLeftRatio: CGFloat = 0.53,
        minimumTokenConfidence: Float = 0.15,
        minimumHeaderHoleCount: Int = 8,
        languages: [String] = ["ko-KR", "en-US"],
        performCellRecognition: Bool = true
    ) {
        self.scoreRegionFallbackLeftRatio = scoreRegionFallbackLeftRatio
        self.minimumTokenConfidence = minimumTokenConfidence
        self.minimumHeaderHoleCount = minimumHeaderHoleCount
        self.languages = languages
        self.performCellRecognition = performCellRecognition
    }
}

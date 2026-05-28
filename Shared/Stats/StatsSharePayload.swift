import Foundation

// MARK: - StatsSharePayload
// 통계 공유 viewer 페이로드. Worker KV에 저장되고 viewer가 렌더한다.
// PII 화이트리스트: 골프장명/닉네임/통계 수치만 포함.
// 좌표/라운드ID/동반자/디바이스ID 절대 X.

/// 통계 공유 카드 종류
public enum StatsSignatureCardKind: String, Codable, Sendable, Equatable {
    /// 개인 최저타 갱신
    case pr
    /// 핸디캡 1.0+ 하락
    case hcp
    /// 최근 흐름
    case trend
}

/// C안 미니 통계 셀 1개 (value + label)
public struct StatsSignatureMiniStat: Codable, Sendable, Equatable {
    /// 예: "82", "+10"
    public let value: String
    /// 예: "이전 PR", "Even 대비"
    public let label: String

    public init(value: String, label: String) {
        self.value = value
        self.label = label
    }
}

/// 시그니처 카드 1장에 필요한 데이터 (cardKind 별로 의미 다름)
public struct StatsSignature: Codable, Sendable, Equatable {
    /// 예: "인생 최저타를 갱신했어요"
    public let headline: String
    /// 예: "82" 또는 "17.1"
    public let bigNumber: String
    /// 예: "타" 또는 "HDCP"
    public let bigUnit: String
    /// 예: "−4" 또는 "▼ 1.2"
    public let deltaText: String?
    /// 예: "레이크사이드 동코스 · Par 72"
    public let metaPrimary: String?
    /// 예: "이전 PR 86타 (2026.04.12)"
    public let metaSecondary: String?
    /// 예: "골프장 PR · 추정 핸디캡 17.1"
    public let footerLabel: String

    // C안 추가 필드 (Optional — 기존 호환)
    /// C안: 골퍼 행 닉네임 (없으면 payload.displayName 폴백)
    public let playerName: String?
    /// C안: 3분할 미니 통계 (3개 권장)
    public let miniStats: [StatsSignatureMiniStat]?
    /// C안: 우상단 태그 (예: "NEW PR", "HDCP DOWN", "IMPROVING")
    public let tagText: String?
    /// C안: 점수 블록 좌측 라벨 (예: "Total Score", "Handicap Index")
    public let scoreBlockLabel: String?

    public init(
        headline: String,
        bigNumber: String,
        bigUnit: String,
        deltaText: String?,
        metaPrimary: String?,
        metaSecondary: String?,
        footerLabel: String,
        playerName: String? = nil,
        miniStats: [StatsSignatureMiniStat]? = nil,
        tagText: String? = nil,
        scoreBlockLabel: String? = nil
    ) {
        self.headline = headline
        self.bigNumber = bigNumber
        self.bigUnit = bigUnit
        self.deltaText = deltaText
        self.metaPrimary = metaPrimary
        self.metaSecondary = metaSecondary
        self.footerLabel = footerLabel
        self.playerName = playerName
        self.miniStats = miniStats
        self.tagText = tagText
        self.scoreBlockLabel = scoreBlockLabel
    }
}

public struct StatsSummary: Codable, Sendable, Equatable {
    /// 집계 대상 완료 라운드 수
    public let totalRounds: Int
    /// 최근 5R 평균 타수
    public let recentAverageScore: Double?
    /// Even 대비 평균
    public let averageVsPar: Double?

    public init(
        totalRounds: Int,
        recentAverageScore: Double?,
        averageVsPar: Double?
    ) {
        self.totalRounds = totalRounds
        self.recentAverageScore = recentAverageScore
        self.averageVsPar = averageVsPar
    }
}

public struct StatsDistribution: Codable, Sendable, Equatable {
    public let eagleOrBetter: Int
    public let birdie: Int
    public let par: Int
    public let bogey: Int
    public let doubleOrWorse: Int
    public let totalHoles: Int
    /// 예: "보기 골퍼 — 더블+ N% ..."
    public let comment: String

    public init(
        eagleOrBetter: Int,
        birdie: Int,
        par: Int,
        bogey: Int,
        doubleOrWorse: Int,
        totalHoles: Int,
        comment: String
    ) {
        self.eagleOrBetter = eagleOrBetter
        self.birdie = birdie
        self.par = par
        self.bogey = bogey
        self.doubleOrWorse = doubleOrWorse
        self.totalHoles = totalHoles
        self.comment = comment
    }
}

public struct StatsParAverage: Codable, Sendable, Equatable {
    /// 3/4/5
    public let par: Int
    public let averageScore: Double
    public let vsPar: Double
    public let holeCount: Int

    public init(par: Int, averageScore: Double, vsPar: Double, holeCount: Int) {
        self.par = par
        self.averageScore = averageScore
        self.vsPar = vsPar
        self.holeCount = holeCount
    }
}

public struct StatsTrend: Codable, Sendable, Equatable {
    /// "improving"/"stable"/"worsening"
    public let direction: String
    /// "↘ 좋아지는 중"
    public let directionLabel: String
    public let previousAverage: Double
    public let currentAverage: Double
    public let delta: Int
    /// 최근 10R 총타수 (sparkline)
    public let scoreTrend: [Int]
    /// "평균 ±4타"
    public let sigmaText: String?

    public init(
        direction: String,
        directionLabel: String,
        previousAverage: Double,
        currentAverage: Double,
        delta: Int,
        scoreTrend: [Int],
        sigmaText: String?
    ) {
        self.direction = direction
        self.directionLabel = directionLabel
        self.previousAverage = previousAverage
        self.currentAverage = currentAverage
        self.delta = delta
        self.scoreTrend = scoreTrend
        self.sigmaText = sigmaText
    }
}

public struct StatsBestRound: Codable, Sendable, Equatable {
    public let courseName: String
    public let dateISO: String
    public let totalScore: Int
    public let isPersonalRecord: Bool

    public init(
        courseName: String,
        dateISO: String,
        totalScore: Int,
        isPersonalRecord: Bool
    ) {
        self.courseName = courseName
        self.dateISO = dateISO
        self.totalScore = totalScore
        self.isPersonalRecord = isPersonalRecord
    }
}

/// 골프장별 정확한 위치 공유 (통계 공유 v1 — 명시적 공유 동의 적용)
/// 사용자가 공유 버튼을 누른다는 것은 본인 라운드 골프장 좌표 노출 동의로 해석 (33-SECURITY §7.7)
public struct StatsRoundLocationShare: Codable, Sendable, Equatable {
    /// 예: "레이크사이드 동코스"
    public let courseName: String
    /// 클럽하우스 위도
    public let lat: Double
    /// 클럽하우스 경도
    public let lng: Double
    /// 같은 골프장 라운드 횟수 (dedupe 후)
    public let roundCount: Int

    public init(courseName: String, lat: Double, lng: Double, roundCount: Int) {
        self.courseName = courseName
        self.lat = lat
        self.lng = lng
        self.roundCount = roundCount
    }
}

/// 시도 centroid 좌표 포함 (클럽하우스 X)
public struct StatsRegionShare: Codable, Sendable, Equatable {
    /// 예: "경기도"
    public let displayName: String
    public let roundCount: Int
    /// 시도 centroid (클럽하우스 X)
    public let centroidLat: Double
    /// 시도 centroid (클럽하우스 X)
    public let centroidLng: Double

    public init(
        displayName: String,
        roundCount: Int,
        centroidLat: Double,
        centroidLng: Double
    ) {
        self.displayName = displayName
        self.roundCount = roundCount
        self.centroidLat = centroidLat
        self.centroidLng = centroidLng
    }
}

public struct StatsRecentEntryShare: Codable, Sendable, Equatable {
    public let courseName: String
    public let dateISO: String
    public let totalScore: Int
    public let vsPar: Int?
    public let holeCount: Int

    public init(
        courseName: String,
        dateISO: String,
        totalScore: Int,
        vsPar: Int?,
        holeCount: Int
    ) {
        self.courseName = courseName
        self.dateISO = dateISO
        self.totalScore = totalScore
        self.vsPar = vsPar
        self.holeCount = holeCount
    }
}

/// 통계 공유 viewer 전체 페이로드
public struct StatsSharePayload: Codable, Sendable, Equatable {
    public let cardKind: StatsSignatureCardKind
    public let signature: StatsSignature
    public let summary: StatsSummary
    public let scoreDistribution: StatsDistribution
    public let parAverages: [StatsParAverage]
    public let trend: StatsTrend?
    public let bestRound: StatsBestRound?
    /// 시도 centroid 좌표 포함 (클럽하우스 X)
    public let regions: [StatsRegionShare]
    public let recentRounds: [StatsRecentEntryShare]
    /// 마스킹 적용된 닉네임
    public let displayName: String
    /// 예: "2026-05-27T12:34:56Z"
    public let createdAtISO: String
    /// 예: "최근 24R"
    public let periodLabel: String
    /// 골프장별 정확한 위치 (Optional — 기존 호환). 사용자 명시 공유 시 포함 (33-SECURITY §7.7)
    public let roundLocations: [StatsRoundLocationShare]?

    public init(
        cardKind: StatsSignatureCardKind,
        signature: StatsSignature,
        summary: StatsSummary,
        scoreDistribution: StatsDistribution,
        parAverages: [StatsParAverage],
        trend: StatsTrend?,
        bestRound: StatsBestRound?,
        regions: [StatsRegionShare],
        recentRounds: [StatsRecentEntryShare],
        displayName: String,
        createdAtISO: String,
        periodLabel: String,
        roundLocations: [StatsRoundLocationShare]? = nil
    ) {
        self.cardKind = cardKind
        self.signature = signature
        self.summary = summary
        self.scoreDistribution = scoreDistribution
        self.parAverages = parAverages
        self.trend = trend
        self.bestRound = bestRound
        self.regions = regions
        self.recentRounds = recentRounds
        self.displayName = displayName
        self.createdAtISO = createdAtISO
        self.periodLabel = periodLabel
        self.roundLocations = roundLocations
    }
}

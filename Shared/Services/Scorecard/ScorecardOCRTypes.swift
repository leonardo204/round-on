// ScorecardOCRTypes.swift
// Scorecard OCR 파이프라인 공용 타입 정의

import CoreGraphics
import Foundation

// MARK: - OCRTextLine

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

// MARK: - OCRPlayer

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

// MARK: - ScorecardOCRResult

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

// MARK: - ScorecardOCRError

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

// MARK: - ScorecardOCRWarning

/// 부분 인식 경고 — par는 잡혔으나 일부 필드가 누락된 경우 사용자에게 알림용.
public enum ScorecardOCRWarning: String, Sendable, CaseIterable {
    case missingCourseName        // 골프장명 인식 못함
    case missingDate              // 날짜 인식 못함
    case missingFrontCourseName   // 전반 코스명
    case missingBackCourseName    // 후반 코스명 (18홀 케이스에서)
    case onlyHalfRound            // 9홀만 인식 (18홀일 수도)
    case noPlayers                // 플레이어 행 0개
    case fewPlayers               // 플레이어 1명 (동반자 인식 못함)
    case scoreSumMismatch         // 일부 플레이어 추출 점수 합 ≠ OCR total

    public var message: String {
        switch self {
        case .missingCourseName:      return "골프장명을 인식하지 못했어요 — 직접 선택해 주세요"
        case .missingDate:            return "날짜를 인식하지 못했어요 — 오늘 날짜로 설정됐어요"
        case .missingFrontCourseName: return "전반 코스명을 인식하지 못했어요"
        case .missingBackCourseName:  return "후반 코스명을 인식하지 못했어요"
        case .onlyHalfRound:          return "9홀만 인식됐어요 — 18홀이라면 후반 정보를 추가해 주세요"
        case .noPlayers:              return "플레이어 점수를 인식하지 못했어요 — 직접 입력해 주세요"
        case .fewPlayers:             return "본인 외 동반자가 인식되지 않았어요 — 필요하면 추가해 주세요"
        case .scoreSumMismatch:       return "일부 점수가 누락된 것 같아요 — 합계가 맞는지 확인해 주세요"
        }
    }
}

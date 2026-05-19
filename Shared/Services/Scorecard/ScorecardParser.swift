// ScorecardParser.swift
// 스코어카드 파서 프로토콜 — 다형성 dispatch 기반

/// Scorecard 파서 공통 프로토콜.
/// 각 구현체는 `detect`로 confidence를 제공하고, `parse`로 실제 결과를 반환한다.
public protocol ScorecardParser {
    /// 이 parser의 이름 (로그/디버그용)
    static var typeName: String { get }

    /// 이 형식일 가능성 (0.0 ~ 1.0). 식별 키워드 / layout 신호 검사.
    static func detect(lines: [OCRTextLine]) -> Double

    /// 실제 파싱. nil 반환 시 dispatch가 다음 parser를 시도한다.
    static func parse(lines: [OCRTextLine]) -> ScorecardOCRResult?
}

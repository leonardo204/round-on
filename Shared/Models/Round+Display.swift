import Foundation

// MARK: - Round+Display
// 화면 표시용 서브라벨 합성 확장 (22-STATE §3 참조)
// frontCourseName / backCourseName → displaySubLabel 문자열 합성

extension Round {
    /// 화면 표시용 서브코스 라벨.
    ///
    /// 합성 규칙:
    /// - front/back 중 nil이 아닌 값들을 " / "로 연결 (예: "동코스 / 남코스", "동코스")
    /// - 둘 다 nil이면 legacy courseSubName으로 폴백 (마이그레이션 안전)
    /// - 모두 nil이면 nil (호출자가 "전반"/"후반" 폴백 라벨 사용)
    public var displaySubLabel: String? {
        let parts = [frontCourseName, backCourseName].compactMap { name -> String? in
            guard let n = name, !n.isEmpty else { return nil }
            return n
        }
        if !parts.isEmpty { return parts.joined(separator: " / ") }
        // legacy courseSubName 폴백 (deprecated 프로퍼티 — 내부 브릿지 경유로 경고 최소화)
        return _legacyFallback()
    }

    /// deprecated courseSubName 접근 전용 내부 브릿지.
    /// 함수 자체를 deprecated 마킹 → 내부에서 deprecated courseSubName 접근 시
    /// "deprecated-in-deprecated" 규칙으로 컴파일러 경고가 억제된다.
    /// 외부 코드에서 직접 호출 금지.
    @available(*, deprecated, message: "Internal legacy bridge — do not call from external code")
    @inline(__always)
    func _legacyFallback() -> String? {
        courseSubName?.isEmpty == false ? courseSubName : nil
    }
}

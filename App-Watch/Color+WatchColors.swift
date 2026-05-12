import SwiftUI

// Watch 전용 컬러 — Asset Catalog 없이 하드코딩 (watchOS 런타임 제약 대응)
// 10-DESIGN_SYSTEM §2 Winter 팔레트 값 그대로 사용
extension Color {
    // Winter (dark default) — watch UI 기본값
    static let winterTextPrimary     = Color(red: 0.910, green: 0.941, blue: 0.918)
    static let winterTextSecondary   = Color(red: 0.604, green: 0.667, blue: 0.624)
    static let winterGreenPrimary    = Color(red: 0.353, green: 0.541, blue: 0.420)
    static let winterGreenAccent     = Color(red: 0.561, green: 0.710, blue: 0.627)
    static let winterSurface          = Color(red: 0.059, green: 0.086, blue: 0.071)
    static let winterSurfaceElevated  = Color(red: 0.102, green: 0.141, blue: 0.118)
    static let winterBorder           = Color(red: 0.165, green: 0.208, blue: 0.188)
    static let winterGreenSecondary  = Color(red: 0.165, green: 0.247, blue: 0.208)
}

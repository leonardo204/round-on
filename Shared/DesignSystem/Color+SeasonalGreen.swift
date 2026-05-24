import SwiftUI

// BundleToken: Xcode Framework 타깃에서 .module 대신 사용 (SwiftPM 전용 아님)
// public: App-iOS 타깃에서 Shared 번들 리소스(이미지/컬러) 접근용
public final class SharedAssetBundleToken {}
private let sharedBundle = Bundle(for: SharedAssetBundleToken.self)

public extension Bundle {
    /// Shared framework 리소스 번들 (SharedAssets.xcassets 등)
    static let sharedAssets = Bundle(for: SharedAssetBundleToken.self)
}

public extension Color {
    // Spring (light default) — 10-DESIGN_SYSTEM §2
    static let springGreenPrimary    = Color("Spring/GreenPrimary",    bundle: sharedBundle)
    static let springGreenSecondary  = Color("Spring/GreenSecondary",  bundle: sharedBundle)
    static let springGreenAccent     = Color("Spring/GreenAccent",     bundle: sharedBundle)
    static let springSurface          = Color("Spring/Surface",         bundle: sharedBundle)
    static let springSurfaceElevated  = Color("Spring/SurfaceElevated", bundle: sharedBundle)
    static let springTextPrimary      = Color("Spring/TextPrimary",     bundle: sharedBundle)
    static let springTextSecondary    = Color("Spring/TextSecondary",   bundle: sharedBundle)
    static let springBorder           = Color("Spring/Border",          bundle: sharedBundle)

    // Winter (dark default) — 10-DESIGN_SYSTEM §2
    static let winterGreenPrimary    = Color("Winter/GreenPrimary",    bundle: sharedBundle)
    static let winterGreenSecondary  = Color("Winter/GreenSecondary",  bundle: sharedBundle)
    static let winterGreenAccent     = Color("Winter/GreenAccent",     bundle: sharedBundle)
    static let winterSurface          = Color("Winter/Surface",         bundle: sharedBundle)
    static let winterSurfaceElevated  = Color("Winter/SurfaceElevated", bundle: sharedBundle)
    static let winterTextPrimary      = Color("Winter/TextPrimary",     bundle: sharedBundle)
    static let winterTextSecondary    = Color("Winter/TextSecondary",   bundle: sharedBundle)
    static let winterBorder           = Color("Winter/Border",          bundle: sharedBundle)

    // MARK: - viewer.ts 디자인 토큰 (2026-05-24 v6)
    // light: 하드코딩 hex, dark: 동일 hue 유지 + 채도 조정

    /// Pale sage page background — light: #f4f7f4, dark: #0f1614
    static let paleSageBg = Color("Viewer/PaleSageBg", bundle: sharedBundle)

    /// Card background — light: #ffffff, dark: #1a221e
    static let cardSurface = Color("Viewer/CardSurface", bundle: sharedBundle)

    /// Card border — light: #e6ece7, dark: rgba(255,255,255,0.08)
    static let cardBorder = Color("Viewer/CardBorder", bundle: sharedBundle)

    /// House green — light: #1c6b43, dark: #2da06a (가독성 위해 더 밝게)
    static let houseGreen = Color("Viewer/HouseGreen", bundle: sharedBundle)

    /// Accent green — light: #21895a, dark: #3db578
    static let accentGreen = Color("Viewer/AccentGreen", bundle: sharedBundle)

    /// Table header row bg — light: #f1f9f4, dark: #141f18
    static let tableHeaderBg = Color("Viewer/TableHeaderBg", bundle: sharedBundle)

    // MARK: Score cell tokens (4단계)

    /// Birdie (≤-1) terracotta — light: #c0573a, dark: #e06b4a
    static let scoreBirdie = Color("Viewer/ScoreBirdie", bundle: sharedBundle)

    /// Par (0) green-700 — light: #1c6b43, dark: #2da06a
    static let scoreParGreen = Color("Viewer/ScoreParGreen", bundle: sharedBundle)

    /// Bogey (+1) mustard — light: #d6a93b, dark: #e8bb55
    static let scoreBogey = Color("Viewer/ScoreBogey", bundle: sharedBundle)

    /// Double (≥+2) blue — light: #1e40af, dark: #4f72d8
    static let scoreDouble = Color("Viewer/ScoreDouble", bundle: sharedBundle)

    // MARK: Hero / delta tokens

    /// Hero leader delta green-400 — light: #4cb784, dark: #6ecfa0
    static let heroLeaderDelta = Color("Viewer/HeroLeaderDelta", bundle: sharedBundle)

    /// Sum delta / non-leader delta terracotta — light: #c0573a, dark: #e06b4a
    static let sumDelta = Color("Viewer/SumDelta", bundle: sharedBundle)

    // MARK: Ink tokens

    /// ink #1a2620 — dark: #e8f0ec
    static let inkPrimary = Color("Viewer/InkPrimary", bundle: sharedBundle)

    /// ink-soft #5d6b63 — dark: #94a39b
    static let inkSoft = Color("Viewer/InkSoft", bundle: sharedBundle)

    /// ink-faint #94a39b — dark: #5d6b63
    static let inkFaint = Color("Viewer/InkFaint", bundle: sharedBundle)
}

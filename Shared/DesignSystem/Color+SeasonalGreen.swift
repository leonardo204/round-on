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
}

---
name: 라운드온 (Round-On)
colors:
  surface: '#fdf7ff'
  surface-dim: '#ded8e0'
  surface-bright: '#fdf7ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f8f2fa'
  surface-container: '#f2ecf4'
  surface-container-high: '#ece6ee'
  surface-container-highest: '#e6e0e9'
  on-surface: '#1d1b20'
  on-surface-variant: '#494551'
  inverse-surface: '#322f35'
  inverse-on-surface: '#f5eff7'
  outline: '#7a7582'
  outline-variant: '#cbc4d2'
  surface-tint: '#6750a4'
  primary: '#4f378a'
  on-primary: '#ffffff'
  primary-container: '#6750a4'
  on-primary-container: '#e0d2ff'
  inverse-primary: '#cfbcff'
  secondary: '#63597c'
  on-secondary: '#ffffff'
  secondary-container: '#e1d4fd'
  on-secondary-container: '#645a7d'
  tertiary: '#765b00'
  on-tertiary: '#ffffff'
  tertiary-container: '#c9a74d'
  on-tertiary-container: '#503d00'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#e9ddff'
  primary-fixed-dim: '#cfbcff'
  on-primary-fixed: '#22005d'
  on-primary-fixed-variant: '#4f378a'
  secondary-fixed: '#e9ddff'
  secondary-fixed-dim: '#cdc0e9'
  on-secondary-fixed: '#1f1635'
  on-secondary-fixed-variant: '#4b4263'
  tertiary-fixed: '#ffdf93'
  tertiary-fixed-dim: '#e7c365'
  on-tertiary-fixed: '#241a00'
  on-tertiary-fixed-variant: '#594400'
  background: '#fdf7ff'
  on-background: '#1d1b20'
  surface-variant: '#e6e0e9'
typography:
  display-hero:
    fontFamily: Hanken Grotesk
    fontSize: 48px
    fontWeight: '700'
    lineHeight: '1.1'
    letterSpacing: -0.04em
  headline-lg:
    fontFamily: Hanken Grotesk
    fontSize: 32px
    fontWeight: '600'
    lineHeight: '1.2'
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Hanken Grotesk
    fontSize: 24px
    fontWeight: '500'
    lineHeight: '1.3'
  body-lg:
    fontFamily: Hanken Grotesk
    fontSize: 18px
    fontWeight: '400'
    lineHeight: '1.6'
  body-md:
    fontFamily: Hanken Grotesk
    fontSize: 16px
    fontWeight: '400'
    lineHeight: '1.5'
  data-lg:
    fontFamily: JetBrains Mono
    fontSize: 20px
    fontWeight: '500'
    lineHeight: '1.0'
  data-sm:
    fontFamily: JetBrains Mono
    fontSize: 12px
    fontWeight: '400'
    lineHeight: '1.0'
    letterSpacing: 0.05em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  unit: 8px
  container-padding: 24px
  section-gap: 48px
  element-gap: 16px
  gutter: 12px
---

## Brand & Style
The design system is anchored in the concept of "The Gallery of the Green." It treats every golf round not just as a set of data, but as a cinematic narrative. The aesthetic is heavily influenced by high-end Korean editorial design—balancing strict discipline with poetic negative space.

The style is a blend of **Minimalism** and **Cinematic Editorial**. It avoids standard mobile patterns in favor of asymmetric layouts, oversized typography, and full-bleed photography that evokes the quiet atmosphere of an early morning tee time. The user experience should feel like flipping through a premium coffee-table magazine: quiet, confident, and meticulously curated.

## Colors
This design system utilizes two distinct palettes: **Spring (Light)** and **Winter (Dark)**. These are not merely day/night modes, but seasonal themes that reflect the changing colors of the golf course.

- **Spring Palette:** Focused on "Sunlight on Grass." It uses a warm, off-white surface to reduce eye strain and feel more organic than pure white.
- **Winter Palette:** Focused on "Deep Forest." It uses low-light greens and desaturated slate tones to provide a premium, low-glare experience for post-round analysis in clubhouses or evening settings.
- **Accents:** Reserved strictly for performance indicators (e.g., Birdie or better) and primary calls to action.

## Typography
The typography is the most expressive element of this design system. It utilizes **SF Pro Display / Pretendard** for general interface elements and **SF Mono** for all numerical scoring data.

- **Asymmetry:** Large headlines should often be left-aligned with significant top-padding to create an editorial "header" feel.
- **Numerical Precision:** Scoring data must always use monospaced fonts to ensure columns align perfectly in scorecards, mimicking the technical look of a yardage book.
- **Hierarchy:** Use extreme scale differences. A hero score might be 48px, while the supporting label is a tiny 10px monospaced uppercase string.

## Layout & Spacing
The layout follows an **8pt grid** but applies it with the breathing room of a luxury brand.

- **Safe Zones:** A generous 24px horizontal margin is standard for all screens to prevent content from feeling crowded.
- **Vertical Rhythm:** Large vertical gaps (48px+) are used between major sections to emphasize the "whitespace as luxury" philosophy.
- **The 1/3 Rule:** For editorial screens, use a 3-column grid where the main headline might span 2 columns, leaving 1 column entirely empty to create visual tension and sophistication.
- **Mobile Fluidity:** On mobile, components should utilize the full width only when using photography; otherwise, inset containers with the defined radii are preferred.

## Elevation & Depth
This design system rejects heavy, muddy shadows. Depth is communicated through **Tonal Layering** and **Subtle Outlines**.

- **Surface Tiers:** Backgrounds use the `surface` color. Floating cards or interactive elements use `surface-elevated`.
- **Soft Definition:** Instead of a shadow, use a 1px border using the `border` token. If a shadow is necessary for a floating action button, use a 15% opacity shadow tinted with the `primary` color, with a large 24px blur and 0px spread.
- **Glassmorphism:** In the Winter Palette, use background blurs (20px) on navigation bars to maintain the cinematic feel of the photography behind the UI.

## Shapes
The shape language is "Soft-Modern." It uses substantial corner radii to contrast the sharp, technical nature of the monospaced data.

- **Standard Containers:** Use a 16px radius for primary cards and sections.
- **Interactive Elements:** Buttons and input fields use a 12px radius.
- **Micro-elements:** Small tags or chips use a 4px radius or are fully pill-shaped depending on the content density.
- **Images:** All photography should have a 16px radius unless it is a full-bleed hero element.

## Components
Consistent styling across the application is driven by a "less is more" approach.

- **Scorecard Cells:** The primary component. A square or slightly vertical rectangle with a subtle border. The score (SF Mono) is centered, and the "to par" indicator is placed in the top-right corner in a smaller weight.
- **Primary Buttons:** High-contrast containers using the `primary` color with `surface` text. No gradients.
- **Ghost Buttons:** Transparent background with a `border` stroke. Used for secondary actions like "View Gallery" or "Previous Rounds."
- **Editorial Cards:** Used for course discovery. These feature a large background image, a dark gradient overlay at the bottom, and white text (Pretendard) for the course name and location.
- **Status Chips:** Small, monospaced text indicators with a subtle background tint of the status color (e.g., #E8F0EA for a "Fairway Hit").
- **Inputs:** Underlined or subtly boxed with 1px lines. Focus states should transition the border color to `primary` without increasing stroke weight.
import SwiftUI

/// The visual language of the app. Semantic colours live in the asset catalogue so light and dark
/// appearances are handled by the system; everything else is defined here.
enum Theme {
    enum Colors {
        static let canvas = Color("Canvas")
        static let canvasRaised = Color("CanvasRaised")
        static let surface = Color("Surface")
        static let surfaceStrong = Color("SurfaceStrong")
        static let ink = Color("Ink")
        static let inkSecondary = Color("InkSecondary")
        static let inkTertiary = Color("InkTertiary")
        static let hairline = Color("Hairline")
        static let accent = Color("AccentColor")
    }

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
        /// Horizontal page margin.
        static let page: CGFloat = 20
    }

    enum Radius {
        static let sm: CGFloat = 12
        static let md: CGFloat = 18
        static let lg: CGFloat = 24
        static let xl: CGFloat = 30
    }

    enum Shadow {
        static let soft = Color.black.opacity(0.06)
    }
}

// MARK: - Typography
//
// Serif for anything editorial (titles, chapter text, the companion's voice); the system sans for
// interface text. All styles are Dynamic Type text styles so they scale.

extension Font {
    static var displaySerif: Font { .system(.largeTitle, design: .serif, weight: .semibold) }
    static var titleSerif: Font { .system(.title, design: .serif, weight: .semibold) }
    static var title2Serif: Font { .system(.title2, design: .serif, weight: .semibold) }
    static var title3Serif: Font { .system(.title3, design: .serif, weight: .semibold) }
    static var headlineSerif: Font { .system(.headline, design: .serif, weight: .semibold) }
    static var bodySerif: Font { .system(.body, design: .serif) }
    static var calloutSerif: Font { .system(.callout, design: .serif) }
    /// Reading text for chapters and long entries: serif body with generous leading.
    static var readingSerif: Font { .system(.title3, design: .serif, weight: .regular) }
    static var eyebrow: Font { .system(.caption, design: .default, weight: .semibold) }
}

extension View {
    /// Small, spaced label above a section title.
    func eyebrowStyle() -> some View {
        self.font(.eyebrow)
            .textCase(.uppercase)
            .tracking(1.1)
            .foregroundStyle(Theme.Colors.inkSecondary)
    }
}

// MARK: - Motion

/// Animations that respect Reduce Motion.
struct Motion {
    let reduceMotion: Bool

    var gentle: Animation? { reduceMotion ? nil : .smooth(duration: 0.35) }
    var quick: Animation? { reduceMotion ? nil : .snappy(duration: 0.25) }
    var spring: Animation? { reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.82) }
    var slow: Animation? { reduceMotion ? nil : .easeInOut(duration: 0.8) }

    func transition(_ transition: AnyTransition) -> AnyTransition {
        reduceMotion ? .opacity : transition
    }
}

extension EnvironmentValues {
    var motion: Motion { Motion(reduceMotion: accessibilityReduceMotion) }
}

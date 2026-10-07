import SwiftUI

/// The page background. A plain warm canvas with the faintest gradient so screens feel like paper, not panels.
struct CanvasBackground: View {
    var body: some View {
        ZStack {
            Theme.Colors.canvas
            LinearGradient(
                colors: [Theme.Colors.accent.opacity(0.05), Color.clear],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.35)
            )
        }
        .ignoresSafeArea()
    }
}

struct SoftCardStyle: ViewModifier {
    var padding: CGFloat = Theme.Spacing.md
    var radius: CGFloat = Theme.Radius.lg
    var raised: Bool = false

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(raised ? Theme.Colors.canvasRaised : Theme.Colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Theme.Colors.hairline.opacity(raised ? 1 : 0.5), lineWidth: 0.5)
            )
            .shadow(color: raised ? Theme.Shadow.soft : .clear, radius: 12, y: 4)
    }
}

extension View {
    func softCard(padding: CGFloat = Theme.Spacing.md, radius: CGFloat = Theme.Radius.lg, raised: Bool = false) -> some View {
        modifier(SoftCardStyle(padding: padding, radius: radius, raised: raised))
    }
}

/// Section heading with an optional eyebrow and trailing action.
struct SectionHeading<Trailing: View>: View {
    var eyebrow: String? = nil
    var title: String
    var subtitle: String? = nil
    @ViewBuilder var trailing: Trailing

    init(eyebrow: String? = nil, title: String, subtitle: String? = nil, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                if let eyebrow {
                    Text(eyebrow).eyebrowStyle()
                }
                Text(title)
                    .font(.title2Serif)
                    .foregroundStyle(Theme.Colors.ink)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Theme.Colors.inkSecondary)
                }
            }
            Spacer(minLength: Theme.Spacing.sm)
            trailing
        }
        .accessibilityElement(children: .combine)
    }
}

/// A small, quiet action link such as "See all".
struct QuietLink: View {
    var title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Text(title)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Theme.Colors.accent)
        }
        .buttonStyle(.plain)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(Theme.Colors.canvasRaised)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .background(
                Capsule().fill(Theme.Colors.accent.opacity(isEnabled ? 1 : 0.4))
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .foregroundStyle(Theme.Colors.ink)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .background(Capsule().fill(Theme.Colors.surfaceStrong))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

/// A capsule chip used for suggestions, concepts and filters.
struct Chip: View {
    var title: String
    var systemImage: String? = nil
    var tint: Color? = nil
    var filled: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage).font(.caption.weight(.semibold))
            }
            Text(title)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .foregroundStyle(filled ? Theme.Colors.canvasRaised : (tint ?? Theme.Colors.ink))
        .background(
            Capsule().fill(filled ? (tint ?? Theme.Colors.accent) : (tint?.opacity(0.14) ?? Theme.Colors.surfaceStrong))
        )
    }
}

/// Empty states that read like an invitation rather than an error.
struct GentleEmptyState: View {
    var title: String
    var message: String
    var systemImage: String = "sparkle"
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(Theme.Colors.accent)
                .padding(.bottom, 4)
            Text(title)
                .font(.title3Serif)
                .foregroundStyle(Theme.Colors.ink)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.inkSecondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.primary)
                    .padding(.top, Theme.Spacing.xs)
                    .frame(maxWidth: 260)
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity)
    }
}

/// Small coloured mark showing how a moment felt.
struct FeelingMark: View {
    var feeling: Feeling
    var size: CGFloat = 10

    var body: some View {
        Circle()
            .fill(feeling.color)
            .frame(width: size, height: size)
            .accessibilityLabel(feeling.accessibilityDescription)
    }
}

/// The companion's mark: two overlapping soft circles, "I" and "ME".
struct CompanionMark: View {
    var size: CGFloat = 28

    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.Colors.accent.opacity(0.85))
                .frame(width: size * 0.62, height: size * 0.62)
                .offset(x: -size * 0.14)
            Circle()
                .fill(Theme.Colors.accent.opacity(0.45))
                .frame(width: size * 0.62, height: size * 0.62)
                .offset(x: size * 0.14)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Initial-based avatar for people and the profile.
struct InitialAvatar: View {
    var name: String
    var size: CGFloat = 44
    var tint: Color = Theme.Colors.accent

    private var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        return parts.compactMap { $0.first.map(String.init) }.joined().uppercased()
    }

    var body: some View {
        ZStack {
            Circle().fill(tint.opacity(0.16))
            Text(initials.isEmpty ? "·" : initials)
                .font(.system(size: size * 0.38, weight: .semibold, design: .serif))
                .foregroundStyle(tint)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Divider that matches the warm palette.
struct Hairline: View {
    var body: some View {
        Rectangle()
            .fill(Theme.Colors.hairline)
            .frame(height: 0.5)
    }
}

/// Standard pull-up sheet chrome for forms.
extension View {
    func pageHorizontalPadding() -> some View {
        padding(.horizontal, Theme.Spacing.page)
    }
}

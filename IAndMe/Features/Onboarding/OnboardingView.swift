import SwiftUI
import SwiftData

/// Three light steps: the idea, a name, and how to begin. Nothing else is asked.
struct OnboardingView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.motion) private var motion

    private enum Step: Int { case welcome, name, begin }

    @State private var step: Step = .welcome
    @State private var name = ""
    @State private var choice: Choice = .sample
    @State private var isWorking = false
    @FocusState private var nameFocused: Bool

    enum Choice { case fresh, sample }

    var body: some View {
        ZStack {
            CanvasBackground()
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                Group {
                    switch step {
                    case .welcome: welcome
                    case .name: nameStep
                    case .begin: beginStep
                    }
                }
                .transition(motion.transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity))))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .animation(motion.gentle, value: step)
        }
    }

    // MARK: Steps

    private var welcome: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            BrandMark(size: 72)
                .padding(.bottom, Theme.Spacing.sm)
            Text("Your life is made of moments.")
                .font(.displaySerif)
                .foregroundStyle(Theme.Colors.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(Brand.name) helps you capture them, remember them, and understand the story they create.")
                .font(.title3)
                .foregroundStyle(Theme.Colors.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Everything stays on this phone.")
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.inkTertiary)
                .padding(.top, Theme.Spacing.xs)
            Button("Begin") {
                step = .name
                nameFocused = true
            }
            .buttonStyle(.primary)
            .padding(.top, Theme.Spacing.lg)
            .accessibilityIdentifier("onboarding.begin")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            Text("What should I call you?")
                .font(.displaySerif)
                .foregroundStyle(Theme.Colors.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("Just a first name is fine. It's only used to greet you.")
                .font(.title3)
                .foregroundStyle(Theme.Colors.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            TextField("Your name", text: $name)
                .font(.title2Serif)
                .textContentType(.givenName)
                .autocorrectionDisabled()
                .submitLabel(.continue)
                .focused($nameFocused)
                .padding(.vertical, 14)
                .padding(.horizontal, 18)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).fill(Theme.Colors.canvasRaised))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).strokeBorder(Theme.Colors.hairline))
                .onSubmit { advanceFromName() }
                .accessibilityIdentifier("onboarding.name")
            Button("Continue") { advanceFromName() }
                .buttonStyle(.primary)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.top, Theme.Spacing.sm)
                .accessibilityIdentifier("onboarding.continue")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { nameFocused = true }
    }

    private var beginStep: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            Text("How would you like to begin, \(name.trimmingCharacters(in: .whitespaces))?")
                .font(.displaySerif)
                .foregroundStyle(Theme.Colors.ink)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: Theme.Spacing.sm) {
                ChoiceCard(
                    title: "Explore a sample life",
                    detail: "See what \(Brand.name) becomes after a few months of moments. Remove it whenever you like.",
                    systemImage: "sparkles",
                    isSelected: choice == .sample
                ) { choice = .sample }
                .accessibilityIdentifier("onboarding.sample")
                ChoiceCard(
                    title: "Start with my own first moment",
                    detail: "An empty page, and a gentle way in.",
                    systemImage: "pencil.line",
                    isSelected: choice == .fresh
                ) { choice = .fresh }
                .accessibilityIdentifier("onboarding.fresh")
            }
            Button {
                finish()
            } label: {
                if isWorking {
                    ProgressView().tint(Theme.Colors.canvasRaised)
                } else {
                    Text("Let's begin")
                }
            }
            .buttonStyle(.primary)
            .disabled(isWorking)
            .padding(.top, Theme.Spacing.sm)
            .accessibilityIdentifier("onboarding.finish")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func advanceFromName() {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        nameFocused = false
        step = .begin
    }

    private func finish() {
        guard !isWorking else { return }
        isWorking = true
        let profile = services.repository.profile()
        profile.name = name.trimmingCharacters(in: .whitespaces)
        if choice == .sample {
            try? services.sample.installSampleLife(renderMedia: !services.isUITesting || true)
            services.refreshInsights()
        }
        profile.hasCompletedOnboarding = true
        try? services.repository.save()
        isWorking = false
    }
}

private struct ChoiceCard: View {
    var title: String
    var detail: String
    var systemImage: String
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(isSelected ? Theme.Colors.accent : Theme.Colors.inkSecondary)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Theme.Colors.ink)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(Theme.Colors.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Theme.Colors.accent : Theme.Colors.inkTertiary)
            }
            .padding(Theme.Spacing.md)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous).fill(Theme.Colors.canvasRaised))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous).strokeBorder(isSelected ? Theme.Colors.accent.opacity(0.6) : Theme.Colors.hairline, lineWidth: isSelected ? 1.5 : 0.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// The product mark: a serif ampersand on a warm disc. Lives in one place so the brand can change.
struct BrandMark: View {
    var size: CGFloat = 56

    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Theme.Colors.accent, Theme.Colors.accent.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing))
            Text("&")
                .font(.system(size: size * 0.56, weight: .regular, design: .serif))
                .foregroundStyle(Theme.Colors.canvasRaised)
                .offset(y: -size * 0.02)
        }
        .frame(width: size, height: size)
        .accessibilityLabel(Brand.name)
    }
}

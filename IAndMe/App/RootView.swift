import SwiftUI
import SwiftData

/// Decides between onboarding and the main experience.
struct RootView: View {
    @Environment(AppServices.self) private var services
    @Query private var profiles: [UserProfile]
    @Environment(\.motion) private var motion

    private var hasOnboarded: Bool { profiles.first?.hasCompletedOnboarding ?? false }

    var body: some View {
        ZStack {
            if hasOnboarded {
                MainTabView()
                    .transition(motion.transition(.opacity.combined(with: .scale(scale: 1.02))))
            } else {
                OnboardingView()
                    .transition(motion.transition(.opacity))
            }
        }
        .animation(motion.slow, value: hasOnboarded)
    }
}

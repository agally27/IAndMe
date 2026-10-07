import SwiftUI

struct MainTabView: View {
    @Environment(AppServices.self) private var services
    @State private var router = AppRouter()

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            Tab("Today", systemImage: "sun.horizon", value: AppTab.today) {
                TodayView()
            }
            Tab("Journal", systemImage: "book.closed", value: AppTab.journal) {
                JournalView()
            }
            Tab("Companion", systemImage: "bubble.left.and.bubble.right", value: AppTab.companion) {
                CompanionHomeView()
            }
            Tab("Memories", systemImage: "sparkles", value: AppTab.memories) {
                MemoriesView()
            }
            Tab("Story", systemImage: "book.pages", value: AppTab.story) {
                StoryView()
            }
        }
        .tabViewBottomAccessory {
            CaptureAccessory()
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .environment(router)
        .sheet(item: $router.captureRequest) { request in
            CaptureView(request: request)
                .environment(router)
        }
    }
}

/// The always-available way to capture a moment. Lives above the tab bar on every screen.
struct CaptureAccessory: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        HStack(spacing: 0) {
            Button {
                router.capture(.write)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "pencil.line")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.Colors.accent)
                    Text("Capture a moment")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Theme.Colors.ink)
                    Spacer(minLength: 0)
                }
                .padding(.leading, 18)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("capture.accessory")
            .accessibilityLabel("Capture a moment")

            Button {
                router.capture(.voice)
            } label: {
                Image(systemName: "mic")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.Colors.ink)
            .accessibilityIdentifier("capture.accessory.voice")
            .accessibilityLabel("Record a voice moment")

            Button {
                router.capture(.photo)
            } label: {
                Image(systemName: "photo")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.Colors.ink)
            .padding(.trailing, 6)
            .accessibilityIdentifier("capture.accessory.photo")
            .accessibilityLabel("Add a photo moment")
        }
    }
}

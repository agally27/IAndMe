import SwiftUI
import SwiftData

@main
struct IAndMeApp: App {
    @State private var services: AppServices

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let isUITesting = arguments.contains("-ui-testing")
        if arguments.contains("-reset-data") {
            LocalStorage.removeStoreFiles()
            try? FileManager.default.removeItem(at: LocalStorage.mediaDirectory)
        }
        let container: ModelContainer
        do {
            container = try ModelContainerFactory.makeContainer(inMemory: isUITesting && arguments.contains("-in-memory"))
        } catch {
            // If the store is unreadable (for example after a schema change in development), start fresh rather than crash.
            LocalStorage.removeStoreFiles()
            container = (try? ModelContainerFactory.makeContainer()) ?? ModelContainerFactory.makeInMemory()
        }
        let services = AppServices(container: container, isUITesting: isUITesting)
        // Development conveniences: `-seed-sample` skips onboarding with the sample life installed.
        if arguments.contains("-seed-sample") {
            let profile = services.repository.profile()
            if !profile.hasCompletedOnboarding {
                profile.name = "Sam"
                try? services.sample.installSampleLife()
                services.refreshInsights()
                profile.hasCompletedOnboarding = true
                try? services.repository.save()
            }
        }
        _services = State(initialValue: services)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(services)
                .modelContainer(services.container)
                .tint(Theme.Colors.accent)
        }
    }
}

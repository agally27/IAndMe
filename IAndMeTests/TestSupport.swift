import Foundation
import SwiftData
import UIKit
@testable import IAndMe

/// Builds an isolated, in-memory app stack with a throwaway media directory.
@MainActor
enum TestStack {
    static func make(seedSample: Bool = false, name: String = "Sam") throws -> AppServices {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("iandme-tests-\(UUID().uuidString)", isDirectory: true)
        let services = AppServices(container: ModelContainerFactory.makeInMemory(), replyDelay: .zero, mediaRoot: root)
        let profile = services.repository.profile()
        profile.name = name
        profile.hasCompletedOnboarding = true
        try services.repository.save()
        if seedSample {
            try services.sample.installSampleLife(renderMedia: false)
            services.refreshInsights()
        }
        return services
    }

    static func solidImage(width: Int = 400, height: Int = 300) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        return renderer.image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }
}

import Foundation
import SwiftData

/// The single person who owns this journal. There is exactly one profile per installation.
@Model
final class UserProfile {
    @Attribute(.unique) var id: UUID
    var name: String
    var avatarFileName: String?
    var createdAt: Date
    var hasCompletedOnboarding: Bool
    /// True while the fictional sample life is loaded alongside (or instead of) the person's own moments.
    var usesSampleLife: Bool
    var lastOpenedAt: Date

    init(
        id: UUID = UUID(),
        name: String = "",
        avatarFileName: String? = nil,
        createdAt: Date = .now,
        hasCompletedOnboarding: Bool = false,
        usesSampleLife: Bool = false,
        lastOpenedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.avatarFileName = avatarFileName
        self.createdAt = createdAt
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.usesSampleLife = usesSampleLife
        self.lastOpenedAt = lastOpenedAt
    }

    /// First name only, for greetings.
    var firstName: String {
        name.split(separator: " ").first.map(String.init) ?? name
    }
}

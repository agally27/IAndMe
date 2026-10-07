import Foundation

/// Central place for product naming so the brand can change without touching features.
/// Nothing in the app should hard-code the product name; use `Brand` instead.
enum Brand {
    /// Display name used throughout the interface.
    static let name = "I&ME"
    /// The two halves of the name, used sparingly in onboarding and the Story area.
    static let selfWord = "I"
    static let reflectiveWord = "ME"
    /// Name of the reflective companion. Deliberately not a persona name: the companion is a role, not a character.
    static let companionName = "Companion"
    /// Short line used in onboarding and About.
    static let tagline = "Capture your life as it happens. Understand yourself over time. Keep the story of you."
    /// Subdirectory name for local storage. Kept brand-neutral so renaming the product never moves user data.
    static let storageDirectoryName = "LifeJournal"
}

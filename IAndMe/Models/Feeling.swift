import SwiftUI

/// How a moment felt. Deliberately five plain words rather than a numeric scale or emoji.
/// The order matters: lower values are more difficult, higher values more uplifting.
enum Feeling: Int, CaseIterable, Codable, Identifiable, Sendable {
    case heavy = 1
    case low = 2
    case steady = 3
    case good = 4
    case bright = 5

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .heavy: return "Heavy"
        case .low: return "Low"
        case .steady: return "Steady"
        case .good: return "Good"
        case .bright: return "Bright"
        }
    }

    /// A short phrase the companion can use when describing the feeling in prose.
    var phrase: String {
        switch self {
        case .heavy: return "felt heavy"
        case .low: return "felt low"
        case .steady: return "felt steady"
        case .good: return "felt good"
        case .bright: return "felt bright"
        }
    }

    var color: Color {
        switch self {
        case .heavy: return Color("FeelingHeavy")
        case .low: return Color("FeelingLow")
        case .steady: return Color("FeelingSteady")
        case .good: return Color("FeelingGood")
        case .bright: return Color("FeelingBright")
        }
    }

    var isDifficult: Bool { rawValue <= Feeling.low.rawValue }
    var isUplifting: Bool { rawValue >= Feeling.good.rawValue }

    var accessibilityDescription: String { "Feeling: \(label)" }
}

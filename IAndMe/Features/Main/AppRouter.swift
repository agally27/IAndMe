import SwiftUI
import Observation

enum AppTab: Hashable {
    case today, journal, companion, memories, story
}

/// What the capture sheet should open with.
struct CaptureRequest: Identifiable {
    enum Mode { case write, voice, photo }

    var id = UUID()
    var mode: Mode = .write
    var prefilledText: String = ""
    /// A reflective question shown quietly above the editor.
    var prompt: String? = nil
    var editing: JournalEntry? = nil
}

/// Cross-feature navigation state: selected tab and the capture sheet.
@MainActor
@Observable
final class AppRouter {
    var selectedTab: AppTab = AppRouter.initialTab
    var captureRequest: CaptureRequest? = AppRouter.initialCapture
    /// Set after onboarding when the person chose to start fresh, so Today can welcome them.
    var isFirstRun = false

    /// `-open-tab journal` (and friends) selects a tab at launch, for development and screenshots.
    private static var initialTab: AppTab {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-open-tab"), index + 1 < arguments.count else { return .today }
        switch arguments[index + 1] {
        case "journal": return .journal
        case "companion": return .companion
        case "memories": return .memories
        case "story": return .story
        default: return .today
        }
    }

    /// `-capture voice|write|photo` opens the capture sheet at launch, for development.
    private static var initialCapture: CaptureRequest? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-capture"), index + 1 < arguments.count else { return nil }
        switch arguments[index + 1] {
        case "voice": return CaptureRequest(mode: .voice)
        case "photo": return CaptureRequest(mode: .photo)
        default: return CaptureRequest(mode: .write)
        }
    }

    func capture(_ mode: CaptureRequest.Mode = .write, text: String = "", prompt: String? = nil) {
        captureRequest = CaptureRequest(mode: mode, prefilledText: text, prompt: prompt)
    }

    func edit(_ entry: JournalEntry) {
        captureRequest = CaptureRequest(mode: .write, prefilledText: entry.text, editing: entry)
    }
}

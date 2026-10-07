import Foundation

/// Produces a copy of the journal the person owns outright: readable Markdown, or structured JSON
/// for taking the data somewhere else. Media files are referenced by name, not embedded.
@MainActor
final class ExportService {
    enum Format: String, CaseIterable, Identifiable {
        case markdown
        case json

        var id: String { rawValue }
        var label: String {
            switch self {
            case .markdown: return "Readable text"
            case .json: return "Structured data (JSON)"
            }
        }
        var fileExtension: String {
            switch self {
            case .markdown: return "md"
            case .json: return "json"
            }
        }
    }

    private let repository: JournalRepository

    init(repository: JournalRepository) {
        self.repository = repository
    }

    func export(format: Format) throws -> URL {
        let entries = repository.allEntries().sorted { $0.occurredAt < $1.occurredAt }
        let profile = repository.profile()
        let data: Data
        switch format {
        case .markdown:
            data = Data(markdown(entries: entries, profile: profile).utf8)
        case .json:
            data = try json(entries: entries, profile: profile)
        }
        let stamp = Date.now.formatted(.iso8601.year().month().day())
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(Brand.name.filter(\.isLetter))-journal-\(stamp)")
            .appendingPathExtension(format.fileExtension)
        try data.write(to: url, options: .atomic)
        return url
    }

    func markdown(entries: [JournalEntry], profile: UserProfile) -> String {
        var lines: [String] = []
        lines.append("# \(profile.name.isEmpty ? "My" : profile.name + "'s") journal")
        lines.append("")
        lines.append("Exported from \(Brand.name) on \(Date.now.formatted(date: .long, time: .shortened)). \(entries.count) moments.")
        lines.append("")
        var currentMonth = ""
        for entry in entries {
            let month = entry.occurredAt.formatted(.dateTime.month(.wide).year())
            if month != currentMonth {
                currentMonth = month
                lines.append("")
                lines.append("## \(month)")
                lines.append("")
            }
            var heading = "### \(entry.occurredAt.formatted(date: .complete, time: .shortened))"
            if let place = entry.placeName { heading += " — \(place)" }
            lines.append(heading)
            lines.append("")
            var meta: [String] = []
            if let feeling = entry.feeling { meta.append("Felt \(feeling.label.lowercased())") }
            if entry.isKept { meta.append("Worth remembering") }
            if !entry.concepts.isEmpty { meta.append("About: " + entry.concepts.map(\.name).joined(separator: ", ")) }
            if !meta.isEmpty {
                lines.append("_" + meta.joined(separator: " · ") + "_")
                lines.append("")
            }
            if !entry.trimmedText.isEmpty {
                lines.append(entry.trimmedText)
                lines.append("")
            }
            for attachment in entry.sortedAttachments {
                lines.append("![Photo](Media/Photos/\(attachment.fileName))")
            }
            for recording in entry.sortedRecordings {
                lines.append("🎙 Voice moment, \(recording.formattedDuration) (Media/Audio/\(recording.fileName))")
                if let transcript = recording.transcript {
                    lines.append("")
                    lines.append("> \(transcript)")
                }
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    func json(entries: [JournalEntry], profile: UserProfile) throws -> Data {
        let export = JournalExport(
            exportedAt: .now,
            app: Brand.name,
            profile: .init(name: profile.name, createdAt: profile.createdAt),
            entries: entries.map { entry in
                .init(
                    id: entry.id,
                    createdAt: entry.createdAt,
                    occurredAt: entry.occurredAt,
                    text: entry.text,
                    feeling: entry.feeling?.label,
                    isKept: entry.isKept,
                    placeName: entry.placeName,
                    concepts: entry.concepts.map(\.name),
                    photos: entry.sortedAttachments.map { .init(fileName: $0.fileName, width: $0.pixelWidth, height: $0.pixelHeight) },
                    recordings: entry.sortedRecordings.map { .init(fileName: $0.fileName, duration: $0.duration, transcript: $0.transcript) }
                )
            },
            concepts: repository.allConcepts(includeForgotten: false).map { .init(name: $0.name, kind: $0.kind.rawValue, note: $0.note, mentionCount: max($0.mentionCount, $0.entries.count)) }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(export)
    }
}

struct JournalExport: Codable {
    struct Profile: Codable { var name: String; var createdAt: Date }
    struct Photo: Codable { var fileName: String; var width: Int; var height: Int }
    struct Recording: Codable { var fileName: String; var duration: TimeInterval; var transcript: String? }
    struct Entry: Codable {
        var id: UUID
        var createdAt: Date
        var occurredAt: Date
        var text: String
        var feeling: String?
        var isKept: Bool
        var placeName: String?
        var concepts: [String]
        var photos: [Photo]
        var recordings: [Recording]
    }
    struct Concept: Codable { var name: String; var kind: String; var note: String?; var mentionCount: Int }

    var exportedAt: Date
    var app: String
    var profile: Profile
    var entries: [Entry]
    var concepts: [Concept]
}

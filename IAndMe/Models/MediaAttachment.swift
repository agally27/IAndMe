import Foundation
import SwiftData

/// A photograph that belongs to a moment. The image itself lives in the app's local media directory.
@Model
final class MediaAttachment {
    @Attribute(.unique) var id: UUID
    var fileName: String
    var createdAt: Date
    var pixelWidth: Int
    var pixelHeight: Int
    var caption: String?
    var sortOrder: Int
    var entry: JournalEntry?

    init(
        id: UUID = UUID(),
        fileName: String,
        createdAt: Date = .now,
        pixelWidth: Int,
        pixelHeight: Int,
        caption: String? = nil,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.fileName = fileName
        self.createdAt = createdAt
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.caption = caption
        self.sortOrder = sortOrder
    }

    var aspectRatio: CGFloat {
        guard pixelHeight > 0 else { return 4.0 / 3.0 }
        return CGFloat(pixelWidth) / CGFloat(pixelHeight)
    }

    var isPortrait: Bool { pixelHeight > pixelWidth }
}

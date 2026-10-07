import Foundation
import SwiftData

/// Builds the SwiftData container. All persistence lives in one brand-neutral directory inside
/// Application Support, next to the media files, so the whole journal can be exported or deleted as a unit.
enum ModelContainerFactory {
    static let schema = Schema([
        UserProfile.self,
        JournalEntry.self,
        MediaAttachment.self,
        VoiceRecording.self,
        MemoryConcept.self,
        MemoryCollection.self,
        Insight.self,
        LifeChapter.self,
        Conversation.self,
        ConversationMessage.self
    ])

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        if inMemory {
            let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
            return try ModelContainer(for: schema, configurations: configuration)
        }
        let storeURL = LocalStorage.rootDirectory.appendingPathComponent("Journal.store")
        let configuration = ModelConfiguration(url: storeURL)
        return try ModelContainer(for: schema, configurations: configuration)
    }

    /// Used by previews and tests.
    static func makeInMemory() -> ModelContainer {
        do {
            return try makeContainer(inMemory: true)
        } catch {
            fatalError("Unable to create in-memory model container: \(error)")
        }
    }
}

/// Where the journal lives on disk.
enum LocalStorage {
    static var rootDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let root = base.appendingPathComponent(Brand.storageDirectoryName, isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    static var mediaDirectory: URL {
        let url = rootDirectory.appendingPathComponent("Media", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Removes the persistent store files. Only used for a full reset.
    static func removeStoreFiles() {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(at: rootDirectory, includingPropertiesForKeys: nil) else { return }
        for item in items where item.lastPathComponent.hasPrefix("Journal.store") {
            try? fm.removeItem(at: item)
        }
    }
}

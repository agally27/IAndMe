import Foundation
import UIKit

struct StoredPhoto: Sendable {
    var fileName: String
    var pixelWidth: Int
    var pixelHeight: Int
}

/// Owns the files behind photos and voice recordings. Everything stays inside the app's local
/// storage directory. A future implementation could add encryption or cloud-backed blobs behind
/// the same interface.
protocol MediaService: AnyObject {
    var photosDirectory: URL { get }
    var audioDirectory: URL { get }

    func storePhoto(_ image: UIImage) throws -> StoredPhoto
    func photoURL(named fileName: String) -> URL
    func loadPhoto(named fileName: String) -> UIImage?
    func deletePhoto(named fileName: String)

    /// A fresh, unique location for a new recording.
    func newAudioFile(extension ext: String) -> (fileName: String, url: URL)
    func audioURL(named fileName: String) -> URL
    func audioExists(named fileName: String) -> Bool
    func deleteAudio(named fileName: String)

    func totalBytes() -> Int64
    func deleteAll()
}

final class LocalMediaService: MediaService {
    let photosDirectory: URL
    let audioDirectory: URL
    private let fileManager = FileManager.default

    /// Photos are downscaled so a journal of thousands of moments stays light. 2048px is plenty for a phone.
    private let maxPixelDimension: CGFloat = 2048

    init(root: URL = LocalStorage.mediaDirectory) {
        photosDirectory = root.appendingPathComponent("Photos", isDirectory: true)
        audioDirectory = root.appendingPathComponent("Audio", isDirectory: true)
        try? fileManager.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: audioDirectory, withIntermediateDirectories: true)
    }

    func storePhoto(_ image: UIImage) throws -> StoredPhoto {
        let scaled = image.downscaled(maxDimension: maxPixelDimension)
        guard let data = scaled.jpegData(compressionQuality: 0.86) else {
            throw MediaError.encodingFailed
        }
        let fileName = UUID().uuidString + ".jpg"
        try data.write(to: photoURL(named: fileName), options: [.atomic])
        let width = Int(scaled.size.width * scaled.scale)
        let height = Int(scaled.size.height * scaled.scale)
        return StoredPhoto(fileName: fileName, pixelWidth: width, pixelHeight: height)
    }

    func photoURL(named fileName: String) -> URL {
        photosDirectory.appendingPathComponent(fileName)
    }

    func loadPhoto(named fileName: String) -> UIImage? {
        UIImage(contentsOfFile: photoURL(named: fileName).path)
    }

    func deletePhoto(named fileName: String) {
        try? fileManager.removeItem(at: photoURL(named: fileName))
        ImageCache.shared.remove(fileName)
    }

    func newAudioFile(extension ext: String = "m4a") -> (fileName: String, url: URL) {
        let fileName = UUID().uuidString + "." + ext
        return (fileName, audioURL(named: fileName))
    }

    func audioURL(named fileName: String) -> URL {
        audioDirectory.appendingPathComponent(fileName)
    }

    func audioExists(named fileName: String) -> Bool {
        fileManager.fileExists(atPath: audioURL(named: fileName).path)
    }

    func deleteAudio(named fileName: String) {
        try? fileManager.removeItem(at: audioURL(named: fileName))
    }

    func totalBytes() -> Int64 {
        [photosDirectory, audioDirectory].reduce(0) { total, dir in
            guard let items = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey]) else { return total }
            return total + items.reduce(0) { sum, url in
                sum + Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            }
        }
    }

    func deleteAll() {
        for dir in [photosDirectory, audioDirectory] {
            try? fileManager.removeItem(at: dir)
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        ImageCache.shared.removeAll()
    }
}

enum MediaError: LocalizedError {
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .encodingFailed: return "The photo couldn't be saved."
        }
    }
}

extension UIImage {
    func downscaled(maxDimension: CGFloat) -> UIImage {
        let largest = max(size.width, size.height) * scale
        guard largest > maxDimension else { return self }
        let ratio = maxDimension / largest
        let newSize = CGSize(width: size.width * scale * ratio, height: size.height * scale * ratio)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

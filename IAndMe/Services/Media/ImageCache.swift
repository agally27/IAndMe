import Foundation
import UIKit
import SwiftUI

/// In-memory cache for decoded photos so scrolling the journal stays smooth.
final class ImageCache: @unchecked Sendable {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 300
        cache.totalCostLimit = 200 * 1024 * 1024
    }

    func image(for key: String) -> UIImage? { cache.object(forKey: key as NSString) }

    func store(_ image: UIImage, for key: String) {
        let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }

    func remove(_ key: String) { cache.removeObject(forKey: key as NSString) }
    func removeAll() { cache.removeAllObjects() }
}

/// Loads a photo from local storage off the main thread, with a downsampled variant for thumbnails.
actor ImageLoader {
    static let shared = ImageLoader()

    func load(url: URL, cacheKey: String, targetPixelSize: CGFloat?) -> UIImage? {
        let key = targetPixelSize.map { "\(cacheKey)@\(Int($0))" } ?? cacheKey
        if let cached = ImageCache.shared.image(for: key) { return cached }
        let image: UIImage?
        if let targetPixelSize {
            image = ImageLoader.downsample(url: url, maxPixelSize: targetPixelSize)
        } else {
            image = UIImage(contentsOfFile: url.path)
        }
        if let image { ImageCache.shared.store(image, for: key) }
        return image
    }

    nonisolated static func downsample(url: URL, maxPixelSize: CGFloat) -> UIImage? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, options) else { return nil }
        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

/// A view that shows a locally stored photo, loading it asynchronously and fading it in.
struct LocalPhoto: View {
    let fileName: String
    var targetPixelSize: CGFloat? = 800
    var contentMode: ContentMode = .fill

    @Environment(AppServices.self) private var services
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Color("SurfaceStrong")
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .transition(reduceMotion ? .identity : .opacity.animation(.easeOut(duration: 0.25)))
            }
        }
        .clipped()
        .task(id: fileName) {
            if image == nil || image != nil {
                let url = services.media.photoURL(named: fileName)
                let loaded = await ImageLoader.shared.load(url: url, cacheKey: fileName, targetPixelSize: targetPixelSize)
                if !Task.isCancelled { image = loaded }
            }
        }
    }
}

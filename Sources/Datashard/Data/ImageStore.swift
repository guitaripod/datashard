import UIKit

/// Decodes pictures out of the dataset on demand and keeps the decoded
/// bitmaps around, keyed by picture and target size, so list rows and the
/// reader never touch the database twice for the same art.
final class ImageStore: @unchecked Sendable {
    private let store: JournalStore
    private let cache = NSCache<NSString, UIImage>()

    init(store: JournalStore) {
        self.store = store
        cache.totalCostLimit = 96 << 20
    }

    /// The picture decoded for display, downsampled to `fitting` points on
    /// its longer side when given (thumbnails), else at native size.
    func image(for picture: Picture, fitting points: CGFloat? = nil) async -> UIImage? {
        let key = "\(picture.key)@\(points.map { Int($0) } ?? 0)" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        do {
            guard let data = try await store.imageData(for: picture), let raw = UIImage(data: data) else {
                AppLogger.notice("No picture bytes for \(picture.key)", .dataset)
                return nil
            }
            let prepared: UIImage?
            if let points {
                prepared = await raw.byPreparingThumbnail(ofSize: Self.thumbnailSize(for: picture, fitting: points))
            } else {
                prepared = await raw.byPreparingForDisplay()
            }
            guard let image = prepared else { return nil }
            cache.setObject(image, forKey: key, cost: Int(image.size.width * image.size.height * image.scale * image.scale * 4))
            return image
        } catch {
            AppLogger.error("Loading picture \(picture.key) failed: \(error)", .dataset)
            return nil
        }
    }

    private static func thumbnailSize(for picture: Picture, fitting points: CGFloat) -> CGSize {
        let scale = UITraitCollection.current.displayScale > 0 ? UITraitCollection.current.displayScale : 3
        let longest = points * scale
        return picture.isPortrait
            ? CGSize(width: longest * picture.aspect, height: longest)
            : CGSize(width: longest, height: longest / picture.aspect)
    }
}

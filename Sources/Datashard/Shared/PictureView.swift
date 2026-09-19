import UIKit

/// An image view that fills itself from the dataset: give it a picture and
/// it fetches, decodes and fades the bitmap in, dropping the request if it
/// is reused for another picture first (list cells scroll faster than the
/// decoder). A dim panel shows until the bytes arrive.
final class PictureView: UIView {
    private let imageView = UIImageView()
    private var task: Task<Void, Never>?
    private var shownKey: String?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Theme.panel2
        clipsToBounds = true
        imageView.contentMode = .scaleAspectFill
        imageView.frame = bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(imageView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    var imageContentMode: UIView.ContentMode {
        get { imageView.contentMode }
        set { imageView.contentMode = newValue }
    }

    /// Loads `picture`, downsampled to `fitting` points on its longer side
    /// when given. `nil` clears the view.
    func show(_ picture: Picture?, from images: ImageStore, fitting: CGFloat? = nil) {
        task?.cancel()
        guard let picture else {
            shownKey = nil
            imageView.image = nil
            return
        }
        if shownKey == picture.key, imageView.image != nil { return }
        shownKey = picture.key
        imageView.image = nil
        task = Task { [weak self] in
            let image = await images.image(for: picture, fitting: fitting)
            guard !Task.isCancelled, let self, shownKey == picture.key else { return }
            imageView.image = image
            imageView.alpha = 0
            UIView.animate(withDuration: 0.18) { self.imageView.alpha = 1 }
        }
    }
}

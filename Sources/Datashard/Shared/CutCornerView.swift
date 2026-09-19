import UIKit

/// A panel with the game's signature chamfered corners (top-right and
/// bottom-left cut), optionally outlined.
final class CutCornerView: UIView {
    var cut: CGFloat = Theme.cut { didSet { setNeedsLayout() } }
    var fill: UIColor = Theme.panel { didSet { shape.fillColor = fill.cgColor } }
    var outline: UIColor? { didSet { shape.strokeColor = outline?.cgColor; shape.lineWidth = outline == nil ? 0 : 1 } }

    private let shape = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        shape.fillColor = fill.cgColor
        shape.lineWidth = 0
        layer.insertSublayer(shape, at: 0)
        observeStyleChanges()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        shape.frame = bounds
        shape.path = Self.path(in: bounds, cut: cut).cgPath
    }

    private func observeStyleChanges() {
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
            self.shape.fillColor = self.fill.cgColor
            self.shape.strokeColor = self.outline?.cgColor
        }
    }

    static func path(in rect: CGRect, cut: CGFloat) -> UIBezierPath {
        let c = min(cut, rect.width / 2, rect.height / 2)
        let path = UIBezierPath()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - c, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + c))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + c, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - c))
        path.close()
        return path
    }
}

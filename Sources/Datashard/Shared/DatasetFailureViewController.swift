import UIKit

/// Shown instead of the menu when the bundled dataset cannot be opened; the
/// only way to reach it is a broken build, so it says exactly what failed.
final class DatasetFailureViewController: UIViewController {
    private let message: String

    init(message: String) {
        self.message = message
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.bg
        let title = GlitchTitleLabel(size: 30)
        title.text = "Dataset offline"
        let body = UILabel()
        body.font = GameFont.mono(12)
        body.textColor = Theme.red
        body.numberOfLines = 0
        body.text = message
        let stack = UIStackView(arrangedSubviews: [title, body])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Theme.padding),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Theme.padding),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }
}

import UIKit

final class StoreStatsEmptyView: UIView {
    /// Whether the Jetpack image is shown to indicate the data are unavailable due to Jetpack-the-plugin.
    var showJetpackImage: Bool = false {
        didSet {
            updateJetpackImageVisibility()
        }
    }

    private lazy var jetpackImageView = UIImageView(image: .jetpackLogoImage.withRenderingMode(.alwaysTemplate))

    convenience init() {
        self.init(frame: .zero)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSubviews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupSubviews() {
        translatesAutoresizingMaskIntoConstraints = false

        let emptyView = UIView(frame: .zero)
        emptyView.backgroundColor = .systemColor(.secondarySystemBackground)
        emptyView.layer.cornerRadius = 2.0
        emptyView.translatesAutoresizingMaskIntoConstraints = false

        jetpackImageView.contentMode = .scaleAspectFit
        jetpackImageView.tintColor = .jetpackGreen
        jetpackImageView.translatesAutoresizingMaskIntoConstraints = false
        updateJetpackImageVisibility()

        addSubview(emptyView)
        addSubview(jetpackImageView)

        if ServiceLocator.featureFlagService.isFeatureFlagEnabled(.myStoreTabUpdates) {
            NSLayoutConstraint.activate([
                emptyView.widthAnchor.constraint(equalToConstant: 32),
                emptyView.heightAnchor.constraint(equalToConstant: 10),
                emptyView.centerXAnchor.constraint(equalTo: centerXAnchor),
                emptyView.centerYAnchor.constraint(equalTo: centerYAnchor),
                jetpackImageView.widthAnchor.constraint(equalToConstant: 14),
                jetpackImageView.heightAnchor.constraint(equalToConstant: 14),
                jetpackImageView.leadingAnchor.constraint(equalTo: emptyView.trailingAnchor, constant: 2),
                jetpackImageView.bottomAnchor.constraint(equalTo: emptyView.topAnchor),
                jetpackImageView.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 0)
            ])
        } else {
            NSLayoutConstraint.activate([
                widthAnchor.constraint(equalToConstant: 48),
                emptyView.widthAnchor.constraint(equalToConstant: 32),
                emptyView.heightAnchor.constraint(equalToConstant: 10),
                emptyView.centerXAnchor.constraint(equalTo: centerXAnchor),
                emptyView.topAnchor.constraint(equalTo: jetpackImageView.bottomAnchor),
                jetpackImageView.widthAnchor.constraint(equalToConstant: 14),
                jetpackImageView.heightAnchor.constraint(equalToConstant: 14),
                jetpackImageView.leadingAnchor.constraint(equalTo: emptyView.trailingAnchor),
                jetpackImageView.topAnchor.constraint(equalTo: topAnchor, constant: 4)
            ])
        }
    }
}

private extension StoreStatsEmptyView {
    func updateJetpackImageVisibility() {
        jetpackImageView.isHidden = showJetpackImage == false
    }
}

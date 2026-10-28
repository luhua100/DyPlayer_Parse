//
//  SideActionComponents.swift
//  MVVM_Local
//
//  对应 Flutter 文章第八节：右侧操作栏全部是无状态展示 + 回调。
//  子视图懒加载，`setup()` / `init` 里只加视图 + 约束。
//

import SnapKit
import UIKit

final class SideActionView: UIControl {
    private lazy var iconView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.tintColor = .white
        return view
    }()

    private lazy var countLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOpacity = 0.4
        label.layer.shadowRadius = 2
        label.layer.shadowOffset = CGSize(width: 0, height: 1)
        return label
    }()

    private lazy var stack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [iconView, countLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 2
        stack.isUserInteractionEnabled = false
        return stack
    }()

    var onTap: (() -> Void)?

    init(systemName: String) {
        super.init(frame: .zero)
        setup()
        configure(systemName: systemName, count: nil, active: false)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setup() {
        addSubview(stack)

        stack.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(2)
            make.bottom.equalToSuperview().offset(-2)
            make.centerX.equalToSuperview()
        }

        iconView.snp.makeConstraints { make in
            make.width.height.equalTo(34)
        }

        snp.makeConstraints { make in
            make.width.greaterThanOrEqualTo(52)
        }

        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
    }

    func configure(systemName: String, count: Int?, active: Bool) {
        let config = UIImage.SymbolConfiguration(pointSize: 28, weight: .semibold)
        iconView.image = UIImage(systemName: systemName, withConfiguration: config)
        iconView.tintColor = active ? UIColor(red: 1, green: 0.17, blue: 0.33, alpha: 1) : .white
        countLabel.text = count.map(formatCount)
        countLabel.isHidden = count == nil
        accessibilityLabel = count.map { "\(systemName) \(formatCount($0))" } ?? systemName
    }

    @objc private func handleTap() {
        bounce()
        onTap?()
    }

    func bounce() {
        UIView.animate(withDuration: 0.12, animations: {
            self.iconView.transform = CGAffineTransform(scaleX: 1.22, y: 1.22)
        }) { _ in
            UIView.animate(withDuration: 0.22,
                           delay: 0,
                           usingSpringWithDamping: 0.55,
                           initialSpringVelocity: 0.8,
                           options: [.curveEaseOut]) {
                self.iconView.transform = .identity
            }
        }
    }
}

final class FollowAvatarView: UIControl {
    private lazy var avatarContainer: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 24
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.white.cgColor
        view.clipsToBounds = true
        view.isUserInteractionEnabled = false
        return view
    }()

    private lazy var avatarImageView: RemoteImageView = {
        let view = RemoteImageView()
        view.isUserInteractionEnabled = false
        return view
    }()

    private lazy var placeholderLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()

    private lazy var badgeView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 1, green: 0.17, blue: 0.33, alpha: 1)
        view.layer.cornerRadius = 9
        view.layer.borderWidth = 1.5
        view.layer.borderColor = UIColor.black.cgColor
        view.isUserInteractionEnabled = false
        return view
    }()

    private lazy var badgeIcon: UIImageView = {
        let view = UIImageView(image: UIImage(systemName: "plus",
                                              withConfiguration: UIImage.SymbolConfiguration(pointSize: 9,
                                                                                              weight: .bold)))
        view.tintColor = .white
        return view
    }()

    var onTap: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    convenience init() {
        self.init(frame: .zero)
    }

    private func setup() {
        addSubview(avatarContainer)
        avatarContainer.addSubview(placeholderLabel)
        avatarContainer.addSubview(avatarImageView)
        addSubview(badgeView)
        badgeView.addSubview(badgeIcon)

        avatarContainer.snp.makeConstraints { make in
            make.top.centerX.equalToSuperview()
            make.width.height.equalTo(48)
        }

        placeholderLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        avatarImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        badgeView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview()
            make.width.height.equalTo(18)
        }

        badgeIcon.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        snp.makeConstraints { make in
            make.width.equalTo(52)
            make.height.equalTo(58)
        }
    }

    func configure(url: URL?, name: String) {
        placeholderLabel.text = PlaceholderPalette.initial(for: name)
        avatarContainer.backgroundColor = PlaceholderPalette.color(for: name)
        avatarImageView.setImage(url: url)
    }

    func setFollowed(_ followed: Bool) {
        badgeView.isHidden = followed
    }

    @objc private func handleTap() {
        onTap?()
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.12) {
                self.transform = self.isHighlighted
                    ? CGAffineTransform(scaleX: 0.92, y: 0.92)
                    : .identity
            }
        }
    }
}

final class SpinningDiscView: UIView {
    private lazy var imageView: RemoteImageView = {
        let view = RemoteImageView()
        view.contentMode = .scaleAspectFill
        return view
    }()

    private lazy var overlay: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.22)
        return view
    }()

    private lazy var noteView: UIImageView = {
        let view = UIImageView(image: UIImage(systemName: "music.note",
                                              withConfiguration: UIImage.SymbolConfiguration(pointSize: 16,
                                                                                              weight: .semibold)))
        view.tintColor = .white
        return view
    }()

    private var isSpinning = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        clipsToBounds = true
        layer.borderWidth = 1.5
        layer.borderColor = UIColor.white.withAlphaComponent(0.5).cgColor

        addSubview(imageView)
        addSubview(overlay)
        addSubview(noteView)

        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        overlay.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        noteView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    convenience init() {
        self.init(frame: .zero)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.width / 2
    }

    func configure(url: URL?, seed: String) {
        backgroundColor = PlaceholderPalette.color(for: seed)
        imageView.setImage(url: url)
    }

    func setSpinning(_ spinning: Bool) {
        guard spinning != isSpinning else { return }
        isSpinning = spinning

        if spinning {
            let animation = CABasicAnimation(keyPath: "transform.rotation")
            animation.fromValue = 0
            animation.toValue = CGFloat.pi * 2
            animation.duration = 6
            animation.repeatCount = .infinity
            animation.isRemovedOnCompletion = false
            layer.add(animation, forKey: "rotation")
        } else {
            layer.removeAnimation(forKey: "rotation")
        }
    }
}

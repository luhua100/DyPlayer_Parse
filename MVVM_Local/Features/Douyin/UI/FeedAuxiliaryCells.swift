//
//  FeedAuxiliaryCells.swift
//  MVVM_Local
//
//  信息流里除普通短视频之外的两种卡片：
//  - LiveCardCell：直播。封面 + 「直播中」呼吸动画 + 主播信息，点击进直播页；
//  - AdCardCell：广告封面。封面 + 「广告」角标 + 广告语，点击弹提示。
//  两者都不占用播放器池，也不触发点赞/评论等短视频交互。
//  子视图全部懒加载，`setup()` 只加视图 + 约束。
//

import SnapKit
import UIKit

// MARK: - 直播卡片

final class LiveCardCell: UICollectionViewCell {
    static let reuseIdentifier = "LiveCardCell"

    private lazy var coverImageView: RemoteImageView = {
        let view = RemoteImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        return view
    }()

    private lazy var coverPlaceholder = CoverPlaceholderView()

    private lazy var dimView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        view.isUserInteractionEnabled = false
        return view
    }()

    private lazy var bottomScrim: GradientView = {
        let view = GradientView()
        view.configure(colors: [.clear, UIColor.black.withAlphaComponent(0.85)])
        view.isUserInteractionEnabled = false
        return view
    }()

    private lazy var tapGesture: UITapGestureRecognizer = {
        let gesture = UITapGestureRecognizer()
        gesture.addTarget(self, action: #selector(handleTap))
        return gesture
    }()

    private lazy var liveBadge = LiveBadgeView()

    private lazy var avatarView = FollowAvatarView()

    private lazy var authorLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .white
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOpacity = 0.4
        label.layer.shadowRadius = 3
        label.layer.shadowOffset = CGSize(width: 0, height: 1)
        return label
    }()

    private lazy var viewerLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = UIColor.white.withAlphaComponent(0.8)
        return label
    }()

    private lazy var descLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = UIColor.white.withAlphaComponent(0.85)
        label.numberOfLines = 2
        return label
    }()

    /// 悬浮在封面上的「点击进入直播间」胶囊，左侧声浪条带播放器动画。
    private lazy var enterButton = LiveEnterButton()

    private lazy var infoStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [authorLabel, viewerLabel, descLabel])
        stack.axis = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        return stack
    }()

    var onTap: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setup() {
        contentView.backgroundColor = .black
        addGestureRecognizer(tapGesture)

        [coverImageView, coverPlaceholder, dimView, bottomScrim,
         liveBadge, enterButton, avatarView, infoStack].forEach(contentView.addSubview)

        coverImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        coverPlaceholder.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        dimView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        bottomScrim.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(320)
        }

        liveBadge.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.top.equalTo(contentView.safeAreaLayoutGuide).offset(72)
        }

        avatarView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.top.equalTo(infoStack.snp.top).offset(0)
            make.width.equalTo(52)
            make.height.equalTo(58)
        }

        // 胶囊不算进底部信息栈，像抖音那样单独浮在封面偏下的位置。
        enterButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(avatarView.snp.top).offset(-24)
            make.height.equalTo(34)
        }

        infoStack.snp.makeConstraints { make in
            make.leading.equalTo(avatarView.snp.trailing).offset(12)
            make.trailing.equalToSuperview().offset(-16)
            make.bottom.equalTo(contentView.safeAreaLayoutGuide).offset(-96)
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        liveBadge.stopAnimating()
        enterButton.stopAnimating()
        coverImageView.cancel()
    }

    func configure(video: VideoModel) {
        liveBadge.startAnimating()
        enterButton.startAnimating()
        coverPlaceholder.configure(seed: video.id, name: video.authorName)
        coverImageView.setImage(url: video.coverURL)
        authorLabel.text = video.authorName
        viewerLabel.text = "\(formatCount(video.viewerCount)) 人在看"
        descLabel.text = video.desc
        avatarView.configure(url: video.avatarURL, name: video.authorName)
        avatarView.setFollowed(true)
    }

    @objc private func handleTap() {
        onTap?()
    }
}

// MARK: - 广告卡片

final class AdCardCell: UICollectionViewCell {
    static let reuseIdentifier = "AdCardCell"

    private lazy var coverImageView: RemoteImageView = {
        let view = RemoteImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        return view
    }()

    private lazy var coverPlaceholder = CoverPlaceholderView()

    private lazy var bottomScrim: GradientView = {
        let view = GradientView()
        view.configure(colors: [.clear, UIColor.black.withAlphaComponent(0.8)])
        view.isUserInteractionEnabled = false
        return view
    }()

    private lazy var tapGesture: UITapGestureRecognizer = {
        let gesture = UITapGestureRecognizer()
        gesture.addTarget(self, action: #selector(handleTap))
        return gesture
    }()

    private lazy var adBadge: UILabel = {
        let label = UILabel()
        label.text = "广告"
        label.font = .systemFont(ofSize: 10, weight: .semibold)
        label.textColor = UIColor.black.withAlphaComponent(0.7)
        label.textAlignment = .center
        label.backgroundColor = UIColor.white.withAlphaComponent(0.75)
        label.layer.cornerRadius = 4
        label.clipsToBounds = true
        label.isUserInteractionEnabled = false
        return label
    }()

    private lazy var brandLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = UIColor.white.withAlphaComponent(0.8)
        return label
    }()

    private lazy var descLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        label.textColor = .white
        label.numberOfLines = 2
        return label
    }()

    private lazy var hintLabel: UILabel = {
        let label = UILabel()
        label.text = "点击查看详情 ›"
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = UIColor.white.withAlphaComponent(0.85)
        return label
    }()

    private lazy var infoStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [brandLabel, descLabel, hintLabel])
        stack.axis = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        return stack
    }()

    var onTap: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setup() {
        contentView.backgroundColor = .black
        addGestureRecognizer(tapGesture)

        [coverImageView, coverPlaceholder, bottomScrim, adBadge, infoStack].forEach(contentView.addSubview)

        coverImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        coverPlaceholder.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        bottomScrim.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(280)
        }

        adBadge.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.top.equalTo(contentView.safeAreaLayoutGuide).offset(72)
            make.width.equalTo(34)
            make.height.equalTo(18)
        }

        infoStack.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-20)
            make.bottom.equalTo(contentView.safeAreaLayoutGuide).offset(-96)
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        coverImageView.cancel()
    }

    func configure(video: VideoModel) {
        coverPlaceholder.configure(seed: video.id, name: video.authorName)
        coverImageView.setImage(url: video.coverURL)
        brandLabel.text = video.authorName
        descLabel.text = video.desc
    }

    @objc private func handleTap() {
        onTap?()
    }
}

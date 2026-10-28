//
//  ShortVideoCell.swift
//  MVVM_Local
//
//  对应 Flutter 文章第六节：一屏视频拆成多层，UI 只做展示 + 回调。
//  播放器不归 Cell 所有，Cell 只从 Pool 拿到 entry 后绑定 / 解绑。
//  所有子视图懒加载，`setup()` 只加视图 + 约束。
//

import Combine
import SnapKit
import UIKit

final class ShortVideoCell: UICollectionViewCell {
    static let reuseIdentifier = "ShortVideoCell"

    private lazy var playerView = PlayerLayerView()

    private lazy var coverPlaceholder = CoverPlaceholderView()

    private lazy var coverImageView = RemoteImageView()

    private lazy var topScrim: GradientView = {
        let view = GradientView()
        view.configure(colors: [UIColor.black.withAlphaComponent(0.55), .clear])
        return view
    }()

    private lazy var bottomScrim: GradientView = {
        let view = GradientView()
        view.configure(colors: [.clear, UIColor.black.withAlphaComponent(0.88)])
        return view
    }()

    private lazy var gestureView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()

    private lazy var singleTap: UITapGestureRecognizer = {
        let gesture = UITapGestureRecognizer()
        gesture.addTarget(self, action: #selector(handleSingleTap))
        return gesture
    }()

    private lazy var doubleTap: UITapGestureRecognizer = {
        let gesture = UITapGestureRecognizer()
        gesture.numberOfTapsRequired = 2
        gesture.addTarget(self, action: #selector(handleDoubleTap(_:)))
        return gesture
    }()

    private lazy var bottomInfoStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [authorLabel, descLabel, musicStack])
        stack.axis = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.isUserInteractionEnabled = false
        return stack
    }()

    private lazy var authorLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        label.textColor = .white
        label.numberOfLines = 1
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOpacity = 0.35
        label.layer.shadowRadius = 3
        label.layer.shadowOffset = CGSize(width: 0, height: 1)
        return label
    }()

    private lazy var descLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .white
        label.numberOfLines = 2
        label.lineBreakMode = .byTruncatingTail
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOpacity = 0.35
        label.layer.shadowRadius = 3
        label.layer.shadowOffset = CGSize(width: 0, height: 1)
        return label
    }()

    private lazy var musicStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [musicIcon, musicLabel])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 4
        return stack
    }()

    private lazy var musicIcon: UIImageView = {
        let view = UIImageView(image: UIImage(systemName: "music.note",
                                              withConfiguration: UIImage.SymbolConfiguration(pointSize: 11,
                                                                                              weight: .semibold)))
        view.tintColor = .white
        return view
    }()

    private lazy var musicLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = .white
        label.numberOfLines = 1
        return label
    }()

    private lazy var sideStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [followAvatar, likeAction, commentAction, shareAction, disc])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 18
        return stack
    }()

    private lazy var followAvatar = FollowAvatarView()

    private lazy var likeAction = SideActionView(systemName: "heart.fill")

    private lazy var commentAction = SideActionView(systemName: "message.fill")

    private lazy var shareAction = SideActionView(systemName: "arrowshape.turn.up.right.fill")

    private lazy var disc = SpinningDiscView()

    private lazy var progressBar = VideoProgressBar()

    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.color = UIColor.white.withAlphaComponent(0.75)
        spinner.hidesWhenStopped = true
        return spinner
    }()

    private lazy var pauseIcon: UIImageView = {
        let view = UIImageView(image: UIImage(systemName: "play.fill",
                                              withConfiguration: UIImage.SymbolConfiguration(pointSize: 42,
                                                                                             weight: .semibold)))
        view.tintColor = UIColor.white.withAlphaComponent(0.85)
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.5
        view.layer.shadowRadius = 8
        view.layer.shadowOffset = .zero
        view.isHidden = true
        return view
    }()

    private lazy var failedView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.isHidden = true
        return view
    }()

    private lazy var failedStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [failedIcon, failedLabel, retryButton])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 8
        return stack
    }()

    private lazy var failedIcon: UIImageView = {
        let view = UIImageView(image: UIImage(systemName: "exclamationmark.triangle",
                                              withConfiguration: UIImage.SymbolConfiguration(pointSize: 32,
                                                                                              weight: .regular)))
        view.tintColor = UIColor.white.withAlphaComponent(0.7)
        view.contentMode = .scaleAspectFit
        return view
    }()

    private lazy var failedLabel: UILabel = {
        let label = UILabel()
        label.text = "视频加载失败"
        label.font = .systemFont(ofSize: 13)
        label.textColor = UIColor.white.withAlphaComponent(0.7)
        label.textAlignment = .center
        return label
    }()

    private lazy var retryButton: UIButton = {
        var configuration = UIButton.Configuration.bordered()
        configuration.title = "点击重试"
        configuration.baseForegroundColor = .white
        configuration.baseBackgroundColor = .clear
        configuration.cornerStyle = .capsule
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 7, leading: 18, bottom: 7, trailing: 18)

        let button = UIButton(type: .system)
        button.configuration = configuration
        button.addTarget(self, action: #selector(handleRetry), for: .touchUpInside)
        return button
    }()

    private var progressBottomConstraint: Constraint?
    private var heartViews: [UIImageView] = []

    private var video: VideoModel?
    private var entry: VideoPlayerEntry?
    private var cancellables = Set<AnyCancellable>()
    private var isActive = false
    private var playbackRequested = false
    private var shouldReplayWhenReady = true

    var onLike: (() -> Void)?
    var onDoubleLike: (() -> Void)?
    var onFollow: (() -> Void)?
    var onComment: (() -> Void)?
    var onShare: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - 布局

    private func setup() {
        contentView.backgroundColor = .black

        [playerView, coverPlaceholder, coverImageView, topScrim, bottomScrim,
         gestureView, bottomInfoStack, sideStack, progressBar,
         loadingIndicator, pauseIcon, failedView].forEach(contentView.addSubview)
        failedView.addSubview(failedStack)

        setupGestures()
        setupActions()

        playerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        coverPlaceholder.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        coverImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        topScrim.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(190)
        }

        bottomScrim.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(320)
        }

        gestureView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        bottomInfoStack.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.trailing.lessThanOrEqualTo(sideStack.snp.leading).offset(-14)
            make.bottom.equalTo(progressBar.snp.top).offset(-12)
        }

        musicIcon.snp.makeConstraints { make in
            make.width.height.equalTo(14)
        }

        sideStack.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-10)
            make.bottom.equalTo(progressBar.snp.top).offset(-18)
        }

        disc.snp.makeConstraints { make in
            make.width.height.equalTo(48)
        }

        progressBar.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(22)
            progressBottomConstraint = make.bottom.equalToSuperview().offset(-8).constraint
        }

        loadingIndicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        pauseIcon.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        failedView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        failedStack.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        failedIcon.snp.makeConstraints { make in
            make.width.height.equalTo(36)
        }
    }

    private func setupGestures() {
        singleTap.require(toFail: doubleTap)
        gestureView.addGestureRecognizer(singleTap)
        gestureView.addGestureRecognizer(doubleTap)
    }

    /// 右侧操作栏的点击统一在这里接到 Cell 的对外回调上。
    /// 控件本身只负责「变样式 + 回调」，接业务（关注接口、弹评论、分享）是外面的事。
    private func setupActions() {
        followAvatar.onTap = { [weak self] in
            self?.onFollow?()
        }

        likeAction.onTap = { [weak self] in
            self?.onLike?()
        }

        commentAction.onTap = { [weak self] in
            self?.onComment?()
        }

        shareAction.onTap = { [weak self] in
            self?.onShare?()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let bottomInset = max(safeAreaInsets.bottom, window?.safeAreaInsets.bottom ?? 0)
        progressBottomConstraint?.update(offset: -(max(bottomInset, 8) + 2))
    }

    // MARK: - 对外配置

    func configure(video: VideoModel,
                   entry: VideoPlayerEntry?,
                   active: Bool,
                   muted: Bool) {
        self.video = video
        self.entry = entry
        self.isActive = active
        self.playbackRequested = false
        self.shouldReplayWhenReady = true
        self.cancellables.removeAll()

        apply(video: video)
        bind(entry: entry, muted: muted)

        guard let entry else {
            apply(status: .failed)
            return
        }

        entry.ensureInitialized()
        apply(status: entry.status)
        if active {
            playIfReady()
        } else {
            entry.pause()
            detachPlayer()
        }
    }

    func applyInteraction(video: VideoModel) {
        self.video = video
        likeAction.configure(systemName: "heart.fill",
                             count: video.likeCount,
                             active: video.liked)
        followAvatar.setFollowed(video.followed)
    }

    func setActive(_ active: Bool, replay: Bool) {
        guard active else {
            isActive = false
            playbackRequested = false
            shouldReplayWhenReady = false
            entry?.pause()
            detachPlayer()
            applyPlaying(entry?.isPlaying ?? false)
            return
        }

        isActive = true
        playbackRequested = false
        shouldReplayWhenReady = replay
        entry?.ensureInitialized()
        apply(status: entry?.status ?? .idle)
        playIfReady()
    }

    func resumePlayback() {
        setActive(true, replay: false)
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        isActive = false
        playbackRequested = false
        entry?.pause()
        detachPlayer()
        cancellables.removeAll()
        entry = nil
        video = nil

        coverImageView.cancel()
        loadingIndicator.stopAnimating()
        failedView.isHidden = true
        pauseIcon.isHidden = true
        disc.setSpinning(false)
        heartViews.forEach { $0.removeFromSuperview() }
        heartViews.removeAll()
    }

    // MARK: - 播放状态

    private func bind(entry: VideoPlayerEntry?, muted: Bool) {
        guard let entry else { return }
        entry.setMuted(muted)

        entry.statusSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self else { return }
                self.apply(status: status)
                self.playIfReady()
            }
            .store(in: &cancellables)

        entry.playingSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] playing in
                self?.applyPlaying(playing)
            }
            .store(in: &cancellables)
    }

    private func playIfReady() {
        guard isActive,
              !playbackRequested,
              let entry,
              entry.status == .ready else { return }

        playbackRequested = true
        if shouldReplayWhenReady {
            entry.replay()
        } else {
            entry.play()
        }
    }

    private func apply(status: VideoLoadStatus) {
        switch status {
        case .idle, .loading:
            loadingIndicator.startAnimating()
            failedView.isHidden = true
            detachPlayer()

        case .ready:
            loadingIndicator.stopAnimating()
            failedView.isHidden = true
            if isActive {
                attachPlayer()
            } else {
                detachPlayer()
            }

        case .failed:
            loadingIndicator.stopAnimating()
            failedView.isHidden = false
            detachPlayer()
            pauseIcon.isHidden = true
        }

        applyPlaying(entry?.isPlaying ?? false)
    }

    private func applyPlaying(_ playing: Bool) {
        let waiting = isActive && (entry?.isWaiting ?? false)
        pauseIcon.isHidden = !(isActive && entry?.status == .ready && !playing && !waiting)
        disc.setSpinning(playing && isActive)

        if isActive && (entry?.status == .loading || waiting) {
            loadingIndicator.startAnimating()
        } else {
            loadingIndicator.stopAnimating()
        }
    }

    private func attachPlayer() {
        guard let entry, isActive, entry.status == .ready else { return }
        playerView.player = entry.player
        progressBar.player = entry.player
        coverPlaceholder.isHidden = true
        coverImageView.isHidden = true
    }

    private func detachPlayer() {
        playerView.player = nil
        progressBar.player = nil
        coverPlaceholder.isHidden = false
        coverImageView.isHidden = false
    }

    // MARK: - 展示

    private func apply(video: VideoModel) {
        authorLabel.text = video.authorName
        descLabel.text = video.desc
        musicLabel.text = video.musicName

        coverPlaceholder.configure(seed: video.id, name: video.authorName)
        coverImageView.setImage(url: video.coverURL)

        followAvatar.configure(url: video.avatarURL, name: video.authorName)
        followAvatar.setFollowed(video.followed)
        likeAction.configure(systemName: "heart.fill", count: video.likeCount, active: video.liked)
        commentAction.configure(systemName: "message.fill", count: video.commentCount, active: false)
        shareAction.configure(systemName: "arrowshape.turn.up.right.fill", count: video.shareCount, active: false)
        disc.configure(url: video.coverURL, seed: video.id)
    }

    // MARK: - 手势

    @objc private func handleSingleTap() {
        guard isActive, let entry, entry.status == .ready else { return }
        if entry.isPlaying {
            entry.pause()
        } else {
            entry.play()
        }
    }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        guard isActive else { return }
        addHeart(at: gesture.location(in: contentView))
        likeAction.bounce()
        onDoubleLike?()
    }

    @objc private func handleRetry() {
        guard let entry else { return }
        playbackRequested = false
        shouldReplayWhenReady = true
        entry.ensureInitialized()
    }

    private func addHeart(at point: CGPoint) {
        let size: CGFloat = 100
        let heart = UIImageView(image: UIImage(systemName: "heart.fill",
                                               withConfiguration: UIImage.SymbolConfiguration(pointSize: 88, weight: .bold)))
        heart.tintColor = UIColor(red: 1, green: 0.17, blue: 0.33, alpha: 1)
        heart.alpha = 0
        heart.transform = CGAffineTransform(scaleX: 0.4, y: 0.4)
        heart.isUserInteractionEnabled = false
        contentView.addSubview(heart)
        heartViews.append(heart)

        heart.snp.makeConstraints { make in
            make.width.height.equalTo(size)
            make.centerX.equalToSuperview().offset(point.x - contentView.bounds.midX)
            make.centerY.equalToSuperview().offset(point.y - contentView.bounds.midY)
        }

        UIView.animate(withDuration: 0.28,
                       delay: 0,
                       usingSpringWithDamping: 0.55,
                       initialSpringVelocity: 0.9,
                       options: [.curveEaseOut]) {
            heart.alpha = 1
            heart.transform = CGAffineTransform(scaleX: 1.15, y: 1.15)
        } completion: { _ in
            UIView.animate(withDuration: 0.3, delay: 0.18, options: [.curveEaseOut]) {
                heart.alpha = 0
                heart.transform = CGAffineTransform(scaleX: 1.35, y: 1.35)
            } completion: { _ in
                heart.removeFromSuperview()
                self.heartViews.removeAll { $0 === heart }
            }
        }
    }
}

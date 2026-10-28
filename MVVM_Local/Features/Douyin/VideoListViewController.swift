//
//  VideoListViewController.swift
//  MVVM_Local
//
//  视频列表页：从根页面进入，点任意一条再进入竖屏播放页。
//  列表只负责浏览与选片，播放细节仍然交给 DouyinViewController。
//  子视图全部懒加载，`setup()` 里只加视图 + 约束。
//

import SnapKit
import UIKit

final class VideoListViewController: UIViewController {
    private let repository: VideoRepository

    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 112
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 94, bottom: 0, right: 16)
        tableView.register(VideoListCell.self,
                           forCellReuseIdentifier: VideoListCell.reuseIdentifier)

        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(handleReload), for: .valueChanged)
        tableView.refreshControl = refreshControl
        return tableView
    }()

    private lazy var footerLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .footnote)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.text = "上拉加载更多"
        return label
    }()

    private lazy var spinner: UIActivityIndicatorView = {
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.hidesWhenStopped = true
        return spinner
    }()

    private lazy var errorOverlay: UIView = {
        let overlay = UIView()
        overlay.backgroundColor = .systemBackground
        overlay.isHidden = true

        let stack = UIStackView(arrangedSubviews: [errorLabel, retryButton])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        overlay.addSubview(stack)

        stack.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(32)
        }
        return overlay
    }()

    private lazy var errorLabel: UILabel = {
        let label = UILabel()
        label.text = "加载失败"
        label.font = .preferredFont(forTextStyle: .footnote)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 2
        return label
    }()

    private lazy var retryButton: UIButton = {
        var configuration = UIButton.Configuration.bordered()
        configuration.title = "重试"
        configuration.cornerStyle = .capsule

        let button = UIButton(type: .system)
        button.configuration = configuration
        button.addTarget(self, action: #selector(handleRetry), for: .touchUpInside)
        return button
    }()

    private var items: [VideoModel] = []
    private var page = -1
    private var hasMore = true
    private var isLoading = false
    private var loadTask: Task<Void, Never>?

    init(repository: VideoRepository = VideoRepository()) {
        self.repository = repository
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        self.repository = VideoRepository()
        super.init(coder: coder)
    }

    deinit {
        loadTask?.cancel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
        loadFirstPage()
    }

    // MARK: - 界面

    private func setup() {
        title = "视频列表"
        view.backgroundColor = .systemBackground
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "arrow.clockwise"),
            style: .plain,
            target: self,
            action: #selector(handleReload)
        )

        // 顺序即层级：错误遮罩最后加，保证盖在列表上。
        [tableView, footerLabel, spinner, errorOverlay].forEach(view.addSubview)

        tableView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(footerLabel.snp.top)
        }

        footerLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide)
            make.height.equalTo(36)
        }

        spinner.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        errorOverlay.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    // MARK: - 数据

    private func loadFirstPage() {
        loadTask?.cancel()
        items = []
        page = -1
        hasMore = true
        tableView.reloadData()
        errorOverlay.isHidden = true
        loadNextPage()
    }

    private func loadNextPage() {
        guard !isLoading, hasMore else { return }

        isLoading = true
        footerLabel.text = "加载中…"
        if items.isEmpty {
            spinner.startAnimating()
        }

        let nextPage = page + 1
        loadTask = Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                let list = try await self.repository.fetchFeed(channel: .recommended,
                                                               page: nextPage,
                                                               salt: 0)
                guard !Task.isCancelled else { return }

                if nextPage == 0 {
                    self.items = list
                    self.tableView.reloadData()
                } else {
                    self.append(list)
                }

                self.page = nextPage
                self.hasMore = list.count >= self.repository.pageSize
                self.errorOverlay.isHidden = true
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                if self.items.isEmpty {
                    self.errorLabel.text = error.localizedDescription
                    self.errorOverlay.isHidden = false
                } else {
                    self.footerLabel.text = "加载失败，上拉重试"
                }
            }

            self.isLoading = false
            self.spinner.stopAnimating()
            self.tableView.refreshControl?.endRefreshing()
            self.updateFooter()
        }
    }

    private func append(_ list: [VideoModel]) {
        let existing = Set(items.map(\.id))
        let fresh = list.filter { !existing.contains($0.id) }
        guard !fresh.isEmpty else { return }

        let start = items.count
        items.append(contentsOf: fresh)
        let indexPaths = (start..<items.count).map { IndexPath(row: $0, section: 0) }
        tableView.performBatchUpdates {
            tableView.insertRows(at: indexPaths, with: .automatic)
        }
    }

    private func updateFooter() {
        if isLoading {
            footerLabel.text = "加载中…"
        } else if hasMore {
            footerLabel.text = "上拉加载更多"
        } else {
            footerLabel.text = "没有更多了"
        }
    }

    // MARK: - 动作

    @objc private func handleReload() {
        guard !isLoading else {
            tableView.refreshControl?.endRefreshing()
            return
        }
        loadFirstPage()
    }

    @objc private func handleRetry() {
        loadFirstPage()
    }

    private func openPlayer(for video: VideoModel) {
        let player = DouyinViewController(initialVideo: video)
        player.modalPresentationStyle = .fullScreen
        present(player, animated: true)
    }

    /// 直播：列表页直接进直播页（直播页只有一个「直播页面」占位文案）。
    private func openLiveRoom(for video: VideoModel) {
        let room = LiveRoomViewController(video: video)
        room.modalPresentationStyle = .fullScreen
        present(room, animated: true)
    }

    /// 广告封面：按需求只弹提示。
    private func showAdAlert(for video: VideoModel) {
        let alert = UIAlertController(title: "广告", message: video.desc, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "知道了", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension VideoListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: VideoListCell.reuseIdentifier,
                                                 for: indexPath)
        (cell as? VideoListCell)?.configure(video: items[indexPath.row])
        return cell
    }
}

// MARK: - UITableViewDelegate

extension VideoListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let video = items[indexPath.row]
        switch video.kind {
        case .video:
            openPlayer(for: video)
        case .live:
            openLiveRoom(for: video)
        case .ad:
            showAdAlert(for: video)
        }
    }

    func tableView(_ tableView: UITableView,
                   willDisplay cell: UITableViewCell,
                   forRowAt indexPath: IndexPath) {
        guard indexPath.row == items.count - 1 else { return }
        loadNextPage()
    }
}

// MARK: - Cell

private final class VideoListCell: UITableViewCell {
    static let reuseIdentifier = "VideoListCell"

    private lazy var thumbnailView: RemoteImageView = {
        let view = RemoteImageView()
        view.layer.cornerRadius = 8
        view.clipsToBounds = true
        view.backgroundColor = .secondarySystemBackground
        return view
    }()

    private lazy var playIcon: UIImageView = {
        let view = UIImageView(image: UIImage(systemName: "play.circle.fill",
                                              withConfiguration: UIImage.SymbolConfiguration(pointSize: 22,
                                                                                              weight: .semibold)))
        view.tintColor = UIColor.white.withAlphaComponent(0.9)
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.5
        view.layer.shadowRadius = 4
        view.layer.shadowOffset = .zero
        return view
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .label
        label.numberOfLines = 2
        return label
    }()

    private lazy var authorLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        return label
    }()

    private lazy var metaLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .tertiaryLabel
        return label
    }()

    /// 直播行角标：带「直播中」呼吸动画。
    private lazy var liveBadge = LiveBadgeView()

    /// 广告行角标：静态小标签。
    private lazy var adBadge: UILabel = {
        let label = UILabel()
        label.text = "广告"
        label.font = .systemFont(ofSize: 10, weight: .semibold)
        label.textColor = UIColor.black.withAlphaComponent(0.7)
        label.textAlignment = .center
        label.backgroundColor = UIColor.white.withAlphaComponent(0.9)
        label.layer.cornerRadius = 4
        label.clipsToBounds = true
        label.isHidden = true
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setup() {
        selectionStyle = .none
        backgroundColor = .systemBackground

        [thumbnailView, playIcon, liveBadge, adBadge,
         titleLabel, authorLabel, metaLabel].forEach(contentView.addSubview)

        thumbnailView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.width.equalTo(66)
            make.height.equalTo(88)
        }

        playIcon.snp.makeConstraints { make in
            make.center.equalTo(thumbnailView)
        }

        liveBadge.snp.makeConstraints { make in
            make.leading.equalTo(thumbnailView).offset(4)
            make.bottom.equalTo(thumbnailView).offset(-4)
        }

        adBadge.snp.makeConstraints { make in
            make.leading.equalTo(thumbnailView).offset(4)
            make.top.equalTo(thumbnailView).offset(4)
            make.width.equalTo(34)
            make.height.equalTo(18)
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(thumbnailView.snp.trailing).offset(12)
            make.trailing.equalToSuperview().offset(-16)
            make.top.equalTo(thumbnailView).offset(2)
        }

        authorLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.trailing.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
        }

        metaLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.trailing.equalTo(titleLabel)
            make.top.equalTo(authorLabel.snp.bottom).offset(4)
            make.bottom.lessThanOrEqualTo(thumbnailView)
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailView.cancel()
        liveBadge.stopAnimating()
        titleLabel.text = nil
        authorLabel.text = nil
        metaLabel.text = nil
    }

    func configure(video: VideoModel) {
        thumbnailView.setImage(url: video.coverURL)
        titleLabel.text = video.desc
        authorLabel.text = video.authorName

        // 三种卡片在列表里用角标 + meta 文案区分，点击行为由列表页分流。
        switch video.kind {
        case .video:
            playIcon.isHidden = false
            liveBadge.isHidden = true
            adBadge.isHidden = true
            liveBadge.stopAnimating()
            metaLabel.text = "♥ \(formatCount(video.likeCount)) · \(video.musicName)"
        case .live:
            playIcon.isHidden = true
            liveBadge.isHidden = false
            adBadge.isHidden = true
            liveBadge.startAnimating()
            metaLabel.text = "\(formatCount(video.viewerCount)) 人在看 · \(video.authorName)"
        case .ad:
            playIcon.isHidden = true
            liveBadge.isHidden = true
            adBadge.isHidden = false
            liveBadge.stopAnimating()
            metaLabel.text = "广告 · 点击查看详情"
        }
    }
}

//
//  FeedChannelViewController.swift
//  MVVM_Local
//
//  对应 Flutter 文章第九节：单个频道的信息流。
//  竖向分页 + 预加载窗口 + 触底加载 + 首屏错误重试。
//  列表、遮罩、加载指示器都懒加载，`setup()` 只加视图 + 约束。
//

import SnapKit
import UIKit

final class FeedChannelViewController: UIViewController {
    let channel: VideoChannel

    private let repository: VideoRepository
    private let pool: VideoPlayerPool
    private let initialVideo: VideoModel?

    private lazy var layout: UICollectionViewFlowLayout = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        layout.sectionInset = .zero
        return layout
    }()

    private lazy var collectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .black
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.isPagingEnabled = true
        collectionView.showsVerticalScrollIndicator = false
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.decelerationRate = .fast
        collectionView.register(ShortVideoCell.self,
                                forCellWithReuseIdentifier: ShortVideoCell.reuseIdentifier)
        collectionView.register(LiveCardCell.self,
                                forCellWithReuseIdentifier: LiveCardCell.reuseIdentifier)
        collectionView.register(AdCardCell.self,
                                forCellWithReuseIdentifier: AdCardCell.reuseIdentifier)

        let refreshControl = UIRefreshControl()
        refreshControl.tintColor = .white
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        collectionView.refreshControl = refreshControl
        return collectionView
    }()

    private lazy var loadingOverlay: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        return view
    }()

    private lazy var loadingSpinner: UIActivityIndicatorView = {
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = UIColor.white.withAlphaComponent(0.75)
        return spinner
    }()

    private lazy var errorOverlay: UIView = {
        let overlay = UIView()
        overlay.backgroundColor = .black
        overlay.isHidden = true

        let stack = UIStackView(arrangedSubviews: [errorLabel, retryButton])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        overlay.addSubview(stack)

        stack.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(32)
        }
        return overlay
    }()

    private lazy var errorLabel: UILabel = {
        let label = UILabel()
        label.text = "加载失败"
        label.textColor = UIColor.white.withAlphaComponent(0.75)
        label.font = .preferredFont(forTextStyle: .footnote)
        label.textAlignment = .center
        label.numberOfLines = 2
        return label
    }()

    private lazy var retryButton: UIButton = {
        var configuration = UIButton.Configuration.bordered()
        configuration.title = "重试"
        configuration.baseForegroundColor = .white
        configuration.baseBackgroundColor = .clear
        configuration.cornerStyle = .capsule

        let button = UIButton(type: .system)
        button.configuration = configuration
        button.addTarget(self, action: #selector(handleRetry), for: .touchUpInside)
        return button
    }()

    private lazy var loadMoreIndicator: UIActivityIndicatorView = {
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.color = UIColor.white.withAlphaComponent(0.8)
        spinner.hidesWhenStopped = true
        return spinner
    }()

    private var items: [VideoModel] = []
    private var page = 0
    private var salt = 0
    private var currentIndex = 0
    private var isActive = false
    private var isFirstLoading = false
    private var isLoadingMore = false
    private var hasMore = true

    private var firstLoadTask: Task<Void, Never>?
    private var loadMoreTask: Task<Void, Never>?

    var onComment: ((VideoModel) -> Void)?
    var onShare: ((VideoModel, UIView) -> Void)?
    var onOpenLive: ((VideoModel) -> Void)?
    var onTapAd: ((VideoModel) -> Void)?

    init(channel: VideoChannel,
         repository: VideoRepository,
         pool: VideoPlayerPool,
         initialVideo: VideoModel? = nil) {
        self.channel = channel
        self.repository = repository
        self.pool = pool
        self.initialVideo = initialVideo
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        firstLoadTask?.cancel()
        loadMoreTask?.cancel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let size = collectionView.bounds.size
        guard size.width > 0, size.height > 0 else { return }
        guard layout.itemSize.height != size.height || layout.itemSize.width != size.width else { return }

        layout.itemSize = size
        layout.invalidateLayout()
        collectionView.layoutIfNeeded()

        if !items.isEmpty {
            let offset = CGPoint(x: 0, y: CGFloat(currentIndex) * size.height)
            collectionView.setContentOffset(offset, animated: false)
        }
    }

    // MARK: - 对外生命周期

    func setActive(_ active: Bool, replay: Bool = true) {
        isActive = active

        guard active else {
            collectionView.visibleCells
                .compactMap { $0 as? ShortVideoCell }
                .forEach { $0.setActive(false, replay: false) }
            return
        }

        if items.isEmpty {
            if !isFirstLoading {
                loadFirstPage()
            }
            return
        }

        collectionView.layoutIfNeeded()
        syncPlayback(resume: replay)
    }

    func resumePlayback() {
        guard isActive, !items.isEmpty else { return }
        collectionView.layoutIfNeeded()
        syncPlayback(resume: false)
    }

    /// 打开评论 / 分享弹层时调用：暂停当前播放，但保留频道激活状态。
    func pausePlayback() {
        collectionView.visibleCells
            .compactMap { $0 as? ShortVideoCell }
            .forEach { $0.setActive(false, replay: false) }
    }

    // MARK: - 界面

    private func setup() {
        view.backgroundColor = .black

        // 顺序即层级：加载/错误遮罩盖在列表上。
        [collectionView, loadMoreIndicator, loadingOverlay, errorOverlay].forEach(view.addSubview)
        loadingOverlay.addSubview(loadingSpinner)

        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        loadMoreIndicator.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-56)
        }

        loadingOverlay.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        loadingSpinner.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        errorOverlay.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    // MARK: - 数据

    private func loadFirstPage() {
        guard !isFirstLoading else { return }

        isFirstLoading = true
        errorOverlay.isHidden = true
        loadingOverlay.isHidden = false
        loadingSpinner.startAnimating()

        loadMoreTask?.cancel()
        isLoadingMore = false
        loadMoreIndicator.stopAnimating()

        firstLoadTask?.cancel()
        firstLoadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let list = try await self.repository.fetchFeed(channel: self.channel,
                                                               page: 0,
                                                               salt: self.salt)
                guard !Task.isCancelled else { return }
                self.applyFirstPage(list)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                self.items = []
                self.currentIndex = 0
                self.errorLabel.text = error.localizedDescription
                self.errorOverlay.isHidden = false
                self.collectionView.reloadData()
            }

            self.isFirstLoading = false
            self.loadingSpinner.stopAnimating()
            self.loadingOverlay.isHidden = true
            self.collectionView.refreshControl?.endRefreshing()
        }
    }

    private func applyFirstPage(_ list: [VideoModel]) {
        items = list
        page = 0
        currentIndex = 0
        // 一页没取满就说明没有下一页，别在触底时反复请求空页。
        hasMore = list.count >= repository.pageSize

        // 从视频列表点进来：优先定位到点选的那条；不在首屏里就置顶播放。
        if let initialVideo {
            if let index = items.firstIndex(where: { $0.id == initialVideo.id }) {
                currentIndex = index
            } else {
                items.insert(initialVideo, at: 0)
            }
        }

        collectionView.reloadData()
        collectionView.layoutIfNeeded()

        let height = collectionView.bounds.height
        if height > 0, currentIndex > 0 {
            collectionView.setContentOffset(
                CGPoint(x: 0, y: CGFloat(currentIndex) * height),
                animated: false
            )
        } else {
            collectionView.setContentOffset(.zero, animated: false)
        }
        errorOverlay.isHidden = true

        syncPlayback(resume: true)
    }

    private func loadMore() {
        guard hasMore, isActive, !isFirstLoading, !isLoadingMore, !items.isEmpty else { return }

        isLoadingMore = true
        loadMoreIndicator.startAnimating()

        let nextPage = page + 1
        loadMoreTask?.cancel()
        loadMoreTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let list = try await self.repository.fetchFeed(channel: self.channel,
                                                               page: nextPage,
                                                               salt: self.salt)
                guard !Task.isCancelled, self.isActive else { return }
                self.appendPage(list, nextPage: nextPage)
            } catch is CancellationError {
                return
            } catch {
                // 加载更多失败不清空已有列表，用户继续上滑会再次触发。
            }

            self.isLoadingMore = false
            self.loadMoreIndicator.stopAnimating()
        }
    }

    private func appendPage(_ list: [VideoModel], nextPage: Int) {
        // 一页没取满 = 到底了，后面不再触发加载更多。
        hasMore = list.count >= repository.pageSize

        let existing = Set(items.map(\.id))
        let fresh = list.filter { !existing.contains($0.id) }
        guard !fresh.isEmpty else {
            page = nextPage
            return
        }

        let start = items.count
        items.append(contentsOf: fresh)
        page = nextPage

        let indexPaths = (start..<items.count).map { IndexPath(item: $0, section: 0) }
        collectionView.performBatchUpdates {
            collectionView.insertItems(at: indexPaths)
        }
    }

    // MARK: - 播放窗口

    private func syncPlayback(resume: Bool) {
        guard isActive, !items.isEmpty else { return }

        currentIndex = min(max(currentIndex, 0), items.count - 1)

        var keep = Set<String>()
        var preload: [URL] = []
        for index in (currentIndex - 1)...(currentIndex + 1) {
            guard items.indices.contains(index) else { continue }

            // 直播 / 广告卡片没有播放器，别白白占池子。
            let item = items[index]
            guard item.isPlayable, let url = item.streamURL else { continue }

            keep.insert(url.absoluteString)
            if index != currentIndex {
                preload.append(url)
            }
        }
        pool.retainOnly(keep)
        pool.preload(preload)

        let currentPath = IndexPath(item: currentIndex, section: 0)
        for case let cell as ShortVideoCell in collectionView.visibleCells {
            guard let indexPath = collectionView.indexPath(for: cell) else { continue }
            cell.setActive(indexPath == currentPath, replay: resume)
        }

        // 距离末尾还有 3 屏就开始加载
        if currentIndex >= items.count - 3 {
            loadMore()
        }
    }

    private func updateCurrentPageFromScroll(replay: Bool) {
        let height = collectionView.bounds.height
        guard height > 0, !items.isEmpty else { return }

        let raw = Int((collectionView.contentOffset.y / height).rounded())
        let index = min(max(raw, 0), items.count - 1)
        guard index != currentIndex else { return }

        currentIndex = index
        syncPlayback(resume: replay)
    }

    // MARK: - 交互

    @objc private func handleRefresh() {
        guard currentIndex == 0, !isFirstLoading else {
            collectionView.refreshControl?.endRefreshing()
            return
        }
        salt += 1
        loadFirstPage()
    }

    @objc private func handleRetry() {
        loadFirstPage()
    }

    private func toggleLike(at index: Int, forceLike: Bool) {
        guard items.indices.contains(index) else { return }
        var video = items[index]

        if forceLike {
            guard !video.liked else { return }
            video = video.copyWith(likeCount: video.likeCount + 1, liked: true)
        } else {
            let liked = !video.liked
            let count = max(0, video.likeCount + (liked ? 1 : -1))
            video = video.copyWith(likeCount: count, liked: liked)
        }

        items[index] = video
        if let cell = collectionView.cellForItem(at: IndexPath(item: index, section: 0)) as? ShortVideoCell {
            cell.applyInteraction(video: video)
        }
    }

    private func toggleFollow(at index: Int) {
        guard items.indices.contains(index) else { return }
        let video = items[index].copyWith(followed: !items[index].followed)
        items[index] = video
        if let cell = collectionView.cellForItem(at: IndexPath(item: index, section: 0)) as? ShortVideoCell {
            cell.applyInteraction(video: video)
        }
    }

    private func video(at index: Int) -> VideoModel? {
        guard items.indices.contains(index) else { return nil }
        return items[index]
    }
}

// MARK: - UICollectionViewDataSource

extension FeedChannelViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        items.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let video = items[indexPath.item]

        // 直播、广告各有自己的卡片，不占用播放器池。
        switch video.kind {
        case .live:
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: LiveCardCell.reuseIdentifier,
                for: indexPath
            )
            let liveCell = cell as? LiveCardCell
            liveCell?.configure(video: video)
            liveCell?.onTap = { [weak self] in
                self?.onOpenLive?(video)
            }
            return cell

        case .ad:
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: AdCardCell.reuseIdentifier,
                for: indexPath
            )
            let adCell = cell as? AdCardCell
            adCell?.configure(video: video)
            adCell?.onTap = { [weak self] in
                self?.onTapAd?(video)
            }
            return cell

        case .video:
            break
        }

        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: ShortVideoCell.reuseIdentifier,
            for: indexPath
        )
        guard let videoCell = cell as? ShortVideoCell else { return cell }

        let entry = video.streamURL.map { pool.entry(for: $0) }
        let active = isActive && indexPath.item == currentIndex

        videoCell.configure(video: video,
                            entry: entry,
                            active: active,
                            muted: pool.isMuted)

        videoCell.onLike = { [weak self, weak videoCell] in
            guard let self, let videoCell,
                  let current = self.collectionView.indexPath(for: videoCell) else { return }
            self.toggleLike(at: current.item, forceLike: false)
        }
        videoCell.onDoubleLike = { [weak self, weak videoCell] in
            guard let self, let videoCell,
                  let current = self.collectionView.indexPath(for: videoCell) else { return }
            self.toggleLike(at: current.item, forceLike: true)
        }
        videoCell.onFollow = { [weak self, weak videoCell] in
            guard let self, let videoCell,
                  let current = self.collectionView.indexPath(for: videoCell) else { return }
            self.toggleFollow(at: current.item)
        }
        videoCell.onComment = { [weak self, weak videoCell] in
            guard let self, let videoCell,
                  let current = self.collectionView.indexPath(for: videoCell),
                  let video = self.video(at: current.item) else { return }
            self.onComment?(video)
        }
        videoCell.onShare = { [weak self, weak videoCell] in
            guard let self, let videoCell,
                  let current = self.collectionView.indexPath(for: videoCell),
                  let video = self.video(at: current.item) else { return }
            self.onShare?(video, videoCell)
        }

        return videoCell
    }
}

// MARK: - UICollectionViewDelegate

extension FeedChannelViewController: UICollectionViewDelegate {
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            updateCurrentPageFromScroll(replay: true)
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        updateCurrentPageFromScroll(replay: true)
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        updateCurrentPageFromScroll(replay: true)
    }

    func collectionView(_ collectionView: UICollectionView,
                        didEndDisplaying cell: UICollectionViewCell,
                        forItemAt indexPath: IndexPath) {
        (cell as? ShortVideoCell)?.setActive(false, replay: false)
    }
}

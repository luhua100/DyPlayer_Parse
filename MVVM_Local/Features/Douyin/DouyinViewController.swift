//
//  DouyinViewController.swift
//  MVVM_Local
//
//  对应 Flutter 文章第十节：页面骨架。
//  只负责频道切换、生命周期、评论/分享弹层；播放细节全部在 FeedChannel 里。
//  顶部控件懒加载创建，`setupTopBar()` 只加视图 + 约束。
//

import AVFoundation
import SnapKit
import UIKit

final class DouyinViewController: UIViewController {
    private let pool = VideoPlayerPool(capacity: 4, muted: true)
    private let repository = VideoRepository()
    private let initialVideo: VideoModel?
    private var channels: [FeedChannelViewController] = []

    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        return view
    }()

    private lazy var topGradient: GradientView = {
        let view = GradientView()
        view.configure(colors: [UIColor.black.withAlphaComponent(0.55), .clear])
        return view
    }()

    private lazy var topBar: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()

    private lazy var searchButton: UIButton = {
        let button = UIButton(type: .system)
        let configuration = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        button.setImage(UIImage(systemName: "magnifyingglass", withConfiguration: configuration),
                        for: .normal)
        button.tintColor = .white
        button.addTarget(self, action: #selector(handleSearch), for: .touchUpInside)
        return button
    }()

    private lazy var closeButton: UIButton = {
        let button = UIButton(type: .system)
        let configuration = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        button.setImage(UIImage(systemName: "xmark", withConfiguration: configuration),
                        for: .normal)
        button.tintColor = .white
        button.addTarget(self, action: #selector(handleClose), for: .touchUpInside)
        return button
    }()

    /// 进页面默认静音，图片先按默认值给，`updateMuteButton()` 再校正。
    private lazy var muteButton: UIButton = {
        let button = UIButton(type: .system)
        let configuration = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        button.setImage(UIImage(systemName: "speaker.slash.fill", withConfiguration: configuration),
                        for: .normal)
        button.tintColor = .white
        button.addTarget(self, action: #selector(handleMute), for: .touchUpInside)
        return button
    }()

    private lazy var segmentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 26

        for (index, channel) in VideoChannel.allCases.enumerated() {
            stack.addArrangedSubview(makeSegmentButton(channel: channel, index: index))
        }
        return stack
    }()

    private var currentIndex: Int
    private var isActive = false
    private var isInterrupted = false
    private var observers: [NSObjectProtocol] = []

    /// 首次进入默认从「推荐」开始；从视频列表点进来时可带上点选的那条。
    init(initialVideo: VideoModel? = nil, initialChannel: VideoChannel = .recommended) {
        self.initialVideo = initialVideo
        self.currentIndex = VideoChannel.allCases.firstIndex(of: initialChannel) ?? 0
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        self.initialVideo = nil
        self.currentIndex = VideoChannel.allCases.firstIndex(of: .recommended) ?? 0
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupTopBar()
        setupChannels()
        registerNotifications()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !isActive {
            setActive(true)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isBeingDismissed || isMovingFromParent {
            setActive(false)
        }
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        pool.dispose()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    /// 根页面切到抖音时调用；切走时传 false。
    func setActive(_ active: Bool) {
        isActive = active

        guard !channels.isEmpty, channels.indices.contains(currentIndex) else { return }

        guard active else {
            channels[currentIndex].setActive(false)
            pool.pauseAll()
            return
        }

        channels[currentIndex].setActive(true, replay: true)
    }

    // MARK: - 界面

    private func setupTopBar() {
        [containerView, topBar].forEach(view.addSubview)
        topBar.addSubview(topGradient)
        [searchButton, closeButton, muteButton, segmentStack].forEach(topBar.addSubview)

        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        topBar.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(126)
        }

        topGradient.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        searchButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.top.equalTo(view.safeAreaLayoutGuide).offset(8)
            make.width.height.equalTo(36)
        }

        closeButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalTo(searchButton)
            make.width.height.equalTo(36)
        }

        muteButton.snp.makeConstraints { make in
            make.trailing.equalTo(closeButton.snp.leading).offset(-4)
            make.centerY.equalTo(searchButton)
            make.width.height.equalTo(36)
        }

        segmentStack.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(searchButton)
            make.leading.greaterThanOrEqualTo(searchButton.snp.trailing).offset(12)
            make.trailing.lessThanOrEqualTo(muteButton.snp.leading).offset(-8)
        }

        updateMuteButton()
        updateSegmentAppearance()
    }

    private func makeSegmentButton(channel: VideoChannel, index: Int) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(channel.rawValue, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.titleLabel?.layer.shadowColor = UIColor.black.cgColor
        button.titleLabel?.layer.shadowOpacity = 0.45
        button.titleLabel?.layer.shadowRadius = 3
        button.titleLabel?.layer.shadowOffset = CGSize(width: 0, height: 1)
        button.tag = index
        button.addTarget(self, action: #selector(handleSegmentTap(_:)), for: .touchUpInside)
        return button
    }

    private func updateMuteButton() {
        let name = pool.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill"
        muteButton.setImage(UIImage(systemName: name,
                                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)),
                            for: .normal)
        muteButton.accessibilityLabel = pool.isMuted ? "取消静音" : "静音"
    }

    private func setupChannels() {
        channels = VideoChannel.allCases.map { channel in
            let child = FeedChannelViewController(channel: channel,
                                                  repository: repository,
                                                  pool: pool,
                                                  initialVideo: channel == .recommended ? initialVideo : nil)
            child.onComment = { [weak self] video in
                self?.presentComments(for: video)
            }
            child.onShare = { [weak self] video, source in
                self?.presentShare(for: video, source: source)
            }
            child.onOpenLive = { [weak self] video in
                self?.presentLiveRoom(for: video)
            }
            child.onTapAd = { [weak self] video in
                self?.presentAdAlert(for: video)
            }
            return child
        }

        for (index, child) in channels.enumerated() {
            addChild(child)
            containerView.addSubview(child.view)
            child.view.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            child.didMove(toParent: self)
            child.view.isHidden = index != currentIndex
        }

        if channels.indices.contains(currentIndex) {
            containerView.bringSubviewToFront(channels[currentIndex].view)
        }
    }

    private func updateSegmentAppearance() {
        for (index, view) in segmentStack.arrangedSubviews.enumerated() {
            guard let button = view as? UIButton else { continue }
            let selected = index == currentIndex
            button.setTitleColor(selected ? .white : UIColor.white.withAlphaComponent(0.6), for: .normal)
            button.transform = selected ? .identity : CGAffineTransform(scaleX: 0.94, y: 0.94)
        }
    }

    private func selectChannel(at index: Int) {
        guard channels.indices.contains(index) else { return }

        if index == currentIndex {
            updateSegmentAppearance()
            return
        }

        let previous = currentIndex
        channels[previous].setActive(false)
        currentIndex = index

        channels[previous].view.isHidden = true
        channels[index].view.isHidden = false
        containerView.bringSubviewToFront(channels[index].view)

        updateSegmentAppearance()

        if isActive {
            channels[currentIndex].setActive(true, replay: true)
        }
    }

    // MARK: - 弹层

    private func presentComments(for video: VideoModel) {
        guard presentedViewController == nil else { return }

        pauseForOverlay()

        let sheet = CommentSheetViewController(video: video)
        sheet.onDismiss = { [weak self] in
            self?.resumeAfterOverlay()
        }

        if let presentation = sheet.sheetPresentationController {
            presentation.detents = [.medium(), .large()]
            presentation.prefersGrabberVisible = true
            presentation.preferredCornerRadius = 20
        }

        present(sheet, animated: true)
    }

    private func presentShare(for video: VideoModel, source: UIView) {
        guard presentedViewController == nil else { return }

        pauseForOverlay()

        let text = "\(video.authorName)\n\(video.desc)\n\(video.url)"
        let controller = UIActivityViewController(activityItems: [text],
                                                  applicationActivities: nil)
        controller.completionWithItemsHandler = { [weak self] _, _, _, _ in
            self?.resumeAfterOverlay()
        }

        if let popover = controller.popoverPresentationController {
            popover.sourceView = source
            popover.sourceRect = source.bounds
            popover.permittedArrowDirections = [.down, .up]
        }

        present(controller, animated: true)
    }

    private func pauseForOverlay() {
        guard !channels.isEmpty else { return }
        channels[currentIndex].pausePlayback()
        pool.pauseAll()
    }

    /// 直播卡片：进直播页（这里只有一个「直播页面」占位文案）。
    private func presentLiveRoom(for video: VideoModel) {
        guard presentedViewController == nil else { return }

        pauseForOverlay()

        let room = LiveRoomViewController(video: video)
        room.modalPresentationStyle = .fullScreen
        room.onDismiss = { [weak self] in
            self?.resumeAfterOverlay()
        }
        present(room, animated: true)
    }

    /// 广告卡片：按需求只弹提示。
    private func presentAdAlert(for video: VideoModel) {
        guard presentedViewController == nil else { return }

        pauseForOverlay()

        let alert = UIAlertController(title: "广告",
                                      message: video.desc,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "知道了", style: .default) { [weak self] _ in
            self?.resumeAfterOverlay()
        })
        present(alert, animated: true)
    }

    private func resumeAfterOverlay() {
        guard isActive, !isInterrupted else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self, self.isActive, !self.isInterrupted else { return }
            self.channels[self.currentIndex].resumePlayback()
        }
    }

    // MARK: - 生命周期

    private func registerNotifications() {
        let center = NotificationCenter.default

        observers.append(center.addObserver(forName: UIApplication.didEnterBackgroundNotification,
                                           object: nil,
                                           queue: .main) { [weak self] _ in
            self?.pauseForInterruption()
        })

        observers.append(center.addObserver(forName: UIApplication.willEnterForegroundNotification,
                                           object: nil,
                                           queue: .main) { [weak self] _ in
            self?.resumeAfterInterruption()
        })

        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification,
                                           object: nil,
                                           queue: .main) { [weak self] note in
            guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }

            switch type {
            case .began:
                self?.pauseForInterruption()
            case .ended:
                self?.resumeAfterInterruption()
            @unknown default:
                break
            }
        })
    }

    private func pauseForInterruption() {
        isInterrupted = true
        guard !channels.isEmpty else { return }
        channels[currentIndex].pausePlayback()
        pool.pauseAll()
    }

    private func resumeAfterInterruption() {
        isInterrupted = false
        guard isActive, !channels.isEmpty, presentedViewController == nil else { return }
        channels[currentIndex].resumePlayback()
    }

    // MARK: - 动作

    @objc private func handleSegmentTap(_ sender: UIButton) {
        selectChannel(at: sender.tag)
    }

    @objc private func handleSearch() {
        let alert = UIAlertController(title: "搜索",
                                      message: "这里可以接入搜索页。",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "知道了", style: .default))
        present(alert, animated: true)
    }

    @objc private func handleMute() {
        pool.setMuted(!pool.isMuted)
        updateMuteButton()
    }

    @objc private func handleClose() {
        if presentingViewController != nil {
            dismiss(animated: true)
        } else {
            navigationController?.popViewController(animated: true)
        }
    }
}

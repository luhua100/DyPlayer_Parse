//
//  VideoPlayerEntry.swift
//  MVVM_Local
//
//  对应 Flutter 文章 5.1：一个 url 对应一个播放单元，四态状态机。
//  iOS 用 AVPlayer + KVO；对外只暴露 Combine Subject，UI 订阅局部刷新。
//

import AVFoundation
import Combine
import Foundation

enum VideoLoadStatus: Equatable {
    case idle        // 已创建未加载
    case loading     // 初始化 / 缓冲
    case ready       // 可以渲染首帧
    case failed      // 失败，可重试
}

final class VideoPlayerEntry {
    let url: URL

    private(set) var status: VideoLoadStatus = .idle
    private(set) var error: Error?
    private(set) var isDisposed = false
    private(set) var isMuted: Bool

    /// 只读给 UI 绑定 AVPlayerLayer，写操作一律走下面的方法。
    private(set) var player: AVPlayer?

    /// UI 订阅这两个 Subject，不需要在播放回调里刷新整屏。
    let statusSubject = CurrentValueSubject<VideoLoadStatus, Never>(.idle)
    let playingSubject = CurrentValueSubject<Bool, Never>(false)

    private var currentItem: AVPlayerItem?
    private var statusObservation: NSKeyValueObservation?
    private var timeControlObservation: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?
    private var timeoutWorkItem: DispatchWorkItem?
    private var wantsPlay = false

    init(url: URL, muted: Bool = true) {
        self.url = url
        self.isMuted = muted
    }

    deinit {
        releasePlayer()
    }

    var isPlaying: Bool {
        player?.timeControlStatus == .playing
    }

    /// 已就绪但在等缓冲：这时显示 loading，而不是暂停图标。
    var isWaiting: Bool {
        player?.timeControlStatus == .waitingToPlayAtSpecifiedRate
    }

    var errorText: String {
        if let error { return error.localizedDescription }
        return "视频加载失败"
    }

    /// 幂等：重复调用安全；失败后再调用即为重试。
    func ensureInitialized() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.ensureInitialized() }
            return
        }
        guard !isDisposed else { return }
        guard status != .ready, status != .loading else { return }

        if status == .failed {
            releasePlayer()
            error = nil
        }

        setStatus(.loading)

        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.isMuted = isMuted
        player.automaticallyWaitsToMinimizeStalling = true
        self.currentItem = item
        self.player = player

        observe(item: item, player: player)
        scheduleTimeout(for: item)
    }

    func play() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.play() }
            return
        }
        guard !isDisposed, status == .ready, let player else { return }
        wantsPlay = true
        player.play()
    }

    func pause() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.pause() }
            return
        }
        wantsPlay = false
        player?.pause()
    }

    /// 回到开头播放：切屏复用同一个播放器时使用。
    func replay() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.replay() }
            return
        }
        guard !isDisposed, status == .ready, let player else { return }
        wantsPlay = true
        player.seek(to: .zero,
                    toleranceBefore: .zero,
                    toleranceAfter: .zero) { [weak self] _ in
            guard let self else { return }
            DispatchQueue.main.async {
                guard !self.isDisposed, self.wantsPlay else { return }
                self.player?.play()
            }
        }
    }

    func setMuted(_ muted: Bool) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.setMuted(muted) }
            return
        }
        isMuted = muted
        player?.isMuted = muted
    }

    func dispose() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.dispose() }
            return
        }
        guard !isDisposed else { return }
        isDisposed = true
        wantsPlay = false
        releasePlayer()
        status = .idle
        statusSubject.send(.idle)
        playingSubject.send(false)
    }

    // MARK: - 监听

    private func observe(item: AVPlayerItem, player: AVPlayer) {
        statusObservation = item.observe(\.status, options: [.new, .initial]) { [weak self, weak item] _, _ in
            guard let self, let item else { return }
            DispatchQueue.main.async {
                guard !self.isDisposed, self.currentItem === item else { return }
                switch item.status {
                case .readyToPlay:
                    guard self.status == .loading else { return }
                    self.timeoutWorkItem?.cancel()
                    self.error = nil
                    self.setStatus(.ready)
                case .failed:
                    self.fail(item.error ?? NSError(domain: "AVPlayerItem",
                                                    code: -1,
                                                    userInfo: [NSLocalizedDescriptionKey: "视频加载失败"]),
                              item: item)
                case .unknown:
                    break
                @unknown default:
                    break
                }
            }
        }

        timeControlObservation = player.observe(\.timeControlStatus, options: [.new, .initial]) { [weak self, weak player] _, _ in
            guard let self, let player else { return }
            DispatchQueue.main.async {
                guard !self.isDisposed, self.player === player else { return }
                self.playingSubject.send(player.timeControlStatus == .playing)
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self, weak item] _ in
            guard let self, let item, !self.isDisposed, self.currentItem === item else { return }
            self.handlePlaybackEnd()
        }
    }

    private func scheduleTimeout(for item: AVPlayerItem) {
        timeoutWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self, weak item] in
            guard let self, let item,
                  !self.isDisposed,
                  self.currentItem === item,
                  self.status == .loading else { return }
            self.fail(NSError(domain: "VideoPlayerEntry",
                              code: -1001,
                              userInfo: [NSLocalizedDescriptionKey: "视频加载超时"]),
                      item: item)
        }
        timeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 20, execute: workItem)
    }

    private func handlePlaybackEnd() {
        guard wantsPlay, let player else { return }
        player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            guard let self else { return }
            DispatchQueue.main.async {
                guard !self.isDisposed, self.wantsPlay else { return }
                self.player?.play()
            }
        }
    }

    private func fail(_ error: Error, item: AVPlayerItem) {
        guard currentItem === item else { return }
        self.error = error
        releasePlayer()
        setStatus(.failed)
    }

    private func setStatus(_ status: VideoLoadStatus) {
        guard self.status != status else { return }
        self.status = status
        statusSubject.send(status)
    }

    private func releasePlayer() {
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil

        statusObservation?.invalidate()
        statusObservation = nil
        timeControlObservation?.invalidate()
        timeControlObservation = nil

        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }

        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        currentItem = nil
    }
}

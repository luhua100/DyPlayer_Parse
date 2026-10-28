//
//  VideoProgressBar.swift
//  MVVM_Local
//
//  对应 Flutter 文章第七节：进度条自己观察播放器，只刷新这一小块，
//  不要让播放回调去刷新整个短视频 Cell。
//  轨道、填充、手势都懒加载，`init` 里只加视图 + 约束。
//

import AVFoundation
import SnapKit
import UIKit

final class VideoProgressBar: UIView {
    private lazy var trackView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.white.withAlphaComponent(0.25)
        view.isUserInteractionEnabled = false
        return view
    }()

    private lazy var fillView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.isUserInteractionEnabled = false
        return view
    }()

    private lazy var panGesture: UIPanGestureRecognizer = {
        let gesture = UIPanGestureRecognizer()
        gesture.addTarget(self, action: #selector(handlePan(_:)))
        gesture.delegate = self
        return gesture
    }()

    private var timeObserver: Any?
    private var progress: CGFloat = 0
    private var dragStartProgress: CGFloat = 0
    private var isDragging = false

    private var trackHeightConstraint: Constraint?
    private var fillHeightConstraint: Constraint?
    private var fillWidthConstraint: Constraint?

    private let idleHeight: CGFloat = 1.5
    private let activeHeight: CGFloat = 3

    var player: AVPlayer? {
        didSet {
            if let timeObserver, let oldValue {
                oldValue.removeTimeObserver(timeObserver)
            }
            timeObserver = nil
            isDragging = false
            progress = 0
            setNeedsLayout()

            guard let player else { return }

            timeObserver = player.addPeriodicTimeObserver(
                forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
                queue: .main
            ) { [weak self, weak player] time in
                guard let self, let player, !self.isDragging else { return }
                let duration = player.currentItem?.duration.seconds ?? 0
                guard duration.isFinite, duration > 0, time.seconds.isFinite else { return }
                self.progress = CGFloat(max(0, min(1, time.seconds / duration)))
                self.setNeedsLayout()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = true

        addSubview(trackView)
        addSubview(fillView)
        addGestureRecognizer(panGesture)

        trackView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
            trackHeightConstraint = make.height.equalTo(idleHeight).constraint
        }

        fillView.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
            fillHeightConstraint = make.height.equalTo(idleHeight).constraint
            fillWidthConstraint = make.width.equalTo(0).constraint
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    convenience init() {
        self.init(frame: .zero)
    }

    deinit {
        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
        }
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
        let velocity = pan.velocity(in: self)
        return abs(velocity.x) > abs(velocity.y)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let height = isDragging ? activeHeight : idleHeight
        trackHeightConstraint?.update(offset: height)
        fillHeightConstraint?.update(offset: height)
        fillWidthConstraint?.update(offset: bounds.width * progress)

        trackView.layer.cornerRadius = height / 2
        fillView.layer.cornerRadius = height / 2
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let player, bounds.width > 0 else { return }

        switch gesture.state {
        case .began:
            let duration = player.currentItem?.duration.seconds ?? 0
            guard duration.isFinite, duration > 0 else { return }
            let current = player.currentTime().seconds
            dragStartProgress = CGFloat(max(0, min(1, current / duration)))
            progress = dragStartProgress
            isDragging = true
            setNeedsLayout()

        case .changed:
            guard isDragging else { return }
            let delta = gesture.translation(in: self).x / bounds.width
            progress = max(0, min(1, dragStartProgress + delta))
            setNeedsLayout()

        case .ended, .cancelled, .failed:
            guard isDragging else { return }
            let duration = player.currentItem?.duration.seconds ?? 0
            if duration.isFinite, duration > 0 {
                let target = CMTime(seconds: Double(progress) * duration, preferredTimescale: 600)
                player.seek(to: target,
                            toleranceBefore: .zero,
                            toleranceAfter: .zero)
            }
            isDragging = false
            setNeedsLayout()

        default:
            break
        }
    }
}

extension VideoProgressBar: UIGestureRecognizerDelegate {}

//
//  LiveRoomViewController.swift
//  MVVM_Local
//
//  直播页占位：按需求这里只放一句「直播页面」文案。
//  从视频列表进来是 push，从信息流进来是 present，两种返回都支持。
//

import SnapKit
import UIKit

final class LiveRoomViewController: UIViewController {
    private let video: VideoModel

    private lazy var liveBadge = LiveBadgeView()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "直播页面"
        label.font = .systemFont(ofSize: 26, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 2
        return label
    }()

    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "\(video.authorName) · \(formatCount(video.viewerCount)) 人在看"
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.textColor = UIColor.white.withAlphaComponent(0.7)
        label.textAlignment = .center
        label.numberOfLines = 2
        return label
    }()

    private lazy var closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "xmark",
                                withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)),
                        for: .normal)
        button.tintColor = .white
        button.addTarget(self, action: #selector(handleClose), for: .touchUpInside)
        return button
    }()

    /// 关闭后回调，播放页用它恢复播放。
    var onDismiss: (() -> Void)?

    init(video: VideoModel) {
        self.video = video
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        liveBadge.startAnimating()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        liveBadge.stopAnimating()

        if isBeingDismissed
            || navigationController?.isBeingDismissed == true
            || isMovingFromParent {
            onDismiss?()
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    private func setup() {
        view.backgroundColor = .black
        title = nil

        [liveBadge, titleLabel, subtitleLabel, closeButton].forEach(view.addSubview)

        closeButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.top.equalTo(view.safeAreaLayoutGuide).offset(8)
            make.width.height.equalTo(36)
        }

        liveBadge.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(titleLabel.snp.top).offset(-16)
        }

        titleLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(32)
        }

        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(32)
        }
    }

    @objc private func handleClose() {
        if presentingViewController != nil {
            dismiss(animated: true)
        } else {
            navigationController?.popViewController(animated: true)
        }
    }
}

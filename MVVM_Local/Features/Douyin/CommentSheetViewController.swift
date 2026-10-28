//
//  CommentSheetViewController.swift
//  MVVM_Local
//
//  评论面板：与短视频播放解耦，打开时暂停，关闭后恢复。
//

import SnapKit
import UIKit

final class CommentSheetViewController: UIViewController {
    fileprivate struct Row {
        let name: String
        let text: String
        let likes: Int
        let isAuthor: Bool
    }

    private let video: VideoModel
    private let rows: [Row]

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "\(formatCount(video.commentCount)) 条评论"
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()

    private lazy var closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "xmark",
                                withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)),
                        for: .normal)
        button.tintColor = UIColor.white.withAlphaComponent(0.8)
        button.addTarget(self, action: #selector(handleClose), for: .touchUpInside)
        return button
    }()

    private lazy var separator: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        return view
    }()

    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 72
        tableView.keyboardDismissMode = .onDrag
        tableView.register(CommentCell.self, forCellReuseIdentifier: CommentCell.reuseIdentifier)
        return tableView
    }()

    var onDismiss: (() -> Void)?

    init(video: VideoModel) {
        self.video = video
        self.rows = Self.makeRows(for: video)
        super.init(nibName: nil, bundle: nil)
        overrideUserInterfaceStyle = .dark
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed || navigationController?.isBeingDismissed == true {
            onDismiss?()
        }
    }

    private func setup() {
        view.backgroundColor = UIColor(white: 0.11, alpha: 1)

        [titleLabel, closeButton, separator, tableView].forEach(view.addSubview)

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(16)
            make.centerX.equalToSuperview()
        }

        closeButton.snp.makeConstraints { make in
            make.centerY.equalTo(titleLabel)
            make.trailing.equalToSuperview().offset(-16)
            make.width.height.equalTo(32)
        }

        separator.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(14)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(0.5)
        }

        tableView.snp.makeConstraints { make in
            make.top.equalTo(separator.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide)
        }
    }

    @objc private func handleClose() {
        dismiss(animated: true)
    }

    private static func makeRows(for video: VideoModel) -> [Row] {
        let texts = [
            "这个运镜太顺了，反复看了三遍。",
            "求 BGM 名字！",
            "已关注，期待下一条。",
            "画面质感和节奏都很舒服。",
            "这里的转场怎么做的？",
            "刷到这里停不下来了。",
            "同款机位有人出教程吗？",
            "我先点赞为敬。"
        ]
        let count = min(max(video.commentCount % 5 + 4, 5), 12)

        return (0..<count).map { index in
            Row(name: "@用户\(video.id.suffix(3))\(index)",
                text: texts[index % texts.count],
                likes: (index * 37) % 260,
                isAuthor: index == 0)
        }
    }
}

extension CommentSheetViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: CommentCell.reuseIdentifier,
                                                 for: indexPath)
        (cell as? CommentCell)?.configure(row: rows[indexPath.row])
        return cell
    }
}

extension CommentSheetViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

private final class CommentCell: UITableViewCell {
    static let reuseIdentifier = "CommentCell"

    private lazy var avatarLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.clipsToBounds = true
        label.layer.cornerRadius = 16
        return label
    }()

    private lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = UIColor.white.withAlphaComponent(0.55)
        return label
    }()

    private lazy var contentLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .white
        label.numberOfLines = 0
        return label
    }()

    private lazy var authorTag: UILabel = {
        let label = UILabel()
        label.text = "作者"
        label.font = .systemFont(ofSize: 10, weight: .semibold)
        label.textColor = UIColor(red: 1, green: 0.17, blue: 0.33, alpha: 1)
        return label
    }()

    private lazy var likeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11)
        label.textColor = UIColor.white.withAlphaComponent(0.45)
        label.textAlignment = .center
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setup() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        [avatarLabel, nameLabel, authorTag, contentLabel, likeLabel].forEach(contentView.addSubview)

        avatarLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.top.equalToSuperview().offset(12)
            make.width.height.equalTo(32)
        }

        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatarLabel.snp.trailing).offset(10)
            make.top.equalTo(avatarLabel)
            make.trailing.lessThanOrEqualTo(likeLabel.snp.leading).offset(-10)
        }

        authorTag.snp.makeConstraints { make in
            make.leading.equalTo(nameLabel.snp.trailing).offset(6)
            make.centerY.equalTo(nameLabel)
        }

        likeLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.top.equalTo(nameLabel)
            make.width.equalTo(44)
        }

        contentLabel.snp.makeConstraints { make in
            make.leading.equalTo(nameLabel)
            make.top.equalTo(nameLabel.snp.bottom).offset(4)
            make.trailing.lessThanOrEqualTo(likeLabel.snp.leading).offset(-10)
            make.bottom.equalToSuperview().offset(-12)
        }
    }

    func configure(row: CommentSheetViewController.Row) {
        apply(name: row.name, text: row.text, likes: row.likes, isAuthor: row.isAuthor)
    }

    private func apply(name: String, text: String, likes: Int, isAuthor: Bool) {
        avatarLabel.text = PlaceholderPalette.initial(for: name)
        avatarLabel.backgroundColor = PlaceholderPalette.color(for: name)
        nameLabel.text = name
        authorTag.isHidden = !isAuthor
        contentLabel.text = text
        likeLabel.text = likes == 0 ? "♡" : "♡ \(formatCount(likes))"
    }
}

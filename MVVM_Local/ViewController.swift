//
//  ViewController.swift
//  MVVM_Local
//
//  根控制器：保留原有 MVVM 示例入口，同时新增 DouyinPlayer 入口。
//  UI 统一用懒加载创建，`viewDidLoad` 里只负责加视图和布局。
//

import SnapKit
import UIKit

final class ViewController: UIViewController {
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "选择示例"
        label.font = .systemFont(ofSize: 30, weight: .bold)
        label.textColor = .label
        label.textAlignment = .center
        return label
    }()

    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "同一个工程里的两种写法"
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        return label
    }()

    private lazy var buttonStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [
            makeButton(title: "MVVM",
                       subtitle: "Alamofire + Codable + Combine 用户列表",
                       color: .systemBlue,
                       action: #selector(openMVVM)),
            makeButton(title: "DouyinPlayer",
                       subtitle: "视频列表 → 竖屏播放",
                       color: UIColor(red: 0.98, green: 0.12, blue: 0.30, alpha: 1),
                       action: #selector(openDouyin))
        ])
        stack.axis = .vertical
        stack.spacing = 14
        return stack
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "iOS 示例"
        view.backgroundColor = .systemBackground
        setupLayout()
    }

    private func setupLayout() {
        [titleLabel, subtitleLabel, buttonStack].forEach(view.addSubview)

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(56)
            make.leading.trailing.equalToSuperview().inset(24)
        }

        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
            make.leading.trailing.equalTo(titleLabel)
        }

        buttonStack.snp.makeConstraints { make in
            make.top.equalTo(subtitleLabel.snp.bottom).offset(32)
            make.leading.trailing.equalToSuperview().inset(24)
        }
    }

    private func makeButton(title: String,
                            subtitle: String,
                            color: UIColor,
                            action: Selector) -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.subtitle = subtitle
        configuration.baseBackgroundColor = color
        configuration.baseForegroundColor = .white
        configuration.cornerStyle = .large
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 18, bottom: 14, trailing: 18)
        configuration.titleAlignment = .leading

        let button = UIButton(configuration: configuration)
        button.contentHorizontalAlignment = .leading
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        button.addTarget(self, action: action, for: .touchUpInside)
        button.snp.makeConstraints { make in
            make.height.equalTo(72)
        }
        return button
    }

    @objc private func openMVVM() {
        navigationController?.pushViewController(UserListViewController(), animated: true)
    }

    @objc private func openDouyin() {
        let list = VideoListViewController()
        if let navigationController {
            navigationController.pushViewController(list, animated: true)
        } else {
            let navigation = UINavigationController(rootViewController: list)
            navigation.modalPresentationStyle = .fullScreen
            present(navigation, animated: true)
        }
    }
}

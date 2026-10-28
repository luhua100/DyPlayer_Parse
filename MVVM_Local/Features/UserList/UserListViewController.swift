//
//  UserListViewController.swift
//  MVVM_Local
//
//  对应博客 4.4 / 4.6：Controller 里不出现 AF.，也不出现 JSONDecoder。
//  它只做三件事：发动作、订阅、刷界面。
//  UI 全部懒加载，`setupUI()` 里只加视图 + 约束。
//

import Combine
import SnapKit
import UIKit

final class UserListViewController: UIViewController {
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.rowHeight = 56

        let refresh = UIRefreshControl()
        refresh.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        tableView.refreshControl = refresh
        return tableView
    }()

    private lazy var spinner: UIActivityIndicatorView = {
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.hidesWhenStopped = true
        return spinner
    }()

    private lazy var headerContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        return view
    }()

    private lazy var footerContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        return view
    }()

    private lazy var footerLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = .preferredFont(forTextStyle: .footnote)
        label.textColor = .secondaryLabel
        label.text = "上拉加载更多"
        return label
    }()

    private lazy var captionLabel: UILabel = {
        let label = UILabel()
        label.text = "解析库（只影响解码这一步）"
        label.font = .preferredFont(forTextStyle: .footnote)
        label.textColor = .secondaryLabel
        return label
    }()

    private lazy var headerStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [captionLabel, parserControl])
        stack.axis = .vertical
        stack.spacing = 8
        return stack
    }()

    private lazy var parserControl: UISegmentedControl = {
        let control = UISegmentedControl(items: UserPageParserStyle.allCases.map(\.title))
        control.selectedSegmentIndex = UserPageParserStyle.launchDefault.rawValue
        control.addTarget(self, action: #selector(parserChanged), for: .valueChanged)
        return control
    }()

    private var vm: UserListViewModel
    private var cancellables = Set<AnyCancellable>()
    private var rows: [UserViewData] = []      // sink 里 vm.users 还是旧值，必须用闭包参数

    init(viewModel: UserListViewModel = UserListViewModel(parser: UserPageParserStyle.launchDefault.makeParser())) {
        self.vm = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        self.vm = UserListViewModel(parser: UserPageParserStyle.launchDefault.makeParser())
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bind()
        vm.trigger.send(.first)                       // 页面就绪，触发第一次加载
    }

    private func setupUI() {
        title = "用户列表"
        view.backgroundColor = .systemBackground

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "关注 #1",
            style: .plain,
            target: self,
            action: #selector(followFirst)
        )

        headerContainer.addSubview(headerStack)
        footerContainer.addSubview(footerLabel)

        // SnapKit 的相对父视图约束要求视图已经在视图树里，所以先加再约束。
        [headerContainer, footerContainer, tableView, spinner].forEach(view.addSubview)

        headerContainer.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(88)
        }

        headerStack.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalToSuperview().offset(8)
            make.bottom.equalToSuperview().offset(-12)
        }

        footerContainer.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide)
            make.height.equalTo(44)
        }

        footerLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        tableView.snp.makeConstraints { make in
            make.top.equalTo(headerContainer.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(footerContainer.snp.top)
        }

        spinner.snp.makeConstraints { make in
            make.center.equalTo(view)
        }
    }

    private func bind() {
        vm.$users
            .receive(on: DispatchQueue.main)
            .sink { [weak self] users in
                guard let self else { return }
                self.rows = users
                self.tableView.reloadData()
            }
            .store(in: &cancellables)

        vm.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                guard let self else { return }
                if isLoading {
                    self.spinner.startAnimating()
                } else {
                    self.spinner.stopAnimating()
                    self.tableView.refreshControl?.endRefreshing()
                }
                self.tableView.isHidden = isLoading && self.rows.isEmpty
            }
            .store(in: &cancellables)

        vm.$errorMessage
            .compactMap { $0 }                 // nil 直接过滤掉
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.presentError(message)
            }
            .store(in: &cancellables)

        vm.$isLoadingMore
            .combineLatest(vm.$hasMore)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoadingMore, hasMore in
                guard let self else { return }
                if isLoadingMore {
                    self.footerLabel.text = "加载中…"
                } else if hasMore {
                    self.footerLabel.text = "上拉加载更多"
                } else {
                    self.footerLabel.text = "没有更多了"
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - 动作

    @objc private func handleRefresh() {
        vm.trigger.send(.first)
    }

    @objc private func followFirst() {
        guard let first = rows.first else {
            presentError("列表还没有数据")
            return
        }
        follow(userID: first.id)
    }

    @objc private func parserChanged() {
        guard let style = UserPageParserStyle(rawValue: parserControl.selectedSegmentIndex) else {
            return
        }

        cancellables.removeAll()
        rows = []
        tableView.reloadData()
        tableView.refreshControl?.endRefreshing()
        spinner.stopAnimating()

        vm = UserListViewModel(parser: style.makeParser())
        bind()
        vm.trigger.send(.first)
    }

    private func follow(userID: Int) {
        vm.follow(userID: userID)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.presentError(error.localizedDescription)
                }
            } receiveValue: { [weak self] in
                // 成功后刷新列表（文章里写的是 vm.refresh.send(())）
                self?.vm.trigger.send(.first)
            }
            .store(in: &cancellables)
    }

    private func presentError(_ message: String) {
        guard presentedViewController == nil else { return }

        let alert = UIAlertController(title: "加载失败", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "知道了", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension UserListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let item = rows[indexPath.row]
        cell.textLabel?.text = "\(item.name) · \(item.followTitle)"
        cell.accessoryType = .disclosureIndicator
        return cell
    }
}

// MARK: - UITableViewDelegate

extension UserListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell,
                   forRowAt indexPath: IndexPath) {
        // 最后一行出现时加载下一页；不用 scrollViewDidScroll 每帧判断，容易重复触发
        guard indexPath.row == rows.count - 1 else { return }
        vm.trigger.send(.more)
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let user = rows[indexPath.row]
        let alert = UIAlertController(title: user.name,
                                      message: "POST /v1/users/\(user.id)/follow",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "关注", style: .default) { [weak self] _ in
            self?.follow(userID: user.id)
        })
        present(alert, animated: true)
    }
}

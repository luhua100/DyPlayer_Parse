//
//  UserListViewModel.swift
//  MVVM_Local
//
//  对应博客第四、五节：Codable 解码 DTO → ViewData，
//  用 Deferred + Future 把 block 回调桥接成 Combine Publisher，
//  再用 @Published 输出；分页状态机负责 replace / append / 去重 / 失败不推进。
//

import Combine
import Foundation

final class UserListViewModel {
    enum LoadKind { case first, more }

    private struct PageResult {
        let kind: LoadKind
        let page: Int
        let items: [UserViewData]
        let hasMore: Bool
        let error: String?
    }

    // ---- 输出给 Controller 的状态 ----
    @Published private(set) var users: [UserViewData] = []
    @Published private(set) var isLoading = false       // 首屏 / 下拉刷新
    @Published private(set) var isLoadingMore = false   // 上拉加载
    @Published private(set) var hasMore = true
    @Published private(set) var errorMessage: String?

    // ---- 输入：Controller 只负责发动作 ----
    let trigger = PassthroughSubject<LoadKind, Never>()

    private let client: HTTPClient
    private let parser: UserPageParsing
    private var cancellables = Set<AnyCancellable>()
    private var page = 0                                // 已成功加载到第几页

    init(client: HTTPClient = HttpManager.shared,
         parser: UserPageParsing = CodableUserPageParser()) {
        self.client = client
        self.parser = parser
        bindPipeline()
    }

    private func bindPipeline() {
        trigger
            .filter { [weak self] kind in
                guard let self else { return false }
                if self.isLoading || self.isLoadingMore { return false }
                if case .more = kind { return self.hasMore }
                return true
            }
            .handleEvents(receiveOutput: { [weak self] kind in
                guard let self else { return }
                self.errorMessage = nil
                if case .first = kind {
                    self.page = 0                       // 刷新：页码归零
                    self.hasMore = true
                    self.isLoading = true
                } else {
                    self.isLoadingMore = true
                }
            })
            // 关键：同一时刻只允许一个分页请求在飞
            .flatMap(maxPublishers: .max(1)) { [weak self] kind -> AnyPublisher<PageResult, Never> in
                guard let self else {
                    return Empty<PageResult, Never>(completeImmediately: false)
                        .eraseToAnyPublisher()
                }

                let target = self.page + 1
                let currentPage = self.page
                let currentHasMore = self.hasMore

                return self.fetchPage(target)
                    .map { parsed in
                        PageResult(kind: kind,
                                   page: parsed.page,
                                   items: parsed.items,
                                   hasMore: !parsed.isLast,
                                   error: nil)
                    }
                    .catch { error in
                        // 失败不推进页码，也不清空已有列表，便于重试
                        Just(PageResult(kind: kind,
                                        page: currentPage,
                                        items: [],
                                        hasMore: currentHasMore,
                                        error: error.localizedDescription))
                    }
                    .eraseToAnyPublisher()
            }
            .receive(on: DispatchQueue.main)                  // 最终一定回主线程
            .sink { [weak self] result in
                guard let self else { return }
                self.isLoading = false
                self.isLoadingMore = false

                if let error = result.error {
                    self.errorMessage = error
                    return
                }

                self.page = result.page
                self.hasMore = result.hasMore

                if case .first = result.kind {
                    self.users = result.items            // 首屏/刷新：整体替换
                } else {
                    self.append(result.items)            // 加载更多：去重后追加
                }
            }
            .store(in: &cancellables)                          // 不存 = 立刻取消
    }

    /// 按 id 去重：offset 分页在数据增删后可能返回重复项
    private func append(_ new: [UserViewData]) {
        let existing = Set(users.map(\.id))
        users.append(contentsOf: new.filter { !existing.contains($0.id) })
    }

    /// 把 block 回调桥接成 Combine Publisher
    private func fetchPage(_ page: Int) -> AnyPublisher<ParsedUserPage, NetworkError> {
        let client = self.client
        let parser = self.parser

        // Deferred：订阅时才真正发请求；Future：把回调转成 Publisher
        return Deferred {
            Future { promise in
                client.get("/v1/users",
                           params: ["page": page, "pageSize": NetworkConfig.pageSize]) { result in
                    switch result {
                    case .success(let data):
                        // 解码放后台，避免大列表卡住主线程
                        DispatchQueue.global(qos: .userInitiated).async {
                            do {
                                promise(.success(try parser.parsePage(from: data)))
                            } catch let error as NetworkError {
                                promise(.failure(error))
                            } catch {
                                promise(.failure(.decoding(error)))
                            }
                        }
                    case .failure(let error):
                        promise(.failure(error))
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }
}

// MARK: - 写操作：POST / PUT / DELETE 同样包成 Publisher

struct EmptyData: Decodable {}

extension UserListViewModel {
    func follow(userID: Int) -> AnyPublisher<Void, NetworkError> {
        let client = self.client
        return performVoid { completion in
            client.post("/v1/users/\(userID)/follow", params: nil, completion: completion)
        }
    }

    func updateNickname(userID: Int, nickname: String) -> AnyPublisher<Void, NetworkError> {
        let client = self.client
        return performVoid { completion in
            client.put("/v1/users/\(userID)",
                       params: ["nickname": nickname],
                       completion: completion)
        }
    }

    func deleteUser(userID: Int) -> AnyPublisher<Void, NetworkError> {
        let client = self.client
        return performVoid { completion in
            client.delete("/v1/users/\(userID)", params: nil, completion: completion)
        }
    }

    /// 把任意「block 回传 Data」的写请求转成 Void Publisher
    private func performVoid(
        _ send: @escaping (@escaping (Result<Data, NetworkError>) -> Void) -> Void
    ) -> AnyPublisher<Void, NetworkError> {
        Deferred {
            Future<Void, NetworkError> { promise in
                send { result in
                    switch result {
                    case .success(let data):
                        // 204 No Content：后端成功但不返回 body 时直接算成功
                        if data.isEmpty {
                            promise(.success(()))
                            return
                        }
                        DispatchQueue.global(qos: .userInitiated).async {
                            do {
                                let response = try JSON.decoder
                                    .decode(ApiResponse<EmptyData>.self, from: data)
                                guard response.code == 0 else {
                                    promise(.failure(.business(code: response.code,
                                                               message: response.message)))
                                    return
                                }
                                promise(.success(()))
                            } catch {
                                promise(.failure(.decoding(error)))
                            }
                        }
                    case .failure(let error):
                        promise(.failure(error))
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }
}

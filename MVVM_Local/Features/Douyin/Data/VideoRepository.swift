//
//  VideoRepository.swift
//  MVVM_Local
//
//  对应 Flutter 文章第四节：UI 只依赖 Repository。
//  只做一件事：向 VideoFeedAPI 要 Data，再交给 VideoFeedParser（HandyJSON）解析成 VideoModel。
//  视频地址属于每条视频自己的字段，由接口下发，Repository 不再维护 URL 数组。
//  接真实后端时把默认的 BundledVideoFeedAPI（读本地 MockVideos.json）换成 HttpManager 实现即可，
//  UI 不用改。
//

import Foundation

enum VideoChannel: String, CaseIterable {
    case following = "关注"
    case recommended = "推荐"
}

enum VideoRepositoryError: LocalizedError {
    case encoding
    case decoding
    case business(message: String)

    var errorDescription: String? {
        switch self {
        case .encoding:                  return "视频数据组装失败"
        case .decoding:                  return "视频数据解析失败"
        case .business(let message):     return message.isEmpty ? "视频加载失败" : message
        }
    }
}

struct VideoRepository {
    let pageSize: Int

    private let api: VideoFeedAPI
    private let parser = VideoFeedParser()

    /// 本地 JSON 里推荐 6 条、关注 4 条，pageSize 取 4 正好演示「第二页」。
    init(pageSize: Int = 4, api: VideoFeedAPI = BundledVideoFeedAPI()) {
        self.pageSize = pageSize
        self.api = api
    }

    /// page 从 0 开始。salt 用于下拉刷新时换一批内容。
    func fetchFeed(channel: VideoChannel, page: Int, salt: Int) async throws -> [VideoModel] {
        let data = try await api.fetchFeed(channel: channel,
                                           page: page,
                                           salt: salt,
                                           pageSize: pageSize)
        return try parser.parse(data: data)
    }
}

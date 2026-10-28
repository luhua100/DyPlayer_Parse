//
//  VideoFeedAPI.swift
//  MVVM_Local
//
//  视频流接口层：只负责「请求 → 拿到 Data」，解析交给 VideoFeedParser（HandyJSON）。
//  真实项目里这里就是 HttpManager.get("/v1/videos", ...)，Repository 不关心数据从哪来。
//
//  演示实现 BundledVideoFeedAPI：读工程里的本地 JSON（Resources/MockVideos.json，共 10 条），
//  按频道 + 分页切好再回传 Data，链路和真实接口一致（都是 Data → HandyJSON → VideoModel）。
//  接真实后端时换成一个 HttpManager 实现即可，UI 与 Repository 都不用改。
//

import Foundation

protocol VideoFeedAPI {
    func fetchFeed(channel: VideoChannel,
                   page: Int,
                   salt: Int,
                   pageSize: Int) async throws -> Data
}

/// 本地 JSON 假后端：视频地址、封面、作者等字段都在 JSON 里，属于每条视频自己的数据。
struct BundledVideoFeedAPI: VideoFeedAPI {
    private static let fileName = "MockVideos"
    private static let fileExtension = "json"

    func fetchFeed(channel: VideoChannel,
                   page: Int,
                   salt: Int,
                   pageSize: Int) async throws -> Data {
        guard let fileURL = Bundle.main.url(forResource: Self.fileName,
                                            withExtension: Self.fileExtension),
              let raw = try? Data(contentsOf: fileURL) else {
            throw VideoRepositoryError.encoding
        }

        guard let root = try JSONSerialization.jsonObject(with: raw) as? [String: Any],
              let data = root["data"] as? [String: Any],
              let list = data[channel.jsonKey] as? [[String: Any]] else {
            throw VideoRepositoryError.decoding
        }

        // 本地文件没有服务端分页，这里按 page/pageSize 切一份，模拟接口分页。
        let start = max(page, 0) * pageSize
        let end = min(start + pageSize, list.count)
        let slice = start < end ? Array(list[start..<end]) : []
        let hasMore = end < list.count

        let payload: [String: Any] = [
            "code": root["code"] ?? 0,
            "message": root["message"] ?? "ok",
            "data": [
                "page": page,
                "pageSize": pageSize,
                "hasMore": hasMore,
                "list": slice
            ]
        ]

        guard JSONSerialization.isValidJSONObject(payload),
              let output = try? JSONSerialization.data(withJSONObject: payload) else {
            throw VideoRepositoryError.encoding
        }
        return output
    }
}

private extension VideoChannel {
    /// 本地 JSON 里按频道分组，字段名与频道原始值分开，避免中文 key。
    var jsonKey: String {
        switch self {
        case .following:    return "following"
        case .recommended:  return "recommended"
        }
    }
}

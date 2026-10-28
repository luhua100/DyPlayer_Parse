//
//  VideoDTO.swift
//  MVVM_Local
//
//  接口模型层（DTO）——只跟 JSON 打交道，字段全部可选，用来吸收后端的不稳定：
//  数字写成字符串、布尔写成 0/1 或 "true"、字段名带下划线、字段缺失。
//  解析完通过 toModel() 转成领域模型 VideoModel，DTO 不会流出解析层。
//
//  为什么不直接用 VideoModel 反序列化：
//  1. VideoModel 是 UI 契约（强类型 Int/Bool/URL + copyWith），不该为了兼容脏字段改成可选；
//  2. 换解析库（Codable / ObjectMapper）时只重写这一层，UI 与播放逻辑不动；
//  3. 后端加减字段只改 DTO + toModel()，和 UserDTO → UserViewData 是同一套分层思路。
//

import Foundation
import HandyJSON

/// 外层统一壳：{ "code": 0, "message": "ok", "data": { ... } }
final class VideoFeedEnvelopeDTO: HandyJSON {
    var code: Int = -1
    var message: String = ""
    var data: VideoFeedPageDTO?      // 嵌套模型同样要实现 HandyJSON

    required init() {}
}

final class VideoFeedPageDTO: HandyJSON {
    var page: Int = 0
    var pageSize: Int = 0
    var hasMore: Bool = false
    var list: [VideoDTO] = []

    required init() {}
}

final class VideoDTO: HandyJSON {
    var id: String?
    var type: String?            // video / live / ad，缺省按普通视频处理
    var url: String?
    var coverUrl: String?
    var desc: String?
    var authorName: String?
    var authorAvatar: String?
    var musicName: String?
    var likeCount: String?
    var commentCount: Int?
    var shareCount: String?
    var viewerCount: String?     // 直播在线人数
    var aspectRatio: String?
    var liked: Int?
    var followed: String?

    required init() {}

    /// 只有 JSON 字段名和属性名对不上时才需要写映射。
    func mapping(mapper: HelpingMapper) {
        mapper <<< aspectRatio <-- "aspect_ratio"
    }

    /// DTO → 领域模型：类型转换、缺字段兜底都收敛在这里。
    func toModel() -> VideoModel {
        let ratio = Double(aspectRatio ?? "") ?? 9.0 / 16.0

        return VideoModel(id: id ?? "",
                          kind: VideoKind(rawValue: type ?? "video") ?? .video,
                          url: url ?? "",
                          coverUrl: coverUrl ?? "",
                          desc: desc ?? "",
                          authorName: authorName ?? "",
                          authorAvatar: authorAvatar ?? "",
                          musicName: musicName ?? "",
                          likeCount: Int(likeCount ?? "") ?? 0,
                          commentCount: commentCount ?? 0,
                          shareCount: Int(shareCount ?? "") ?? 0,
                          viewerCount: Int(viewerCount ?? "") ?? 0,
                          aspectRatio: ratio > 0 ? ratio : 9.0 / 16.0,
                          liked: (liked ?? 0) == 1,
                          followed: followed == "true" || followed == "1")
    }
}

/// 解析入口：真实接口把 Data 直接丢进来即可，这里用本地假数据也走同一条链路。
struct VideoFeedParser {
    func parse(data: Data) throws -> [VideoModel] {
        guard let jsonString = String(data: data, encoding: .utf8),
              let envelope = VideoFeedEnvelopeDTO.deserialize(from: jsonString) else {
            throw VideoRepositoryError.decoding
        }

        guard envelope.code == 0 else {
            throw VideoRepositoryError.business(message: envelope.message)
        }

        return (envelope.data?.list ?? []).map { $0.toModel() }
    }
}

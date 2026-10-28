//
//  VideoModel.swift
//  MVVM_Local
//
//  对应 Flutter 文章第三节：短视频领域模型（UI / 播放器共用的契约）。
//  上游是 VideoDTO（HandyJSON）：DTO 只负责接 JSON 的脏类型，这里只保留
//  UI 需要的强类型字段、URL 转换和 copyWith，解析细节不泄漏到界面。
//

import Foundation

/// 信息流里的三种卡片：普通短视频、直播、广告封面。
enum VideoKind: String {
    case video      // 普通短视频，走播放器
    case live       // 直播，展示封面 + 直播中动画，点击进直播页
    case ad         // 广告封面，点击弹提示
}

struct VideoModel: Identifiable, Equatable {
    let id: String
    let kind: VideoKind
    let url: String
    let coverUrl: String
    let desc: String
    let authorName: String
    let authorAvatar: String
    let musicName: String
    let likeCount: Int
    let commentCount: Int
    let shareCount: Int
    let viewerCount: Int         // 直播在线人数，非直播为 0
    let aspectRatio: Double      // 素材固有属性，不参与 copyWith
    let liked: Bool
    let followed: Bool

    var streamURL: URL? { URL(string: url) }
    var coverURL: URL? { URL(string: coverUrl) }
    var avatarURL: URL? { URL(string: authorAvatar) }

    /// 只有普通短视频需要播放器；直播、广告都不占用播放器池。
    var isPlayable: Bool { kind == .video }

    /// 点赞/关注只改交互字段，其余原样透传。
    func copyWith(likeCount: Int? = nil,
                  commentCount: Int? = nil,
                  shareCount: Int? = nil,
                  liked: Bool? = nil,
                  followed: Bool? = nil) -> VideoModel {
        VideoModel(id: id,
                   kind: kind,
                   url: url,
                   coverUrl: coverUrl,
                   desc: desc,
                   authorName: authorName,
                   authorAvatar: authorAvatar,
                   musicName: musicName,
                   likeCount: likeCount ?? self.likeCount,
                   commentCount: commentCount ?? self.commentCount,
                   shareCount: shareCount ?? self.shareCount,
                   viewerCount: viewerCount,
                   aspectRatio: aspectRatio,
                   liked: liked ?? self.liked,
                   followed: followed ?? self.followed)
    }

    init(id: String,
         kind: VideoKind,
         url: String,
         coverUrl: String,
         desc: String,
         authorName: String,
         authorAvatar: String,
         musicName: String,
         likeCount: Int,
         commentCount: Int,
         shareCount: Int,
         viewerCount: Int = 0,
         aspectRatio: Double,
         liked: Bool,
         followed: Bool) {
        self.id = id
        self.kind = kind
        self.url = url
        self.coverUrl = coverUrl
        self.desc = desc
        self.authorName = authorName
        self.authorAvatar = authorAvatar
        self.musicName = musicName
        self.likeCount = likeCount
        self.commentCount = commentCount
        self.shareCount = shareCount
        self.viewerCount = viewerCount
        self.aspectRatio = aspectRatio
        self.liked = liked
        self.followed = followed
    }

    // 列表按 id 去重 / diff
    static func == (lhs: VideoModel, rhs: VideoModel) -> Bool { lhs.id == rhs.id }
}

/// 12345 -> 1.2w
func formatCount(_ count: Int) -> String {
    let safe = max(count, 0)
    if safe < 10_000 { return "\(safe)" }
    return String(format: "%.1fw", Double(safe) / 10_000)
}

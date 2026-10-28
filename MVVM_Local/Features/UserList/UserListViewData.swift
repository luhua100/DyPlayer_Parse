//
//  UserViewData.swift
//  MVVM_Local
//
//  对应博客 4.1：界面要什么就长什么样，别把 DTO 直接丢给 Cell。
//  昵称为空怎么显示、头像字符串怎么变 URL、关注状态怎么转文案，都收在这里。
//

import Foundation

struct UserViewData: Identifiable, Equatable {
    let id: Int
    let name: String
    let avatarURL: URL?
    let followTitle: String

    init<T: UserRaw>(raw: T) {
        self.id = raw.id
        self.name = raw.nickname.isEmpty ? "未命名用户" : raw.nickname   // 兜底文案
        self.avatarURL = raw.avatar.flatMap(URL.init(string:))
        self.followTitle = raw.followed ? "已关注" : "关注"
    }
}

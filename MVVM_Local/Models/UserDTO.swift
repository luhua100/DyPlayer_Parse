//
//  UserDTO.swift
//  MVVM_Local
//
//  对应博客 4.1：DTO 字段跟接口一一对应，只负责解码。
//  UserRaw 是解析器无关的最小字段集，换 HandyJSON / ObjectMapper 时映射逻辑不用改。
//

import Foundation

struct UserDTO: Decodable {
    let id: Int
    let nickname: String
    let avatar: String?
    let followed: Bool
    let createdAt: String
}

protocol UserRaw {
    var id: Int { get }
    var nickname: String { get }
    var avatar: String? { get }
    var followed: Bool { get }
}

extension UserDTO: UserRaw {}

//
//  ApiResponse.swift
//  MVVM_Local
//
//  后端统一外壳：code / message / data。
//  对应博客 4.1；分页时把 T 换成 UserPage<UserDTO> 即可。
//

import Foundation

struct ApiResponse<T: Decodable>: Decodable {
    let code: Int
    let message: String
    let data: T?
}

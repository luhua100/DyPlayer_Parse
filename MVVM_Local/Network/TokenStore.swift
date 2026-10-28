//
//  TokenStore.swift
//  MVVM_Local
//
//  网络层只读取 token，不保存任何可变业务状态。
//  真实项目建议换成 Keychain；这里用 UserDefaults 保持示例可运行。
//

import Foundation

final class TokenStore {
    static let shared = TokenStore()

    private let key = "com.mvvm_local.auth_token"
    private let defaults = UserDefaults.standard

    private init() {}

    var token: String? {
        get { defaults.string(forKey: key) }
        set { defaults.set(newValue, forKey: key) }
    }
}

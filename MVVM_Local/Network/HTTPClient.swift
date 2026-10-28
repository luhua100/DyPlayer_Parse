//
//  HTTPClient.swift
//  MVVM_Local
//
//  对应博客第七节：把 ViewModel 用到的网络能力抽成协议，
//  生产默认走 HttpManager.shared，单测时注入假实现即可。
//

import Foundation

protocol HTTPClient {
    func get(_ path: String,
             params: [String: Any]?,
             completion: @escaping (Result<Data, NetworkError>) -> Void)

    func post(_ path: String,
              params: [String: Any]?,
              completion: @escaping (Result<Data, NetworkError>) -> Void)

    func put(_ path: String,
             params: [String: Any]?,
             completion: @escaping (Result<Data, NetworkError>) -> Void)

    func delete(_ path: String,
                params: [String: Any]?,
                completion: @escaping (Result<Data, NetworkError>) -> Void)
}

extension HTTPClient {
    func get(_ path: String,
             completion: @escaping (Result<Data, NetworkError>) -> Void) {
        get(path, params: nil, completion: completion)
    }

    func post(_ path: String,
              completion: @escaping (Result<Data, NetworkError>) -> Void) {
        post(path, params: nil, completion: completion)
    }

    func put(_ path: String,
             completion: @escaping (Result<Data, NetworkError>) -> Void) {
        put(path, params: nil, completion: completion)
    }

    func delete(_ path: String,
                completion: @escaping (Result<Data, NetworkError>) -> Void) {
        delete(path, params: nil, completion: completion)
    }
}

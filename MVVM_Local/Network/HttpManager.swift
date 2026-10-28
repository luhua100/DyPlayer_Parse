//
//  HttpManager.swift
//  MVVM_Local
//
//  对应博客第三节：单例 + 共享 Session + 四个动词收敛到同一个 request，
//  结尾通过 block 回传 Data，网络层不 import 任何业务模型。
//

import Alamofire
import Foundation

enum NetworkConfig {
    /// 本地 Mock 服务地址（见仓库根目录 MockServer/mock_server.py）。
    /// 真机调试时改成 Mac 的局域网 IP，例如 http://192.168.1.10:8090。
    /// 接入真实后端时改成生产域名即可，其余代码不用动。
    static let baseURL = "http://localhost:8090"

    /// 与 ViewModel 分页参数保持同一份常量，避免两处写死。
    static let pageSize = 20
}

final class HttpManager {
    static let shared = HttpManager()

    private init() {}          // 只留 shared，禁止 HttpManager() 到处 new

    private let baseURL = NetworkConfig.baseURL

    // 全 App 共用一个 Session：连接池、超时、Header 都在这层统一
    private let session: Session = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 30
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return Session(configuration: config)
    }()

    private var headers: HTTPHeaders {
        var headers: HTTPHeaders = ["Accept": "application/json"]
        if let token = TokenStore.shared.token, !token.isEmpty {
            headers.add(.authorization(bearerToken: token))
        }
        return headers
    }
}

extension HttpManager {
    // 核心：拼 URL、发请求、把 Data 通过 block 交出去
    private func request(
        _ path: String,
        method: HTTPMethod,
        parameters: [String: Any]?,
        encoding: ParameterEncoding,
        completion: @escaping (Result<Data, NetworkError>) -> Void
    ) {
        guard let url = URL(string: baseURL + path) else {
            completion(.failure(.invalidURL))
            return
        }

        session
            .request(url,
                     method: method,
                     parameters: parameters,
                     encoding: encoding,
                     headers: headers)
            .validate()                                  // 非 2xx 直接进 failure
            .responseData { response in
                // 统一回到主线程，调用方不用再关心线程
                DispatchQueue.main.async {
                    switch response.result {
                    case .success(let data):
                        completion(.success(data))
                    case .failure(let error):
                        completion(.failure(Self.map(error, response: response.response)))
                    }
                }
            }
    }
}

// 四个动词：参数、编码方式固定，业务侧只关心 path
extension HttpManager {
    func get(_ path: String,
             params: [String: Any]? = nil,
             completion: @escaping (Result<Data, NetworkError>) -> Void) {
        request(path,
                method: .get,
                parameters: params,
                encoding: URLEncoding.default,
                completion: completion)
    }

    func post(_ path: String,
              params: [String: Any]? = nil,
              completion: @escaping (Result<Data, NetworkError>) -> Void) {
        request(path,
                method: .post,
                parameters: params,
                encoding: JSONEncoding.default,
                completion: completion)
    }

    func put(_ path: String,
             params: [String: Any]? = nil,
             completion: @escaping (Result<Data, NetworkError>) -> Void) {
        request(path,
                method: .put,
                parameters: params,
                encoding: JSONEncoding.default,
                completion: completion)
    }

    func delete(_ path: String,
                params: [String: Any]? = nil,
                completion: @escaping (Result<Data, NetworkError>) -> Void) {
        request(path,
                method: .delete,
                parameters: params,
                encoding: URLEncoding.default,
                completion: completion)
    }
}

extension HttpManager {
    private static func map(_ error: AFError,
                            response: HTTPURLResponse?) -> NetworkError {
        if let status = response?.statusCode, !(200..<300).contains(status) {
            return .http(status)
        }
        if case .sessionTaskFailed(let underlying) = error,
           let urlError = underlying as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return .noNetwork
            case .timedOut:
                return .timeout
            default:
                return .unknown(urlError)
            }
        }
        return .unknown(error)
    }
}

extension HttpManager: HTTPClient {}

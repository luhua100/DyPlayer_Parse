//
//  NetworkError.swift
//  MVVM_Local
//
//  对应博客 3.1：把 Alamofire / URLSession 的错误收敛成一个业务错误枚举，
//  Controller 只展示 error.localizedDescription，不用判断 AFError。
//

import Foundation

enum NetworkError: Error, LocalizedError {
    case invalidURL
    case noNetwork
    case timeout
    case http(Int)                              // 非 2xx
    case business(code: Int, message: String)   // 后端 code != 0
    case decoding(Error)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:            return "请求地址不合法"
        case .noNetwork:             return "网络不可用，请检查连接"
        case .timeout:               return "请求超时，请稍后重试"
        case .http(let code):        return "服务异常（HTTP \(code)）"
        case .business(_, let msg):  return msg
        case .decoding:              return "数据解析失败"
        case .unknown:               return "未知错误"
        }
    }
}

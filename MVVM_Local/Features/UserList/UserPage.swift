//
//  UserPage.swift
//  MVVM_Local
//
//  对应博客 4.2 与 4.6：解码配置 + 泛型页容器。
//  首屏 replace、加载更多 append 的状态机在 ViewModel 里，与解析库无关。
//

import Foundation

enum JSON {
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase   // created_at → createdAt
        decoder.dateDecodingStrategy = .iso8601               // 日期统一 ISO8601
        return decoder
    }()
}

struct UserPage<T: Decodable>: Decodable {
    let list: [T]
    let page: Int
    let pageSize: Int
    let total: Int?
    let hasMore: Bool?

    // 优先信服务端；没有 hasMore 时用「本页数量 < pageSize」兜底
    var isLast: Bool {
        if let hasMore { return !hasMore }
        return list.count < pageSize
    }
}

/// 三个解析库最终都产出同一种「已转好的页面」，ViewModel 不需要知道用的是哪个库。
struct ParsedUserPage {
    let page: Int
    let items: [UserViewData]
    let isLast: Bool
}

protocol UserPageParsing {
    var name: String { get }
    func parsePage(from data: Data) throws -> ParsedUserPage
}

// MARK: - Codable（文章默认方案）

struct CodableUserPageParser: UserPageParsing {
    let name = "Codable"

    func parsePage(from data: Data) throws -> ParsedUserPage {
        let response: ApiResponse<UserPage<UserDTO>>
        do {
            response = try JSON.decoder.decode(ApiResponse<UserPage<UserDTO>>.self, from: data)
        } catch {
            throw NetworkError.decoding(error)
        }

        guard response.code == 0 else {
            throw NetworkError.business(code: response.code, message: response.message)
        }
        guard let page = response.data else {
            throw NetworkError.business(code: response.code,
                                        message: response.message.isEmpty ? "数据为空" : response.message)
        }

        return ParsedUserPage(
            page: page.page,
            items: page.list.map { UserViewData(raw: $0) },   // DTO → ViewData
            isLast: page.isLast
        )
    }
}

// MARK: - 运行时切换解析库

enum UserPageParserStyle: Int, CaseIterable {
    case codable
    case handyJSON
    case objectMapper

    var title: String {
        switch self {
        case .codable:      return "Codable"
        case .handyJSON:    return "HandyJSON"
        case .objectMapper: return "ObjectMapper"
        }
    }

    func makeParser() -> UserPageParsing {
        switch self {
        case .codable:      return CodableUserPageParser()
        case .handyJSON:    return HandyJSONUserPageParser()
        case .objectMapper: return ObjectMapperUserPageParser()
        }
    }

    /// 调试用：不点界面也能切换解析库，验证三条解码链路。
    /// 例：SIMCTL_CHILD_USER_PAGE_PARSER=1 xcrun simctl launch ...
    static var launchDefault: UserPageParserStyle {
        #if DEBUG
        if let raw = ProcessInfo.processInfo.environment["USER_PAGE_PARSER"],
           let value = Int(raw),
           let style = UserPageParserStyle(rawValue: value) {
            return style
        }
        #endif
        return .codable
    }
}

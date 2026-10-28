//
//  HandyJSONUserPageParser.swift
//  MVVM_Local
//
//  对应博客 4.5：HandyJSON 不支持泛型外壳，所以外壳和页容器都写成具体类。
//  换库只改解码这一步，HttpManager 与 Controller 一行都不动。
//

import Foundation
import HandyJSON

final class UserHandyDTO: HandyJSON, UserRaw {
    var id: Int = 0
    var nickname: String = ""
    var avatar: String?
    var followed: Bool = false
    var createdAt: String?

    required init() {}                 // 协议要求，不能省

    // 只有字段名对不上才需要写；同名可整段删掉
    func mapping(mapper: HelpingMapper) {
        mapper <<< createdAt <-- "created_at"
    }
}

final class UserPageHandyDTO: HandyJSON {
    var list: [UserHandyDTO] = []
    var page: Int = 1
    var pageSize: Int = 20
    var total: Int?
    var hasMore: Bool?

    required init() {}

    var isLast: Bool {
        if let hasMore { return !hasMore }
        return list.count < pageSize
    }
}

final class UserPageEnvelope: HandyJSON {
    var code: Int = -1
    var message: String = ""
    var data: UserPageHandyDTO?      // 嵌套模型同样要实现 HandyJSON

    required init() {}
}

struct HandyJSONUserPageParser: UserPageParsing {
    let name = "HandyJSON"

    func parsePage(from data: Data) throws -> ParsedUserPage {
        guard let jsonString = String(data: data, encoding: .utf8),
              let envelope = UserPageEnvelope.deserialize(from: jsonString) else {
            throw NetworkError.decoding(
                NSError(domain: "HandyJSON",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "响应不是合法 JSON"])
            )
        }

        guard envelope.code == 0 else {
            throw NetworkError.business(code: envelope.code, message: envelope.message)
        }
        guard let page = envelope.data else {
            throw NetworkError.business(code: envelope.code,
                                        message: envelope.message.isEmpty ? "数据为空" : envelope.message)
        }

        return ParsedUserPage(
            page: page.page,
            items: page.list.map { UserViewData(raw: $0) },
            isLast: page.isLast
        )
    }
}

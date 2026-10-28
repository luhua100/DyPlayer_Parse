//
//  ObjectMapperUserPageParser.swift
//  MVVM_Local
//
//  对应博客 4.5：ObjectMapper 走 KVC，模型必须继承 NSObject 并实现 Mappable。
//  注意 `<-` 两边类型不匹配不会报错，字段会保持默认值，排查时先看 mapping 是否漏字段。
//

import Foundation
import ObjectMapper

final class UserObjectDTO: NSObject, Mappable, UserRaw {
    var id: Int = 0
    var nickname: String = ""
    var avatar: String?
    var followed: Bool = false
    var createdAt: String?

    required init?(map: Map) {
        super.init()
    }

    func mapping(map: Map) {
        id        <- map["id"]
        nickname  <- map["nickname"]
        avatar    <- map["avatar"]
        followed  <- map["followed"]
        createdAt <- map["created_at"] // 字段名不一致，就地映射
    }
}

final class UserPageObject: NSObject, Mappable {
    var list: [UserObjectDTO] = []
    var page = 1
    var pageSize = 20
    var total: Int?
    var hasMore: Bool?

    required init?(map: Map) {
        super.init()
    }

    func mapping(map: Map) {
        list     <- map["list"]
        page     <- map["page"]
        pageSize <- map["pageSize"]
        total    <- map["total"]
        hasMore  <- map["hasMore"]
    }

    var isLast: Bool {
        if let hasMore { return !hasMore }
        return list.count < pageSize
    }
}

final class UserPageEnvelopeObject: NSObject, Mappable {
    var code = -1
    var message = ""
    var data: UserPageObject?

    required init?(map: Map) {
        super.init()
    }

    func mapping(map: Map) {
        code    <- map["code"]
        message <- map["message"]
        data    <- map["data"]
    }
}

struct ObjectMapperUserPageParser: UserPageParsing {
    let name = "ObjectMapper"

    func parsePage(from data: Data) throws -> ParsedUserPage {
        guard let jsonString = String(data: data, encoding: .utf8),
              let envelope = Mapper<UserPageEnvelopeObject>().map(JSONString: jsonString) else {
            throw NetworkError.decoding(
                NSError(domain: "ObjectMapper",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "响应无法映射为模型"])
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

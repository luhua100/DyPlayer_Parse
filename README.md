# MVVM_Local

同一个工程里的两个示例，根控制器 `ViewController` 提供两个入口：

- **MVVM**：按博客 [我的 iOS MVVM 习惯写法：Alamofire 单例 + Codable + Combine](http://127.0.0.1:5173/post/ios-alamofire-mvvm-combine) 生成的用户列表。
- **DouyinPlayer**：按博客 [Flutter 短视频播放](http://127.0.0.1:5173/post/flutter-short-video) 的思路改写的 iOS 竖屏信息流，先进入视频列表，点任意一条再进播放页。

界面布局统一使用 **SnapKit**（`snp.makeConstraints`），工程内不再使用 `NSLayoutConstraint`、
`translatesAutoresizingMaskIntoConstraints` 或手写 `frame`；需要动态改尺寸的地方用
SnapKit 的 `Constraint.update(offset:)`（见进度条、视频 Cell 底部安全区）。

所有子视图都按 **懒加载** 写：属性声明处创建并配置，`setup()` / `viewDidLoad()` 里只做
「加视图 + 建约束 + 绑事件」，避免把样式代码堆在初始化流程里。

## 运行截图

| MVVM 用户列表 | 竖屏播放页（关注频道） | 广告卡片 | 直播卡片 |
| --- | --- | --- | --- |
| <img src="https://climby-cn.oss-cn-hangzhou.aliyuncs.com/repository/dyp_c_4.png" width="200" alt="MVVM 用户列表"> | <img src="https://climby-cn.oss-cn-hangzhou.aliyuncs.com/repository/dyp_c_5.png" width="200" alt="竖屏播放页"> | <img src="https://climby-cn.oss-cn-hangzhou.aliyuncs.com/repository/dyp_c_6.png" width="200" alt="广告卡片"> | <img src="https://climby-cn.oss-cn-hangzhou.aliyuncs.com/repository/dyp_c_7.png" width="200" alt="直播卡片"> |

> 直播 / 广告是信息流里的两种特殊卡片：直播卡有「直播中」呼吸动画和「点击进入直播间」胶囊，
> 广告卡有「广告」角标，点击分别进入直播页 / 弹出提示。

## 运行

```bash
# MVVM 示例需要本地 Mock 服务（默认 8090）；DouyinPlayer 不需要
python3 MockServer/mock_server.py

open MVVM_Local.xcworkspace
```

选择 iOS 模拟器运行，在根页面点 **MVVM** 或 **DouyinPlayer**。

> `NetworkConfig.baseURL` 默认是 `http://localhost:8090`（模拟器可直接访问 Mac）。
> 真机调试时改成 Mac 的局域网地址；如果仍用 HTTP，需要在 `Info.plist` 的 ATS 例外里补上该地址
> （或改用 HTTPS / `xxx.local` 主机名），否则会被 App Transport Security 拦截。

## MVVM 示例

Alamofire 单例 + 共享 Session，GET/POST/PUT/DELETE 收敛到同一个请求方法并回传 `Data`；
ViewModel 用 Codable（也可运行时切 HandyJSON / ObjectMapper）解 DTO、转 ViewData；
Combine 的 `Deferred + Future` 桥接回调，`@Published` 输出，Controller 只订阅。

列表首屏加载第 1 页，下拉刷新，滚到底自动加载下一页；
点击单元格或右上角「关注 #1」会调用 `POST /v1/users/{id}/follow` 并刷新。

## DouyinPlayer 示例

入口顺序：根页面 **DouyinPlayer** → 视频列表页（`VideoListViewController`）→ 点任意一条进竖屏播放页。
列表支持下拉刷新、上拉分页、加载失败重试；播放页拿到点选的那条视频后直接定位到它。

播放页首次进入（没有指定视频时）默认停在 **推荐** 频道；频道分段里「关注 / 推荐」可切换，
切到「关注」会重新拉关注流。

竖屏分页信息流：上滑切下一条、循环播放、相邻两屏预加载、播放器池 LRU 复用；
单击暂停/继续、双击点赞、右侧关注/点赞/评论/分享、顶部频道切换与静音开关；
打开评论或分享时暂停，关闭后恢复；进后台、来电等音频中断时自动暂停。

本地演示数据在 `MVVM_Local/Resources/MockVideos.json`，共 **10 条**（推荐 6 条 + 关注 4 条），
每条视频自带 `type` / `url` / `coverUrl` / `aspect_ratio`（直播还有 `viewerCount`），客户端不维护素材数组。`VideoRepository` 默认
`pageSize = 4`，正好能演示「先取 4 条、触底再取 2 条、然后显示没有更多了」。

### 直播 / 广告卡片

`VideoModel.kind` 把信息流分成三种卡片，JSON 里用 `type` 字段区分（缺省按 `video` 处理）：

| kind | 卡片 | 行为 |
| --- | --- | --- |
| `video` | `ShortVideoCell` | 走播放器：上滑切条、循环播放、点赞/评论/分享 |
| `live` | `LiveCardCell` | 封面 +「直播中」呼吸动画 + 在线人数，封面中间浮着「点击进入直播间」胶囊（左侧声浪条动画），点击进 `LiveRoomViewController`（目前只有一个「直播页面」占位文案） |
| `ad` | `AdCardCell` | 封面 +「广告」角标 + 广告语，点击只弹 `UIAlertController` 提示 |

直播、广告都不占用播放器池：`syncPlayback` 只给 `isPlayable` 的条目保留播放器，
视频列表页也按 `kind` 分流点击（直播 → 直播页、广告 → 提示、普通视频 → 播放页）。
演示数据里 `rec_5` / `fol_4` 是直播、`rec_6` 是广告，因为 `pageSize = 4`，推荐流翻到第二页就能看到。

视频数据统一走 **HandyJSON** 解析，分三层：

- `VideoFeedAPI`（`Features/Douyin/Data/VideoFeedAPI.swift`）：只负责拿 `Data`。默认实现
  `BundledVideoFeedAPI` 读工程里的 `MockVideos.json`，按频道 + 分页切好后回传 `Data`；
  接真实后端时换成 `HttpManager.get("/v1/videos", ...)` 即可，Repository 与 UI 都不用动。
- `VideoDTO`（`Models/VideoDTO.swift`）：和 JSON 一一对应，字段全可选，`likeCount` 是字符串、
  `liked` 是 0/1、`followed` 是 `"true"`、`aspect_ratio` 用 `mapping` 映射，脏类型都在这层吸收，
  再 `toModel()` 转成 `VideoModel`。
- `VideoModel`（`Models/VideoModel.swift`）：UI / 播放器共用的强类型契约，负责 `copyWith`
  （点赞、关注只改交互字段）和字符串转 `URL`，DTO 不会流到界面层。

两层模型不是重复：DTO 是接口契约，会随后端变；Model 是界面契约，要稳定。这和 MVVM 示例里的
`UserDTO → UserViewData` 是同一个思路。

| 文件 | Flutter 文章对应内容 |
| --- | --- |
| `Resources/MockVideos.json` | 本地演示数据（10 条，推荐 6 + 关注 4） |
| `Features/Douyin/Models/VideoModel.swift` | 第三节 领域模型与 `copyWith` |
| `Features/Douyin/Models/VideoDTO.swift` | 第三节 容错解析（HandyJSON DTO + 映射 + 归一化） |
| `Features/Douyin/Data/VideoFeedAPI.swift` | 第四节 接口层（读本地 JSON，可替换为 HttpManager） |
| `Features/Douyin/Data/VideoRepository.swift` | 第四节 Repository 隔离（取 Data → HandyJSON 解析） |
| `Features/Douyin/VideoListViewController.swift` | 视频列表页：浏览、分页、点选后进播放页 |
| `Features/Douyin/Player/VideoPlayerEntry.swift` | 5.1 四态状态机（idle/loading/ready/failed）+ 循环/超时 |
| `Features/Douyin/Player/VideoPlayerPool.swift` | 5.2 LRU 播放器池与预加载窗口 |
| `Features/Douyin/UI/ShortVideoCell.swift` | 第六节 视频层 + 信息层 + 操作层拆分 |
| `Features/Douyin/UI/FeedAuxiliaryCells.swift` | 直播卡片 `LiveCardCell`、广告卡片 `AdCardCell` |
| `Features/Douyin/UI/LiveBadgeView.swift` | 「直播中」胶囊 + 圆点呼吸动画（列表 / 信息流 / 直播页共用） |
| `Features/Douyin/UI/LiveEnterButton.swift` | 「点击进入直播间」半透明胶囊 + 三根声浪条跳动动画 |
| `Features/Douyin/LiveRoomViewController.swift` | 直播页占位（只有一个「直播页面」文案） |
| `Features/Douyin/UI/VideoProgressBar.swift` | 第七节 进度条只刷新自己 |
| `Features/Douyin/UI/SideActionComponents.swift` | 第八节 右侧操作栏、关注头像、唱片 |
| `Features/Douyin/FeedChannelViewController.swift` | 第九节 单频道分页、触底加载、首屏重试 |
| `Features/Douyin/DouyinViewController.swift` | 第十节 页面骨架、频道切换、生命周期 |
| `Features/Douyin/CommentSheetViewController.swift` | 评论面板与暂停/恢复 |
| `MVVM_Local/ViewController.swift` | 根入口：MVVM / DouyinPlayer |

关键规则：

1. 只有当前屏的播放器在播，前后各一屏只预加载到首帧；
2. 离开窗口的播放实例立即释放，池容量 4，避免低端机解码器耗尽；
3. 播放回调只刷新进度条、暂停图标等局部，不整屏 `reloadData`；
4. 列表按 id 去重，滚动结束才切换当前页，避免拖动过程中反复起停。

## MVVM 文件与文章章节对应

| 文件 | 文章内容 |
| --- | --- |
| `MVVM_Local/Network/NetworkError.swift` | 3.1 统一错误 |
| `MVVM_Local/Network/HttpManager.swift` | 3.2 单例 / 共享 Session、3.3 核心请求 + 四个动词、3.4 错误映射 |
| `MVVM_Local/Network/HTTPClient.swift` | 第七节 给 ViewModel 注入协议 |
| `MVVM_Local/Network/ApiResponse.swift` | 4.1 后端统一外壳 |
| `MVVM_Local/Models/UserDTO.swift` | 4.1 DTO 与 `UserRaw` 最小字段集 |
| `MVVM_Local/Features/UserList/UserListViewData.swift` | 4.1 DTO → ViewData 映射 |
| `MVVM_Local/Features/UserList/UserPage.swift` | 4.2 解码配置、4.6 泛型页容器 + Codable 解析 |
| `MVVM_Local/Features/UserList/UserListViewModel.swift` | 4.3 Deferred + Future、4.6 分页状态机、第五节写操作 |
| `MVVM_Local/Features/UserList/UserListViewController.swift` | 4.4 Controller 只订阅、4.6 滚到底触发 |
| `MVVM_Local/Features/UserList/Parsing/HandyJSONUserPageParser.swift` | 4.5 HandyJSON 替换写法 |
| `MVVM_Local/Features/UserList/Parsing/ObjectMapperUserPageParser.swift` | 4.5 ObjectMapper 替换写法 |
| `MockServer/mock_server.py` | 演示用 `/v1/users` 分页 + 关注接口 |

## 三条边界

1. 网络层不 import 业务模型，也不碰 Codable；
2. ViewModel 不 import UIKit；
3. Controller 里不出现 `AF.`，也不出现 `JSONDecoder`。

## 换解析库

界面上方的分段控件可以在 **Codable / HandyJSON / ObjectMapper** 之间切换。
切换只会替换 ViewModel 的 `parser`，`HttpManager` 与 Controller 不动——这正是文章 4.5 想说明的：
网络层只回传 `Data`，解析库就被隔离在 ViewModel 的解码那一步。

调试时也可以不点界面，直接用环境变量指定启动解析库：

```bash
# 0 = Codable，1 = HandyJSON，2 = ObjectMapper
SIMCTL_CHILD_USER_PAGE_PARSER=1 xcrun simctl launch --terminate-running-process booted com.climby.ff.MVVM-Local
```

## Mock 接口

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| GET | `/v1/users?page=1&pageSize=20` | 86 条用户，分页返回 `list/page/pageSize/total/hasMore` |
| POST | `/v1/users/{id}/follow` | 关注用户 |
| PUT | `/v1/users/{id}` | 修改昵称，body 为 `{"nickname": "..."}` |
| DELETE | `/v1/users/{id}` | 删除用户 |

响应统一为 `{"code": 0, "message": "ok", "data": ...}`。

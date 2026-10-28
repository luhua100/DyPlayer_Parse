//
//  VideoPlayerPool.swift
//  MVVM_Local
//
//  对应 Flutter 文章 5.2：LRU 播放器池。
//  capacity 建议 3~5：覆盖「当前 + 前后各一」，再多低端机解码器吃不消。
//

import Foundation

final class VideoPlayerPool {
    let capacity: Int

    private var entries: [String: VideoPlayerEntry] = [:]
    private var keys: [String] = []          // 尾部 = 最近使用
    private var disposed = false
    private(set) var isMuted: Bool

    init(capacity: Int = 4, muted: Bool = true) {
        self.capacity = capacity
        self.isMuted = muted
    }

    var count: Int { entries.count }

    /// 获取或创建播放单元，同步返回，不阻塞首帧。
    func entry(for url: URL) -> VideoPlayerEntry {
        let key = url.absoluteString
        if let entry = entries[key] {
            touch(key)
            return entry
        }

        let entry = VideoPlayerEntry(url: url, muted: isMuted)
        entries[key] = entry
        keys.append(key)
        enforceCapacity()
        return entry
    }

    /// 预加载前后一屏：初始化好停在第一帧，滑到时直接起播。
    func preload(_ urls: [URL]) {
        guard !disposed else { return }
        for url in urls {
            entry(for: url).ensureInitialized()
        }
    }

    /// 只保留窗口内的实例，窗口外立即释放。
    func retainOnly(_ keep: Set<String>) {
        guard !disposed else { return }

        let victims = keys.filter { !keep.contains($0) }
        for key in victims {
            entries.removeValue(forKey: key)?.dispose()
        }
        keys.removeAll { !keep.contains($0) }
        enforceCapacity()
    }

    /// 页面进后台 / 切频道时调用。
    func pauseAll() {
        guard !disposed else { return }
        entries.values.forEach { $0.pause() }
    }

    func setMuted(_ muted: Bool) {
        guard !disposed else { return }
        isMuted = muted
        entries.values.forEach { $0.setMuted(muted) }
    }

    func dispose() {
        guard !disposed else { return }
        disposed = true
        entries.values.forEach { $0.dispose() }
        entries.removeAll()
        keys.removeAll()
    }

    private func touch(_ key: String) {
        guard let index = keys.firstIndex(of: key) else { return }
        keys.remove(at: index)
        keys.append(key)
    }

    private func enforceCapacity() {
        while entries.count > capacity, let oldest = keys.first {
            entries.removeValue(forKey: oldest)?.dispose()
            keys.removeFirst()
        }
    }
}

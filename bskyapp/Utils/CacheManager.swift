import Foundation

/// キャッシュアイテムの構造体
struct CacheItem<T> {
    let data: T
    let timestamp: Date
    let ttl: TimeInterval // Time To Live (秒)
    
    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > ttl
    }
}

/// 汎用キャッシュマネージャー
class CacheManager {
    static let shared = CacheManager()
    
    private var cache: [String: Any] = [:]
    private let queue = DispatchQueue(label: "CacheManager", attributes: .concurrent)
    
    private init() {}
    
    /// データをキャッシュに保存
    func set<T>(_ data: T, forKey key: String, ttl: TimeInterval = 300) { // デフォルト5分
        queue.async(flags: .barrier) {
            let item = CacheItem(data: data, timestamp: Date(), ttl: ttl)
            self.cache[key] = item
        }
    }
    
    /// キャッシュからデータを取得
    func get<T>(_ type: T.Type, forKey key: String) -> T? {
        return queue.sync {
            guard let item = cache[key] as? CacheItem<T> else {
                return nil
            }
            
            if item.isExpired {
                cache.removeValue(forKey: key)
                return nil
            }
            
            return item.data
        }
    }
    
    /// 特定のキーのキャッシュを削除
    func remove(forKey key: String) {
        queue.async(flags: .barrier) {
            self.cache.removeValue(forKey: key)
        }
    }
    
    /// 期限切れのキャッシュを削除
    func cleanExpiredCache() {
        queue.async(flags: .barrier) {
            let keysToRemove = self.cache.compactMap { key, value -> String? in
                if let item = value as? CacheItem<Any>, item.isExpired {
                    return key
                }
                return nil
            }
            
            keysToRemove.forEach { key in
                self.cache.removeValue(forKey: key)
            }
        }
    }
    
    /// 全キャッシュをクリア
    func clearAll() {
        queue.async(flags: .barrier) {
            self.cache.removeAll()
        }
    }
}

/// タイムライン専用のキャッシュマネージャー
class TimelineCacheManager {
    static let shared = TimelineCacheManager()
    
    private var timelineCache: FeedResponse?
    private var lastFetchTime: Date?
    private let cacheValidityDuration: TimeInterval = 60 // 1分間有効
    
    private init() {}
    
    /// タイムラインをキャッシュに保存
    func cacheTimeline(_ timeline: FeedResponse) {
        timelineCache = timeline
        lastFetchTime = Date()
    }
    
    /// キャッシュされたタイムラインを取得
    func getCachedTimeline() -> FeedResponse? {
        guard let cache = timelineCache,
              let lastFetch = lastFetchTime,
              Date().timeIntervalSince(lastFetch) < cacheValidityDuration else {
            return nil
        }
        return cache
    }
    
    /// キャッシュが有効かどうかを確認
    var isCacheValid: Bool {
        guard let lastFetch = lastFetchTime else { return false }
        return Date().timeIntervalSince(lastFetch) < cacheValidityDuration
    }
    
    /// キャッシュをクリア
    func clearCache() {
        timelineCache = nil
        lastFetchTime = nil
    }
}

/// プロフィール専用のキャッシュマネージャー
class ProfileCacheManager {
    static let shared = ProfileCacheManager()
    
    private let cacheManager = CacheManager.shared
    private let profileCacheTTL: TimeInterval = 300 // 5分間有効
    
    private init() {}
    
    /// プロフィールをキャッシュに保存
    func cacheProfile(_ profile: GetProfileApiResponse, for actor: String) {
        let key = "profile_\(actor)"
        cacheManager.set(profile, forKey: key, ttl: profileCacheTTL)
    }
    
    /// キャッシュされたプロフィールを取得
    func getCachedProfile(for actor: String) -> GetProfileApiResponse? {
        let key = "profile_\(actor)"
        return cacheManager.get(GetProfileApiResponse.self, forKey: key)
    }
    
    /// 特定のプロフィールキャッシュを削除
    func clearProfile(for actor: String) {
        let key = "profile_\(actor)"
        cacheManager.remove(forKey: key)
    }
}

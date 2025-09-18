import Foundation
import Alamofire

/// レート制限管理クラス
class RateLimitManager {
    static let shared = RateLimitManager()
    
    private var requestCounts: [String: Int] = [:]
    private var lastResetTime: [String: Date] = [:]
    private var retryAfter: [String: Date] = [:]
    
    private let queue = DispatchQueue(label: "RateLimitManager", attributes: .concurrent)
    
    // デフォルトのレート制限設定
    private let defaultLimits: [String: (requests: Int, timeWindow: TimeInterval)] = [
        "timeline": (requests: 30, timeWindow: 300), // 5分間に30回
        "profile": (requests: 20, timeWindow: 300),  // 5分間に20回
        "like": (requests: 50, timeWindow: 300),     // 5分間に50回
        "follow": (requests: 10, timeWindow: 300),   // 5分間に10回
        "default": (requests: 100, timeWindow: 300)  // デフォルト: 5分間に100回
    ]
    
    private init() {}
    
    /// API呼び出し前にレート制限をチェック
    func canMakeRequest(for endpoint: String) -> Bool {
        return queue.sync {
            let now = Date()
            let limits = defaultLimits[endpoint] ?? defaultLimits["default"]!
            
            // 429エラー後の待機時間をチェック
            if let retryTime = retryAfter[endpoint], now < retryTime {
                return false
            }
            
            // 時間窓をリセット
            if let lastReset = lastResetTime[endpoint],
               now.timeIntervalSince(lastReset) >= limits.timeWindow {
                requestCounts[endpoint] = 0
                lastResetTime[endpoint] = now
            } else if lastResetTime[endpoint] == nil {
                lastResetTime[endpoint] = now
            }
            
            let currentCount = requestCounts[endpoint] ?? 0
            return currentCount < limits.requests
        }
    }
    
    /// API呼び出し後にカウントを更新
    func recordRequest(for endpoint: String) {
        queue.async(flags: .barrier) {
            self.requestCounts[endpoint] = (self.requestCounts[endpoint] ?? 0) + 1
        }
    }
    
    /// 429エラー時の処理
    func handle429Error(for endpoint: String, retryAfterSeconds: Int = 60) {
        queue.async(flags: .barrier) {
            let retryTime = Date().addingTimeInterval(TimeInterval(retryAfterSeconds))
            self.retryAfter[endpoint] = retryTime
            print("Rate limit exceeded for \(endpoint). Retry after: \(retryTime)")
        }
    }
    
    /// 次のリクエストまでの待機時間を取得
    func getWaitTime(for endpoint: String) -> TimeInterval {
        return queue.sync {
            if let retryTime = retryAfter[endpoint] {
                let waitTime = retryTime.timeIntervalSinceNow
                return max(0, waitTime)
            }
            return 0
        }
    }
    
    /// 統計情報を取得
    func getStats(for endpoint: String) -> (current: Int, limit: Int, resetTime: Date?) {
        return queue.sync {
            let limits = defaultLimits[endpoint] ?? defaultLimits["default"]!
            let current = requestCounts[endpoint] ?? 0
            let resetTime = lastResetTime[endpoint]?.addingTimeInterval(limits.timeWindow)
            return (current: current, limit: limits.requests, resetTime: resetTime)
        }
    }
    
    /// 全ての制限をリセット
    func resetAll() {
        queue.async(flags: .barrier) {
            self.requestCounts.removeAll()
            self.lastResetTime.removeAll()
            self.retryAfter.removeAll()
        }
    }
}

/// API呼び出しを安全に実行するためのヘルパー
class SafeAPIExecutor {
    static let shared = SafeAPIExecutor()
    private let rateLimitManager = RateLimitManager.shared
    
    private init() {}
    
    /// レート制限を考慮してAPI呼び出しを実行
    func execute<T>(
        endpoint: String,
        maxRetries: Int = 3,
        apiCall: @escaping () async throws -> T
    ) async throws -> T {
        var retryCount = 0
        
        while retryCount <= maxRetries {
            // レート制限チェック
            if !rateLimitManager.canMakeRequest(for: endpoint) {
                let waitTime = rateLimitManager.getWaitTime(for: endpoint)
                if waitTime > 0 {
                    print("Rate limit reached for \(endpoint). Waiting \(waitTime) seconds...")
                    try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
                }
            }
            
            do {
                // API呼び出し実行
                rateLimitManager.recordRequest(for: endpoint)
                let result = try await apiCall()
                return result
                
            } catch {
                // 429エラーの処理
                if let afError = error as? AFError,
                   case .responseValidationFailed(reason: .unacceptableStatusCode(code: 429)) = afError {
                    
                    let retryAfter = extractRetryAfterFromError(error) ?? 60
                    rateLimitManager.handle429Error(for: endpoint, retryAfterSeconds: retryAfter)
                    
                    if retryCount < maxRetries {
                        retryCount += 1
                        let backoffTime = calculateBackoffTime(retryCount: retryCount)
                        print("429 error for \(endpoint). Retrying in \(backoffTime) seconds... (attempt \(retryCount)/\(maxRetries))")
                        try await Task.sleep(nanoseconds: UInt64(backoffTime * 1_000_000_000))
                        continue
                    }
                }
                
                throw error
            }
        }
        
        throw NSError(domain: "SafeAPIExecutor", code: -1, userInfo: [NSLocalizedDescriptionKey: "Max retries exceeded"])
    }
    
    /// エラーからRetry-Afterヘッダーを抽出
    private func extractRetryAfterFromError(_ error: Error) -> Int? {
        // Alamofireのエラーからレスポンスヘッダーを取得する実装
        // 実際の実装では、HTTPレスポンスからRetry-Afterヘッダーを読み取る
        return nil
    }
    
    /// 指数バックオフの計算
    private func calculateBackoffTime(retryCount: Int) -> TimeInterval {
        let baseDelay: TimeInterval = 1.0
        let maxDelay: TimeInterval = 60.0
        let backoff = baseDelay * pow(2.0, Double(retryCount - 1))
        return min(backoff, maxDelay)
    }
}

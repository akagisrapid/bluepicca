import Foundation

/// バッチ処理用のアクション定義
enum BatchAction {
    case like(postUri: String, postCid: String)
    case unlike(likeUri: String)
    case repost(postUri: String, postCid: String)
    case unrepost(repostUri: String)
    case follow(actorDid: String)
    case unfollow(followUri: String)
}

/// バッチ処理結果
struct BatchResult {
    let success: Bool
    let action: BatchAction
    let result: Any?
    let error: Error?
}

/// バッチ処理マネージャー
class BatchProcessor {
    static let shared = BatchProcessor()
    
    private var pendingActions: [BatchAction] = []
    private var isProcessing = false
    private let queue = DispatchQueue(label: "BatchProcessor", attributes: .concurrent)
    private let processingQueue = DispatchQueue(label: "BatchProcessing")
    
    // バッチ処理の設定
    private let batchSize = 5 // 一度に処理するアクション数
    private let processingInterval: TimeInterval = 2.0 // 処理間隔（秒）
    private var processingTimer: Timer?
    
    private init() {
        startPeriodicProcessing()
    }
    
    deinit {
        stopPeriodicProcessing()
    }
    
    /// アクションをキューに追加
    func addAction(_ action: BatchAction) {
        queue.async(flags: .barrier) {
            self.pendingActions.append(action)
            Swift.print("Added action to batch queue. Queue size: \(self.pendingActions.count)")
        }
    }
    
    /// 即座にバッチ処理を実行
    func processImmediately() async -> [BatchResult] {
        return await withCheckedContinuation { continuation in
            processingQueue.async {
                Task {
                    let results = await self.processBatch()
                    continuation.resume(returning: results)
                }
            }
        }
    }
    
    /// 定期的なバッチ処理を開始
    private func startPeriodicProcessing() {
        processingTimer = Timer.scheduledTimer(withTimeInterval: processingInterval, repeats: true) { _ in
            Task {
                await self.processBatch()
            }
        }
    }
    
    /// 定期的なバッチ処理を停止
    private func stopPeriodicProcessing() {
        processingTimer?.invalidate()
        processingTimer = nil
    }
    
    /// バッチ処理を実行
    private func processBatch() async -> [BatchResult] {
        guard !isProcessing else { return [] }

        // Safely extract a batch of actions under barrier to protect shared state
        let actionsToProcess: [BatchAction] = queue.sync(flags: .barrier) {
            guard !pendingActions.isEmpty else { return [] }
            isProcessing = true
            let batch = Array(pendingActions.prefix(batchSize))
            pendingActions.removeFirst(min(batchSize, pendingActions.count))
            return batch
        }

        guard !actionsToProcess.isEmpty else {
            // If no actions were available, ensure processing flag is reset
            isProcessing = false
            return []
        }

        print("Processing batch of \(actionsToProcess.count) actions")

        var results: [BatchResult] = []

        // Process actions in parallel
        await withTaskGroup(of: BatchResult.self) { group in
            for action in actionsToProcess {
                group.addTask { [self] in
                    await self.processAction(action)
                }
            }

            for await result in group {
                results.append(result)
            }
        }

        isProcessing = false

        // Output success/failure statistics
        let successCount = results.filter { $0.success }.count
        let failureCount = results.count - successCount
        print("Batch processing completed: \(successCount) success, \(failureCount) failures")

        return results
    }
    
    /// 個別のアクションを処理
    private func processAction(_ action: BatchAction) async -> BatchResult {
        do {
            let result = try await executeAction(action)
            return BatchResult(success: true, action: action, result: result, error: nil)
        } catch {
            print("Batch action failed: \(action), error: \(error)")
            return BatchResult(success: false, action: action, result: nil, error: error)
        }
    }
    
    /// アクションを実際に実行
    private func executeAction(_ action: BatchAction) async throws -> Any {
        let safeExecutor = SafeAPIExecutor.shared
        
        switch action {
        case .like(let postUri, let postCid):
            return try await safeExecutor.execute(endpoint: "like") {
                try await createLike(postUri: postUri, postCid: postCid)
            }
            
        case .unlike(let likeUri):
            return try await safeExecutor.execute(endpoint: "like") {
                try await deleteLike(likeUri: likeUri)
                return "Success"
            }
            
        case .repost(let postUri, let postCid):
            return try await safeExecutor.execute(endpoint: "like") { // repostも同じエンドポイント制限を使用
                try await createRepost(postUri: postUri, postCid: postCid)
            }
            
        case .unrepost(let repostUri):
            return try await safeExecutor.execute(endpoint: "like") {
                try await deleteRepost(repostUri: repostUri)
                return "Success"
            }
            
        case .follow(let actorDid):
            return try await safeExecutor.execute(endpoint: "follow") {
                try await CreateFollowApi.createFollow(actorDid: actorDid)
            }
            
        case .unfollow(let followUri):
            return try await safeExecutor.execute(endpoint: "follow") {
                try await DeleteRecordApi.deleteRecord(uri: followUri)
                return "Success"
            }
        }
    }
    
    /// キューの状態を取得
    func getQueueStatus() -> (pending: Int, processing: Bool) {
        return queue.sync {
            (pending: pendingActions.count, processing: isProcessing)
        }
    }
    
    /// キューをクリア
    func clearQueue() {
        queue.async(flags: .barrier) {
            self.pendingActions.removeAll()
        }
    }
}

/// バッチ処理対応のアクションヘルパー
class BatchActionHelper {
    static let shared = BatchActionHelper()
    private let batchProcessor = BatchProcessor.shared
    
    private init() {}
    
    /// いいねをバッチ処理に追加
    func queueLike(postUri: String, postCid: String) {
        let action = BatchAction.like(postUri: postUri, postCid: postCid)
        batchProcessor.addAction(action)
    }
    
    /// いいね取り消しをバッチ処理に追加
    func queueUnlike(likeUri: String) {
        let action = BatchAction.unlike(likeUri: likeUri)
        batchProcessor.addAction(action)
    }
    
    /// リポストをバッチ処理に追加
    func queueRepost(postUri: String, postCid: String) {
        let action = BatchAction.repost(postUri: postUri, postCid: postCid)
        batchProcessor.addAction(action)
    }
    
    /// リポスト取り消しをバッチ処理に追加
    func queueUnrepost(repostUri: String) {
        let action = BatchAction.unrepost(repostUri: repostUri)
        batchProcessor.addAction(action)
    }
    
    /// フォローをバッチ処理に追加
    func queueFollow(actorDid: String) {
        let action = BatchAction.follow(actorDid: actorDid)
        batchProcessor.addAction(action)
    }
    
    /// アンフォローをバッチ処理に追加
    func queueUnfollow(followUri: String) {
        let action = BatchAction.unfollow(followUri: followUri)
        batchProcessor.addAction(action)
    }
    
    /// 即座に処理を実行
    func processNow() async -> [BatchResult] {
        return await batchProcessor.processImmediately()
    }
}

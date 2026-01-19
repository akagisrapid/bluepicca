# 現状の実装レビュー

コードベースの分析に基づき、現在のMVVM実装における主な問題点を以下にまとめました。

## 重大な問題（バグの可能性）

> [!WARNING]
> **「いいね」と「リポスト」がサーバーに同期されていない可能性があります。**

- **現象**: `TimelineCardViewModel` と `PostDetailViewModel` で `PostStateManager.shared.setLiked(...)` などを呼び出しています。
- **調査結果**: `PostStateManager` は `UserDefaults`（ローカルストレージ）への保存のみを行っています。`PostStateManager` の変更を監視して、実際に Bluesky/AT Protocol の API（`createRecord`）を呼び出す処理が見当たりません。
- **影響**: ユーザーが「いいね」をしたつもりでも、サーバーには送信されておらず、他のユーザーからは見えません。アプリを再インストールすると「いいね」の状態は消えます。

## アーキテクチャ上の違反 (MVVM)

> [!IMPORTANT]
> 現在のアーキテクチャは関心事が混在しており、テストが困難でバグが発生しやすい状態です。

### 1. Viewのボディ内でのViewModelのインスタンス化
- **ファイル**: `ContentView.swift`
- **問題点**: `List` のループ内で `TimelineCardViewModel` をインスタンス化しています。
  ```swift
  List(viewModel.validFeeds) { feedItem in
      // ...
      var timelineCardViewModel = TimelineCardViewModel(post: post, ...) // 毎回生成される
      TimelineCardView(viewModel: timelineCardViewModel)
  }
  ```
- **影響**: `TimelineCardViewModel` は `class`（参照型）です。Viewの描画更新のたびに新しいインスタンスが生成されるため、ViewModel内の `@Published` な状態（いいねの楽観的UI更新など）が失われたり、意図しない挙動になります。また、パフォーマンスにも悪影響を与えます。
- **修正案**: 行ごとのViewModelは `struct`（値型）にするか、親のViewModelで管理する、あるいは `View` 側で直接モデルを表示するように変更すべきです。

### 2. ViewModelが「神クラス」化しており、Service層が欠如している
- **ファイル**: `PostCardViewModel.swift`
- **問題点**: このViewModelが以下の全てを行っています。
  - UIロジック（バリデーション）
  - 画像圧縮処理（`ImageCompressionHelper`, `UIImage`）
  - **直接的なネットワーク通信**（`Alamofire.upload`, `AF.request`）
  - JSONの構築
- **影響**: ロジックが密結合しており、`Alamofire` をモックしない限り単体テストができません。
- **修正案**: ネットワーク通信は `Repository` パターンや `Service` 層（例: `PostService`）に移動させてください。画像処理も独立したユーティリティにすべきです。

### 3. ViewModelへのUIフレームワークの混入
- **ファイル**: `PostCardViewModel.swift`, `TimelineCardViewModel.swift`
- **問題点**: `SwiftUI`, `UIKit`, `PhotosUI` をインポートしています。
- **影響**: ViewModelは可能な限りプラットフォームに依存しない形（Pure Swift）であるべきです。`UIImage` などを直接扱うと、ロジックのテストや再利用が難しくなります。

## コードの保守性

- **エラーハンドリング**: `ContentViewModel.swift` で API エラーを `print` しているだけで、ユーザーへのフィードバックが不足している箇所があります。
- **ロジックの重複**: `TimelineCardViewModel` と `PostDetailViewModel` に、「いいね/リポスト」のトグル処理という全く同じロジックが重複しています。これらは共通の Service または UseCase に切り出すべきです。

## 推奨される改善手順

1.  **「いいね/リポスト」バグの修正**: 実際にAPIを呼び出す処理を実装してください（`InteractionService` などを作成することを推奨）。
2.  **リスト項目のViewModelのリファクタリング**: `ContentView` での `TimelineCardViewModel` の生成方法を見直し、状態消失を防ぐ実装に変更してください。
3.  **Service層の抽出**: `Alamofire` を直接使うのではなく、`TimelineService`, `PostService`, `AuthService` などを作成し、ViewModelに注入（Dependency Injection）してください。

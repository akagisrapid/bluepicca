import SwiftUI

extension View {
  /// リポスト／引用の選択ダイアログ。タイムラインと投稿詳細で共通の表示を提供する。
  ///
  /// アクションの中身（トースト表示の有無など）は呼び出し側で `onRepost` / `onQuote` に渡す。
  func repostConfirmationDialog(
    isPresented: Binding<Bool>,
    isReposted: Bool,
    onRepost: @escaping () -> Void,
    onQuote: @escaping () -> Void
  ) -> some View {
    confirmationDialog("", isPresented: isPresented, titleVisibility: .hidden) {
      Button(isReposted ? "リポストを取り消す" : "リポスト", action: onRepost)
      Button("引用ポスト", action: onQuote)
      Button("キャンセル", role: .cancel) {}
    }
  }

  /// 投稿の通報理由選択ダイアログ。選択された理由は `com.atproto.moderation.defs` のreasonType参照文字列で渡される。
  func reportConfirmationDialog(
    isPresented: Binding<Bool>,
    onSelectReason: @escaping (String) -> Void
  ) -> some View {
    confirmationDialog("投稿を報告", isPresented: isPresented, titleVisibility: .visible) {
      Button("スパム") { onSelectReason("com.atproto.moderation.defs#reasonSpam") }
      Button("規約違反") { onSelectReason("com.atproto.moderation.defs#reasonViolation") }
      Button("誤情報") { onSelectReason("com.atproto.moderation.defs#reasonMisleading") }
      Button("性的なコンテンツ") { onSelectReason("com.atproto.moderation.defs#reasonSexual") }
      Button("迷惑行為") { onSelectReason("com.atproto.moderation.defs#reasonRude") }
      Button("その他") { onSelectReason("com.atproto.moderation.defs#reasonOther") }
      Button("キャンセル", role: .cancel) {}
    }
  }
}

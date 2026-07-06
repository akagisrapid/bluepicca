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
}

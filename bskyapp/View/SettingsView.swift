import SwiftUI

enum AppearanceMode: String, CaseIterable {
  case system = "system"
  case light = "light"
  case dark = "dark"

  var label: String {
    switch self {
    case .system: return "システム"
    case .light: return "ライト"
    case .dark: return "ダーク"
    }
  }

  var colorScheme: ColorScheme? {
    switch self {
    case .system: return nil
    case .light: return .light
    case .dark: return .dark
    }
  }
}

struct SettingsView: View {
  @Binding var isLoggedIn: Bool
  @Environment(\.dismiss) private var dismiss
  @State private var showLogoutConfirmation = false
  @State private var showMuteBlockList = false
  @State private var showMuteWords = false
  @AppStorage("appearanceMode") private var appearanceModeRaw: String = AppearanceMode.system
    .rawValue
  @AppStorage("feedSelectorStyle") private var feedSelectorStyle: String = "dropdown"
  @AppStorage("swipeLeadingAction") private var swipeLeadingActionRaw: String = SwipeAction.like
    .rawValue
  @AppStorage("swipeTrailingAction") private var swipeTrailingActionRaw: String = SwipeAction.repost
    .rawValue

  private var appearanceMode: AppearanceMode {
    AppearanceMode(rawValue: appearanceModeRaw) ?? .system
  }

  var body: some View {
    NavigationStack {
      List {
        Section("タイムライン") {
          Picker("フィード切り替え", selection: $feedSelectorStyle) {
            Text("ドロップダウン").tag("dropdown")
            Text("タブ").tag("tabs")
          }
          .pickerStyle(.segmented)
        }

        Section("スワイプ操作") {
          Picker("右スワイプ", selection: $swipeLeadingActionRaw) {
            ForEach(SwipeAction.allCases, id: \.rawValue) { action in
              Text(action.label).tag(action.rawValue)
            }
          }
          Picker("左スワイプ", selection: $swipeTrailingActionRaw) {
            ForEach(SwipeAction.allCases, id: \.rawValue) { action in
              Text(action.label).tag(action.rawValue)
            }
          }
        }

        Section("外観") {
          Picker("テーマ", selection: $appearanceModeRaw) {
            ForEach(AppearanceMode.allCases, id: \.rawValue) { mode in
              Text(mode.label).tag(mode.rawValue)
            }
          }
          .pickerStyle(.segmented)
        }

        Section("モデレーション") {
          Button(action: { showMuteBlockList = true }) {
            HStack {
              Image(systemName: "hand.raised")
              Text("ミュート・ブロックリスト")
              Spacer()
              Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }
          .foregroundColor(.primary)

          Button(action: { showMuteWords = true }) {
            HStack {
              Image(systemName: "text.badge.minus")
              Text("ミュートワード")
              Spacer()
              Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }
          .foregroundColor(.primary)
        }

        Section {
          Button(role: .destructive) {
            showLogoutConfirmation = true
          } label: {
            HStack {
              Image(systemName: "rectangle.portrait.and.arrow.right")
              Text("ログアウト")
            }
          }
        }
      }
      .navigationTitle("設定")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("閉じる", systemImage: "xmark") {
            dismiss()
          }
        }
      }
      .sheet(isPresented: $showMuteBlockList) {
        MuteBlockListView()
      }
      .sheet(isPresented: $showMuteWords) {
        MuteWordsView()
      }
      .alert("ログアウトしますか？", isPresented: $showLogoutConfirmation) {
        Button("キャンセル", role: .cancel) {}
        Button("ログアウト", role: .destructive) {
          SessionManager.shared.logout()
          isLoggedIn = false
          dismiss()
        }
      }
    }
    .preferredColorScheme(appearanceMode.colorScheme)
  }
}

#Preview {
  SettingsView(isLoggedIn: .constant(true))
}

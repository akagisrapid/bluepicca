import SwiftUI

enum AppearanceMode: String, CaseIterable {
  case system = "system"
  case light = "light"
  case dark = "dark"

  var label: String {
    switch self {
    case .system: return String(localized: "システム")
    case .light: return String(localized: "ライト")
    case .dark: return String(localized: "ダーク")
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
  @State private var showContentLabels = false
  @AppStorage("appearanceMode") private var appearanceModeRaw: String = AppearanceMode.system
    .rawValue
  @AppStorage("feedSelectorStyle") private var feedSelectorStyle: String = "dropdown"
  @AppStorage("swipeLeadingAction") private var swipeLeadingActionRaw: String = SwipeAction.like
    .rawValue
  @AppStorage("swipeTrailingAction") private var swipeTrailingActionRaw: String = SwipeAction.repost
    .rawValue
  @AppStorage("autoRefreshEnabled") private var autoRefreshEnabled: Bool = false
  @AppStorage("autoRefreshIntervalSeconds") private var autoRefreshIntervalSeconds: Int = 60
  @AppStorage("hideImagePreview") private var hideImagePreview: Bool = false
  @AppStorage("hideAvatars") private var hideAvatars: Bool = false
  @AppStorage("restoreScrollOnTabSwitch") private var restoreScrollOnTabSwitch: Bool = true

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
          Toggle("フィード切り替え時に前回位置に戻る", isOn: $restoreScrollOnTabSwitch)
          Toggle("自動更新", isOn: $autoRefreshEnabled)
          if autoRefreshEnabled {
            Picker("更新間隔", selection: $autoRefreshIntervalSeconds) {
              Text("30秒").tag(30)
              Text("1分").tag(60)
              Text("3分").tag(180)
              Text("5分").tag(300)
            }
          }
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
          Toggle("画像プレビューを非表示", isOn: $hideImagePreview)
          Toggle("アバターを非表示", isOn: $hideAvatars)
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

          Button(action: { showContentLabels = true }) {
            HStack {
              Image(systemName: "eye.slash")
              Text("センシティブコンテンツ")
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
        ToolbarItem(placement: .navigationBarTrailing) {
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
      .sheet(isPresented: $showContentLabels) {
        ContentLabelSettingsView()
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

// MARK: - ハッシュタグフィード管理

// MARK: - コンテンツラベル設定

private struct ContentLabelSettingsView: View {
  @ObservedObject private var manager = ContentLabelManager.shared
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      List {
        Section {
          Picker("性的コンテンツ", selection: $manager.sexualPolicy) {
            ForEach(LabelPolicy.allCases, id: \.self) { Text($0.label).tag($0) }
          }
          Picker("ヌード", selection: $manager.nudityPolicy) {
            ForEach(LabelPolicy.allCases, id: \.self) { Text($0.label).tag($0) }
          }
          Picker("グロテスク", selection: $manager.graphicPolicy) {
            ForEach(LabelPolicy.allCases, id: \.self) { Text($0.label).tag($0) }
          }
        } footer: {
          Text("「警告付き」はタイムラインに表示されますが、タップするまで内容が隠れます。「非表示」はタイムラインから除外されます。")
        }
      }
      .navigationTitle("センシティブコンテンツ")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("閉じる", systemImage: "xmark") { dismiss() }
        }
      }
    }
  }
}

#Preview {
  SettingsView(isLoggedIn: .constant(true))
}

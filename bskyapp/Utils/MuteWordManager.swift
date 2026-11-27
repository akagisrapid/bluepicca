import Foundation

/// Bluesky の mutedWords と同じく、対象（本文とタグ / タグのみ）と期限を持つ
struct MuteWord: Codable, Hashable, Identifiable {
  enum Target: String, Codable, CaseIterable {
    case content, tag

    var label: LocalizedStringResource {
      switch self {
      case .content: "本文とタグ"
      case .tag: "タグのみ"
      }
    }
  }

  var value: String
  var target: Target = .content
  /// nil なら無期限
  var expiresAt: Date?
  /// Bluesky 側の id と actorTarget。同期で書き戻すときに消さないよう持っておく
  var serverId: String?
  var actorTarget: String?

  var id: String { value }

  func isActive(at now: Date = .now) -> Bool {
    expiresAt.map { $0 > now } ?? true
  }
}

class MuteWordManager: ObservableObject {
  static let shared = MuteWordManager()
  /// 旧形式（[String]）。読み込み時に移行する
  private let legacyKey = "muteWords"
  private let key = "muteWordEntries"

  @Published var entries: [MuteWord]

  /// 変更を Bluesky に送る。テストでは差し替えて通信しない
  var upload: ([MuteWord]) async throws -> Void = {
    try await MutedWordsPreferenceApi().putMutedWords($0)
  }

  /// 期限内の語。プッシュサーバーへの登録とテストが使う
  var muteWords: [String] {
    get { entries.filter { $0.isActive() }.map(\.value) }
    set {
      entries = newValue.map { MuteWord(value: $0) }
      save()
    }
  }

  private init() {
    if let data = UserDefaults.standard.data(forKey: key),
      let saved = try? JSONDecoder().decode([MuteWord].self, from: data)
    {
      entries = saved
    } else {
      entries = (UserDefaults.standard.stringArray(forKey: legacyKey) ?? [])
        .map { MuteWord(value: $0) }
    }
    removeExpired()
  }

  func add(_ word: String, target: MuteWord.Target = .content, duration: TimeInterval? = nil) {
    let trimmed = word.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return }
    // 同じ語を足し直したら、対象と期限を新しい指定で置き換える
    entries.removeAll { $0.value == trimmed }
    entries.append(
      MuteWord(value: trimmed, target: target, expiresAt: duration.map { Date.now + $0 }))
    removeExpired()
    save()
    uploadEntries()
  }

  func remove(at offsets: IndexSet) {
    entries.remove(atOffsets: offsets)
    save()
    uploadEntries()
  }

  /// Bluesky の設定を正とする。公式アプリなどで足した・消した語もここで反映される
  @MainActor
  func syncFromServer() async {
    #if DEBUG
      if DemoTimeline.isEnabled { return }
    #endif
    let serverWords: [MuteWord]?
    do {
      serverWords = try await MutedWordsPreferenceApi().getMutedWords()
    } catch {
      return  // 通信できないときは手元の設定のまま
    }
    // サーバーにまだ設定が無ければ手元のまま。自動では送らず、次に追加・削除したときに送る
    // （自動で送ると、テスト用に起動したアプリが手元の試験用の語を本物のアカウントに書き込んでしまった）
    guard let serverWords else { return }
    entries = serverWords
    removeExpired()
    save()
  }

  private func uploadEntries() {
    #if DEBUG
      // デモはログイン中の本物のアカウントに書き込まない
      if DemoTimeline.isEnabled { return }
    #endif
    // 送り先は今この時点のものを使う。Task の中で self.upload を読むと、
    // テストが差し替えを戻した後に本物の送信が走り、試験用の語がアカウントに書き込まれた
    let words = entries
    let upload = upload
    Task { try? await upload(words) }
  }

  /// 本文だけの照合（通知など）。タグのみの語は見ない
  func matches(_ text: String) -> Bool {
    entries.contains {
      $0.target == .content && $0.isActive() && text.localizedCaseInsensitiveContains($0.value)
    }
  }

  /// 本文に加えて、引用元の本文・リンクカード（URL・タイトル・説明）・画像と動画の ALT も見る。
  /// タグのみの語は、その投稿のハッシュタグと一致したときだけ
  func matches(_ post: Post) -> Bool {
    let active = entries.filter { $0.isActive() }
    guard !active.isEmpty else { return false }
    let texts = Self.searchableTexts(of: post)
    let tags = Set(Self.hashtags(of: post))
    return active.contains { word in
      switch word.target {
      case .content:
        return texts.contains { $0.localizedCaseInsensitiveContains(word.value) }
          || tags.contains(Self.normalizedTag(word.value))
      case .tag:
        return tags.contains(Self.normalizedTag(word.value))
      }
    }
  }

  static func searchableTexts(of post: Post) -> [String] {
    var texts = [post.record?.text]
    if let embed = post.embed {
      if let external = embed.resolvedExternal {
        texts += [external.uri, external.title, external.description]
      }
      texts += (embed.resolvedImages ?? []).map(\.alt)
      texts.append(embed.alt)
      if let quoted = embed.record {
        texts.append(quoted.value?.text)
        texts += (quoted.embeds ?? []).flatMap { ($0.images ?? []).map(\.alt) }
      }
    }
    return texts.compactMap { $0 }.filter { !$0.isEmpty }
  }

  /// 本文のタグ（ファセット）と、本文に出さないタグ（record.tags）
  static func hashtags(of post: Post) -> [String] {
    let facetTags = (post.record?.facets ?? []).flatMap { ($0.features ?? []).compactMap(\.tag) }
    return (facetTags + (post.record?.tags ?? [])).map(normalizedTag)
  }

  private static func normalizedTag(_ tag: String) -> String {
    (tag.hasPrefix("#") || tag.hasPrefix("＃") ? String(tag.dropFirst()) : tag).lowercased()
  }

  private func removeExpired() {
    entries.removeAll { !$0.isActive() }
  }

  private func save() {
    UserDefaults.standard.set(try? JSONEncoder().encode(entries), forKey: key)
  }
}

import PhotosUI
import SwiftUI

/// 設定画面の一番上に出す自分のアカウントのカード。タップすると下に広がってプロフィールを編集できる
/// （twicca の「プロフィールを編集」に倣い、アイコン・ヘッダー・名前・自己紹介・代名詞・リンクを一画面で直す）
struct ProfileEditCard: View {
  @State private var profile: GetProfileApiResponse?
  @State private var isExpanded = false
  @State private var displayName = ""
  @State private var bio = ""
  @State private var pronouns = ""
  @State private var savedPronouns = ""
  @State private var links: [ProfileLink] = []
  @State private var savedLinks: [ProfileLink] = []
  @State private var newLinkURL = ""
  @State private var newLinkTitle = ""
  @State private var avatarItem: PhotosPickerItem?
  @State private var bannerItem: PhotosPickerItem?
  @State private var newAvatar: UIImage?
  @State private var newBanner: UIImage?
  @State private var isSaving = false
  @State private var errorMessage: String?

  // app.bsky.actor.profile の上限（書記素数）
  private static let maxNameLength = 64
  private static let maxBioLength = 256
  private static let maxPronounsLength = 20
  // app.bsky.actor.link の title と、profile の links の上限
  private static let maxLinkTitleLength = 40
  private static let maxLinks = 10
  private static let pronounPresets = ["she/her", "he/him", "they/them"]

  private var hasChanges: Bool {
    displayName != (profile?.displayName ?? "") || bio != (profile?.description ?? "")
      || newAvatar != nil || newBanner != nil || pronouns != savedPronouns || links != savedLinks
  }

  private var isValid: Bool {
    displayName.count <= Self.maxNameLength && bio.count <= Self.maxBioLength
      && pronouns.count <= Self.maxPronounsLength
  }

  private var canAddLink: Bool {
    ProfileRecordService.normalizedLinkURL(newLinkURL) != nil
      && newLinkTitle.count <= Self.maxLinkTitleLength
  }

  var body: some View {
    Section {
      Button {
        withAnimation(.snappy) { isExpanded.toggle() }
      } label: {
        HStack(spacing: 12) {
          avatar(size: 48)
          VStack(alignment: .leading, spacing: 2) {
            Text(profile?.displayName.flatMap { $0.isEmpty ? nil : $0 } ?? profile?.handle ?? " ")
              .font(.headline)
              .lineLimit(1)
            Text(profile.map { savedPronouns.isEmpty ? "@\($0.handle)" : "@\($0.handle) · \(savedPronouns)" } ?? " ")
              .font(.subheadline)
              .foregroundColor(.secondary)
              .lineLimit(1)
          }
          Spacer()
          Image(systemName: "chevron.down")
            .font(.caption)
            .foregroundColor(.secondary)
            .rotationEffect(.degrees(isExpanded ? 180 : 0))
        }
      }
      .foregroundColor(.primary)
      .disabled(profile == nil)
      .accessibilityHint(isExpanded ? "編集を閉じる" : "プロフィールを編集")

      if isExpanded {
        editor
      }
    }
    .task { await load() }
    .onChange(of: avatarItem) { _, item in Task { newAvatar = await image(from: item) } }
    .onChange(of: bannerItem) { _, item in Task { newBanner = await image(from: item) } }
    .alert(
      "プロフィールを保存できませんでした",
      isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    ) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(errorMessage ?? "")
    }
  }

  @ViewBuilder private var editor: some View {
    PhotosPicker(selection: $bannerItem, matching: .images) {
      ZStack {
        Group {
          if let newBanner {
            Image(uiImage: newBanner).resizable().scaledToFill()
          } else if let url = profile?.banner.flatMap(URL.init(string:)) {
            CachedAsyncImage(url: url) {
              $0.resizable().scaledToFill()
            } placeholder: {
              Color(.systemGray5)
            }
          } else {
            Color(.systemGray5)
          }
        }
        .frame(height: 100)
        .frame(maxWidth: .infinity)
        .clipped()
        SwiftUI.Label("ヘッダーを変更", systemImage: "camera")
          .font(.caption)
          .padding(6)
          .background(.ultraThinMaterial, in: Capsule())
      }
    }
    .listRowInsets(EdgeInsets())

    PhotosPicker(selection: $avatarItem, matching: .images) {
      HStack {
        avatar(size: 40)
        Text("アイコンを変更")
      }
    }

    VStack(alignment: .leading, spacing: 4) {
      Text("名前").font(.caption).foregroundColor(.secondary)
      TextField("名前", text: $displayName)
      counter(displayName.count, Self.maxNameLength)
    }

    VStack(alignment: .leading, spacing: 4) {
      Text("自己紹介").font(.caption).foregroundColor(.secondary)
      TextField("自己紹介", text: $bio, axis: .vertical)
        .lineLimit(3...8)
      counter(bio.count, Self.maxBioLength)
    }

    VStack(alignment: .leading, spacing: 8) {
      Text("代名詞").font(.caption).foregroundColor(.secondary)
      HStack {
        ForEach(Self.pronounPresets, id: \.self) { preset in
          Button(preset) { pronouns = preset }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .tint(pronouns == preset ? .accentColor : .secondary)
        }
      }
      TextField("例: they/them", text: $pronouns)
        .textInputAutocapitalization(.never)
      counter(pronouns.count, Self.maxPronounsLength)
    }

    ForEach(links) { link in
      HStack {
        Image(systemName: "link").foregroundColor(.secondary)
        VStack(alignment: .leading, spacing: 2) {
          Text(link.title.isEmpty ? (URL(string: link.url)?.host() ?? link.url) : link.title)
            .lineLimit(1)
          Text(link.url).font(.caption).foregroundColor(.secondary).lineLimit(1)
        }
        Spacer()
        Button {
          withAnimation { links.removeAll { $0.id == link.id } }
        } label: {
          Image(systemName: "minus.circle.fill").foregroundColor(.red)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("リンクを削除")
      }
    }
    .onMove { links.move(fromOffsets: $0, toOffset: $1) }

    if links.count < Self.maxLinks {
      VStack(alignment: .leading, spacing: 8) {
        Text("リンク").font(.caption).foregroundColor(.secondary)
        TextField("yoursite.com", text: $newLinkURL)
          .keyboardType(.URL)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
        TextField("タイトル（任意）例: ポートフォリオ", text: $newLinkTitle)
        Button("リンクを追加", systemImage: "plus") {
          guard let url = ProfileRecordService.normalizedLinkURL(newLinkURL) else { return }
          withAnimation { links.append(ProfileLink(url: url, title: newLinkTitle)) }
          newLinkURL = ""
          newLinkTitle = ""
        }
        .buttonStyle(.borderless)
        .foregroundStyle(canAddLink ? Color.accentColor : .secondary)
        .disabled(!canAddLink)
      }
    }

    Button {
      Task { await save() }
    } label: {
      HStack {
        Spacer()
        if isSaving { ProgressView() } else { Text("保存").bold() }
        Spacer()
      }
    }
    .disabled(!hasChanges || !isValid || isSaving)
  }

  private func avatar(size: CGFloat) -> some View {
    Group {
      if let newAvatar {
        Image(uiImage: newAvatar).resizable().scaledToFill()
      } else if let url = profile?.avatar.flatMap(URL.init(string:)) {
        CachedAsyncImage(url: url) {
          $0.resizable().scaledToFill()
        } placeholder: {
          Color(.systemGray5)
        }
      } else {
        Color(.systemGray5)
      }
    }
    .frame(width: size, height: size)
    .clipShape(Circle())
  }

  private func counter(_ count: Int, _ limit: Int) -> some View {
    Text("\(count) / \(limit)")
      .font(.caption2)
      .foregroundColor(count > limit ? .red : .secondary)
      .frame(maxWidth: .infinity, alignment: .trailing)
  }

  private func image(from item: PhotosPickerItem?) async -> UIImage? {
    guard let data = try? await item?.loadTransferable(type: Data.self) else { return nil }
    return UIImage(data: data)
  }

  private func load() async {
    #if DEBUG
      if DemoTimeline.isEnabled {
        profile = DemoTimeline.profile
        savedPronouns = DemoTimeline.profile.pronouns ?? ""
        savedLinks = (DemoTimeline.profile.links ?? []).map {
          ProfileLink(url: $0.url, title: $0.title ?? "")
        }
        resetFields()
        return
      }
    #endif
    guard let session = try? await SessionManager.shared.getSession(),
      let loaded = try? await GetProfileApi().getProfile(
        param: GetProfileApiRequest(actor: session.did))
    else { return }
    profile = loaded
    if let record = try? await ProfileRecordService.loadExtras() {
      savedPronouns = record.pronouns
      savedLinks = record.links
    }
    resetFields()
  }

  private func resetFields() {
    displayName = profile?.displayName ?? ""
    bio = profile?.description ?? ""
    pronouns = savedPronouns
    links = savedLinks
    newLinkURL = ""
    newLinkTitle = ""
    avatarItem = nil
    bannerItem = nil
    newAvatar = nil
    newBanner = nil
  }

  private func save() async {
    isSaving = true
    defer { isSaving = false }
    do {
      try await ProfileRecordService.update(
        displayName: displayName, description: bio, pronouns: pronouns, links: links,
        avatar: newAvatar, banner: newBanner)
      // AppView への反映は少し遅れるので、取り直す前に手元の値で表示を更新しておく
      profile?.displayName = displayName
      profile?.description = bio
      savedPronouns = pronouns
      withAnimation(.snappy) { isExpanded = false }
      await load()
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}

/// プロフィールに並べるリンク。保存済みのものは app.bsky.actor.link レコードを指す `ref`（uri / cid）を持つ
struct ProfileLink: Identifiable, Equatable {
  let id = UUID()
  var ref: [String: String]?
  var url: String
  var title: String
}

/// app.bsky.actor.profile/self レコードの読み書き。
/// 知らないフィールド（pinnedPost やラベルなど）を消さないよう、取得した JSON をそのまま直して書き戻す
enum ProfileRecordService {
  private static let endPoint = "https://bsky.social/xrpc/"
  // app.bsky.actor.profile の avatar / banner の上限
  private static let maxImageBytes = 1_000_000

  /// 入力をリンクとして保存できる https の URL にする。スキームが無ければ https を補う
  static func normalizedLinkURL(_ input: String) -> String? {
    let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
    let string = trimmed.contains("://") ? trimmed : "https://" + trimmed
    guard let url = URL(string: string), url.scheme?.lowercased() == "https",
      let host = url.host(), host.contains("."), !host.hasPrefix("."), !host.hasSuffix(".")
    else { return nil }
    return string
  }

  /// getProfile に載らない代名詞と、links が指す順に並べたリンク
  static func loadExtras() async throws -> (pronouns: String, links: [ProfileLink]) {
    let session = try await SessionManager.shared.getSession()
    let headers: HTTPHeaders = ["Authorization": "Bearer \(session.accessJwt)"]
    let (record, _) = try await profileRecord(did: session.did, headers: headers)
    let refs = record["links"] as? [[String: String]] ?? []
    guard !refs.isEmpty else { return (record["pronouns"] as? String ?? "", []) }

    // ponytail: 1 回の listRecords で取る。links の上限が 10 なので足りる
    let data = try await HTTPClient.data(
      endPoint + "com.atproto.repo.listRecords",
      query: ["repo": session.did, "collection": "app.bsky.actor.link", "limit": 100],
      headers: headers)
    let items =
      (try JSONSerialization.jsonObject(with: data) as? [String: Any])?["records"]
      as? [[String: Any]] ?? []
    let byURI = Dictionary(
      items.compactMap { item in (item["uri"] as? String).map { ($0, item) } },
      uniquingKeysWith: { a, _ in a })
    let links = refs.compactMap { ref -> ProfileLink? in
      guard let uri = ref["uri"], let value = byURI[uri]?["value"] as? [String: Any],
        let url = value["url"] as? String
      else { return nil }
      return ProfileLink(ref: ref, url: url, title: value["title"] as? String ?? "")
    }
    return (record["pronouns"] as? String ?? "", links)
  }

  /// profile/self の中身と cid。まだ一度も作っていないアカウントはレコードが無い（RecordNotFound）
  private static func profileRecord(did: String, headers: HTTPHeaders) async throws -> (
    [String: Any], String?
  ) {
    do {
      let data = try await HTTPClient.data(
        endPoint + "com.atproto.repo.getRecord",
        query: ["repo": did, "collection": "app.bsky.actor.profile", "rkey": "self"],
        headers: headers)
      let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
      return (
        json?["value"] as? [String: Any] ?? ["$type": "app.bsky.actor.profile"],
        json?["cid"] as? String
      )
    } catch let error as HTTPError where error.statusCode == 400 {
      return (["$type": "app.bsky.actor.profile"], nil)
    }
  }

  static func update(
    displayName: String, description: String, pronouns: String, links: [ProfileLink],
    avatar: UIImage?, banner: UIImage?
  ) async throws {
    let session = try await SessionManager.shared.getSession()
    let headers: HTTPHeaders = ["Authorization": "Bearer \(session.accessJwt)"]
    var (record, swapCID) = try await profileRecord(did: session.did, headers: headers)
    let oldRefs = record["links"] as? [[String: String]] ?? []

    // 新しいリンクは先に link レコードを作り、その uri / cid を profile の links に並べる
    var refs: [[String: String]] = []
    for link in links {
      if let ref = link.ref {
        refs.append(ref)
        continue
      }
      var linkRecord: [String: Any] = [
        "$type": "app.bsky.actor.link", "url": link.url,
        "createdAt": ISO8601DateFormatter().string(from: Date()),
      ]
      if !link.title.isEmpty { linkRecord["title"] = link.title }
      let data = try await HTTPClient.data(
        endPoint + "com.atproto.repo.createRecord", method: .post,
        json: ["repo": session.did, "collection": "app.bsky.actor.link", "record": linkRecord],
        headers: headers)
      let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
      guard let uri = json?["uri"] as? String, let cid = json?["cid"] as? String else {
        throw URLError(.cannotParseResponse)
      }
      refs.append(["uri": uri, "cid": cid])
    }

    record["displayName"] = displayName.isEmpty ? nil : displayName
    record["description"] = description.isEmpty ? nil : description
    record["pronouns"] = pronouns.isEmpty ? nil : pronouns
    record["links"] = refs.isEmpty ? nil : refs
    if let avatar { record["avatar"] = try await blob(avatar) }
    if let banner { record["banner"] = try await blob(banner) }

    var body: [String: Any] = [
      "repo": session.did, "collection": "app.bsky.actor.profile", "rkey": "self",
      "record": record,
    ]
    // 他の端末で同時に書き換えていたら上書きせずに失敗させる
    if let swapCID { body["swapRecord"] = swapCID }
    _ = try await HTTPClient.data(
      endPoint + "com.atproto.repo.putRecord", method: .post, json: body, headers: headers)

    // profile から外したリンクのレコードを消す。失敗しても表示には出ないので保存は成功扱いにする
    let kept = Set(refs.compactMap { $0["uri"] })
    for uri in oldRefs.compactMap({ $0["uri"] }) where !kept.contains(uri) {
      guard let rkey = uri.split(separator: "/").last else { continue }
      _ = try? await HTTPClient.data(
        endPoint + "com.atproto.repo.deleteRecord", method: .post,
        json: ["repo": session.did, "collection": "app.bsky.actor.link", "rkey": String(rkey)],
        headers: headers)
    }
  }

  private static func blob(_ image: UIImage) async throws -> [String: Any] {
    guard
      let data = ImageCompressionHelper.compressImage(
        ImageCompressionHelper.resizeImage(image, maxDimension: 2000), maxSizeBytes: maxImageBytes)
    else { throw URLError(.cannotDecodeContentData) }
    let ref = try await PostCreationService.shared.uploadBlob(imageData: data).blob
    return [
      "$type": "blob", "ref": ["$link": ref.cid], "mimeType": ref.mimeType, "size": data.count,
    ]
  }
}

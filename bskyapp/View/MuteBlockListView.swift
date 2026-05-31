import SwiftUI

struct MuteBlockListView: View {
  @StateObject private var viewModel = MuteBlockListViewModel()
  @ObservedObject private var rtFilterManager = RTFilterManager.shared
  @Environment(\.dismiss) private var dismiss
  @State private var selectedSegment = 0

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        Picker("", selection: $selectedSegment) {
          Text("ミュート").tag(0)
          Text("ブロック").tag(1)
          Text("RTフィルタ").tag(2)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)

        if selectedSegment == 0 {
          MutedListSection(viewModel: viewModel)
        } else if selectedSegment == 1 {
          BlockedListSection(viewModel: viewModel)
        } else {
          RTFilterListSection(rtFilterManager: rtFilterManager)
        }
      }
      .navigationTitle("モデレーション")
      .navigationBarTitleDisplayMode(.inline)
      .task {
        await viewModel.fetchMuted()
        await viewModel.fetchBlocked()
      }
      .overlay(alignment: .bottomTrailing) {
        Button(action: { dismiss() }) {
          SwiftUI.Label("閉じる", systemImage: "xmark.circle.fill")
            .labelStyle(.iconOnly)
            .font(.largeTitle)
            .foregroundColor(.white)
            .background(Color.black.opacity(0.7))
            .clipShape(Circle())
            .shadow(radius: 5)
            .scaleEffect(1.2)
        }
        .buttonStyle(.plain)
        .padding(.trailing, 20)
        .padding(.bottom, 20)
      }
    }
  }
}

// MARK: - ミュートリスト

private struct MutedListSection: View {
  @ObservedObject var viewModel: MuteBlockListViewModel

  var body: some View {
    Group {
      if viewModel.isFetchingMuted {
        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if viewModel.mutedActors.isEmpty {
        ContentUnavailableView("ミュートしているアカウントはありません", systemImage: "speaker.slash")
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        List {
          ForEach(viewModel.mutedActors) { actor in
            ModeratedActorRow(actor: actor)
              .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button("ミュート解除", systemImage: "speaker.wave.2") {
                  Task { await viewModel.unmute(actor: actor) }
                }
                .tint(.orange)
              }
          }
        }
        .listStyle(.plain)
      }
    }
  }
}

// MARK: - ブロックリスト

private struct BlockedListSection: View {
  @ObservedObject var viewModel: MuteBlockListViewModel

  var body: some View {
    Group {
      if viewModel.isFetchingBlocked {
        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if viewModel.blockedActors.isEmpty {
        ContentUnavailableView("ブロックしているアカウントはありません", systemImage: "hand.raised")
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        List {
          ForEach(viewModel.blockedActors) { actor in
            ModeratedActorRow(actor: actor)
              .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button("ブロック解除", systemImage: "hand.raised.slash") {
                  Task { await viewModel.unblock(actor: actor) }
                }
                .tint(.red)
              }
          }
        }
        .listStyle(.plain)
      }
    }
  }
}

// MARK: - RTフィルタリスト

private struct RTFilterListSection: View {
  @ObservedObject var rtFilterManager: RTFilterManager

  var body: some View {
    Group {
      let entries = rtFilterManager.entries()
      if entries.isEmpty {
        ContentUnavailableView("RTを非表示にしているアカウントはありません", systemImage: "eye.slash")
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        List {
          ForEach(entries) { entry in
            RTFilterEntryRow(entry: entry)
              .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button("解除", systemImage: "eye") {
                  rtFilterManager.remove(did: entry.did)
                }
                .tint(.orange)
              }
          }
        }
        .listStyle(.plain)
      }
    }
  }
}

private struct RTFilterEntryRow: View {
  let entry: RTFilterEntry

  var body: some View {
    HStack(spacing: 12) {
      AsyncImage(url: entry.avatarUrl) { image in
        image.resizable().scaledToFill()
      } placeholder: {
        Image(systemName: "person.circle.fill")
          .foregroundColor(.secondary)
      }
      .frame(width: 40, height: 40)
      .clipShape(Circle())

      VStack(alignment: .leading, spacing: 2) {
        Text(entry.displayName.isEmpty ? entry.handle : entry.displayName)
          .font(.subheadline)
          .fontWeight(.semibold)
          .foregroundColor(.primary)
        Text("@\(entry.handle)")
          .font(.caption)
          .foregroundColor(.secondary)
      }

      Spacer()

      Image(systemName: "eye.slash")
        .font(.caption2)
        .foregroundColor(.orange)
    }
    .padding(.vertical, 4)
  }
}

// MARK: - 共通行

private struct ModeratedActorRow: View {
  let actor: ModeratedActor

  var body: some View {
    HStack(spacing: 12) {
      AsyncImage(url: actor.avatarUrl) { image in
        image.resizable().scaledToFill()
      } placeholder: {
        Image(systemName: "person.circle.fill")
          .foregroundColor(.secondary)
      }
      .frame(width: 40, height: 40)
      .clipShape(Circle())

      VStack(alignment: .leading, spacing: 2) {
        Text(actor.displayName ?? actor.handle)
          .font(.subheadline)
          .fontWeight(.semibold)
          .foregroundColor(.primary)
        Text("@\(actor.handle)")
          .font(.caption)
          .foregroundColor(.secondary)
      }

      Spacer()
    }
    .padding(.vertical, 4)
  }
}

//
//  RepliesView.swift
//  bskyapp
//
//  Created by shuya on 2025/09/17.
//

import SwiftUI

struct RepliesView: View {
  @StateObject var viewModel: RepliesViewModel
  @Environment(\.dismiss) private var dismiss
  @State private var selectedNotification: NotificationItem?
  @State private var isShowReplyCard = false
  @State private var profileNavActor: String?

  var body: some View {
    NavigationStack {
      List(viewModel.replyNotifications) { notification in
        ReplyCardView(notification: notification)
          .onTapGesture {
            selectedNotification = notification
            isShowReplyCard = true
          }
      }
      .listStyle(.plain)
      .overlay {
        if viewModel.isFetchingReplies {
          ProgressView()
            .progressViewStyle(CircularProgressViewStyle())
            .scaleEffect(2.0)
        }
      }
      .navigationDestination(
        isPresented: Binding(
          get: { profileNavActor != nil },
          set: { if !$0 { profileNavActor = nil } })
      ) {
        if let actor = profileNavActor {
          ProfileView(
            viewModel: ProfileViewModel(
              actor: actor,
              profile: .init(did: "", handle: "", labels: [])))
        }
      }
      .environment(\.navigateToProfile, { actor in profileNavActor = actor })
      .navigationTitle("リプライ")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("更新", systemImage: "arrow.clockwise") {
            Task { await viewModel.fetchReplies() }
          }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("閉じる", systemImage: "xmark") { dismiss() }
        }
      }
    }
    .onAppear {
      Task {
        await viewModel.fetchReplies()
      }
    }
    .sheet(isPresented: $isShowReplyCard) {
      if let notification = selectedNotification {
        ReplyPostCardView(
          notification: notification,
          isShowReplyCard: $isShowReplyCard
        )
      }
    }
  }

  struct ReplyCardView: View {
    let notification: NotificationItem

    var body: some View {
      HStack(alignment: .top, spacing: 10) {
        ProfileImageView(
          viewModel: AsyncImageViewModel(
            url: URL(string: notification.author.avatar ?? ""),
            imageSize: .timeline,
            alt: notification.author.displayName ?? notification.author.handle ?? ""
          ),
          actor: notification.author.did
        )

        VStack(alignment: .leading, spacing: 1) {
          HStack(spacing: 4) {
            Text(notification.author.displayName ?? notification.author.handle ?? "")
              .font(.subheadline)
              .fontWeight(.semibold)
              .foregroundColor(.primary)
              .lineLimit(1)
            if !notification.isRead {
              Circle()
                .fill(Color.blue)
                .frame(width: 8, height: 8)
            }
          }
          Text("@\(notification.author.handle ?? "")")
            .font(.caption)
            .foregroundColor(.secondary)
            .lineLimit(1)

          if let record = notification.record, let text = record.text {
            Text(text)
              .font(.body)
              .foregroundColor(.primary)
              .fixedSize(horizontal: false, vertical: true)
              .padding(.top, 2)
          }
        }

        Spacer()

        if let date = notification.indexedAtDate {
          Text(date.formatted(.dateTime.hour().minute()))
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }
      .padding(.vertical, 5)
      .padding(.horizontal, 12)
    }
  }
}
#Preview {
  RepliesView(viewModel: RepliesViewModel())
}

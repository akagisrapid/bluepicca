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
    
    var body: some View {
        NavigationStack {
            VStack {
                if viewModel.isFetchingReplies {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(2.0)
                        .padding()
                } else {
                    List(viewModel.replyNotifications) { notification in
                        ReplyCardView(notification: notification)
                            .onTapGesture {
                                selectedNotification = notification
                                isShowReplyCard = true
                            }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("リプライ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("更新", systemImage: "arrow.clockwise") {
                        Task {
                            await viewModel.fetchReplies()
                        }
                    }
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
}

struct ReplyCardView: View {
    let notification: NotificationItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ProfileImageView(
                    viewModel: AsyncImageViewModel(
                        url: URL(string: notification.author.avatar ?? ""),
                        imageSize: .avatar,
                        alt: notification.author.displayName ?? notification.author.handle
                    ),
                    actor: notification.author.did
                )
                .frame(width: 40, height: 40)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(notification.author.displayName ?? notification.author.handle)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("@\(notification.author.handle)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(notification.indexedAtDate?.formatted(.dateTime.hour().minute()) ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let record = notification.record, let text = record.text {
                Text(text)
                    .font(.body)
                    .padding(.leading, 48)
            }
            
            if !notification.isRead {
                HStack {
                    Spacer()
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    RepliesView(viewModel: RepliesViewModel())
}

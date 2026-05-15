//
//  ReplyPostCardView.swift
//  bskyapp
//
//  Created by shuya on 2025/09/17.
//

import Combine
import PhotosUI
import SwiftUI

struct ReplyPostCardView: View {
  let notification: NotificationItem?
  let post: Post?
  @Binding var isShowReplyCard: Bool
  @StateObject private var viewModel: ReplyPostCardViewModel
  @FocusState private var isTextEditorFocused: Bool
  @State private var keyboardHeight: CGFloat = 0

  // NotificationItem用のイニシャライザー
  init(notification: NotificationItem, isShowReplyCard: Binding<Bool>) {
    self.notification = notification
    self.post = nil
    self._isShowReplyCard = isShowReplyCard
    self._viewModel = StateObject(wrappedValue: ReplyPostCardViewModel(notification: notification))
  }

  // Post用のイニシャライザー
  init(post: Post, isShowReplyCard: Binding<Bool>) {
    self.notification = nil
    self.post = post
    self._isShowReplyCard = isShowReplyCard
    self._viewModel = StateObject(wrappedValue: ReplyPostCardViewModel(post: post))
  }

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        // リプライ先の投稿
        HStack(alignment: .top, spacing: 10) {
          ProfileImageView(
            viewModel: AsyncImageViewModel(
              url: replyTargetAvatarUrl,
              imageSize: .timeline,
              alt: replyTargetDisplayName
            ),
            actor: replyTargetDid
          )
          .frame(width: 36, height: 36)

          VStack(alignment: .leading, spacing: 2) {
            Text(replyTargetDisplayName)
              .font(.subheadline)
              .fontWeight(.medium)
            Text(replyTargetText)
              .font(.body)
              .foregroundColor(.secondary)
              .lineLimit(3)
          }

          Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 10)

        Divider()

        // テキストエディタエリア
        ZStack(alignment: .topTrailing) {
          TextEditor(text: $viewModel.text)
            .padding(8)
            .overlay(
              RoundedRectangle(cornerRadius: 8)
                .stroke(viewModel.isTextValid ? Color.gray.opacity(0.3) : Color.red, lineWidth: 1)
            )
            .focused($isTextEditorFocused)
            .onChange(of: viewModel.text) {
              viewModel.checkTextCount()
            }

          Text(viewModel.textCountString)
            .font(.caption)
            .foregroundColor(viewModel.isTextValid ? .secondary : .red)
            .padding(8)
        }
        .padding(.horizontal)
        .padding(.top, 8)

        // 選択された画像の表示
        if !viewModel.selectedImages.isEmpty {
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
              ForEach(0..<viewModel.selectedImages.count, id: \.self) { index in
                ZStack(alignment: .topTrailing) {
                  Image(uiImage: viewModel.selectedImages[index])
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                  Button(action: {
                    viewModel.removeImage(at: index)
                  }) {
                    Image(systemName: "xmark.circle.fill")
                      .foregroundColor(.red)
                      .background(Circle().fill(Color.white))
                  }
                  .padding(4)
                }
              }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
          }
        }

        // アップロード進捗表示
        if viewModel.isUploading {
          HStack {
            ProgressView()
              .scaleEffect(0.8)
            Text("アップロード中... \(Int(viewModel.uploadProgress * 100))%")
              .font(.caption)
              .foregroundColor(.blue)
            Spacer()
          }
          .padding(.horizontal)
          .padding(.vertical, 4)
        }

        Spacer()

        // 下部ツールバー: 画像追加（左）と送信ボタン（右）
        HStack {
          PhotosPicker(
            selection: $viewModel.selectedPhotoItems, maxSelectionCount: 1, matching: .images
          ) {
            Image(systemName: "photo.badge.plus")
              .font(.title2)
              .foregroundColor(viewModel.canAddMoreImages() ? .blue : .gray)
          }
          .disabled(!viewModel.canAddMoreImages())

          Spacer()

          Button(action: {
            Task {
              do {
                try await viewModel.postReply()
                await MainActor.run {
                  isShowReplyCard = false
                }
              } catch {
                print("リプライ送信エラー: \(error)")
              }
            }
          }) {
            Image(systemName: "paperplane.fill")
              .font(.title2)
              .foregroundColor(viewModel.isTextValid && !viewModel.isUploading ? .blue : .gray)
          }
          .disabled(!viewModel.isTextValid || viewModel.isUploading)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .padding(.bottom, keyboardHeight > 0 ? 0 : 8)
      }
      .navigationTitle("リプライ")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button(action: {
            isShowReplyCard = false
          }) {
            Image(systemName: "xmark")
          }
        }
      }
      .alert(isPresented: $viewModel.isPostCompleted) {
        Alert(title: Text("リプライを送信しました"), message: nil)
      }
      .alert(isPresented: $viewModel.isPostFailed) {
        Alert(title: Text("送信エラー"), message: Text(viewModel.errorMessage))
      }
      .onChange(of: viewModel.selectedPhotoItems) { newItems in
        if let latestItem = newItems.last {
          viewModel.loadImage(from: latestItem)
        }
      }
      .onReceive(Publishers.keyboardHeight) { height in
        withAnimation(.easeInOut(duration: 0.25)) {
          keyboardHeight = height
        }
      }
    }
  }

  // リプライ先の情報を取得するためのcomputed properties
  private var replyTargetAvatarUrl: URL? {
    if let notification = notification {
      return URL(string: notification.author.avatar ?? "")
    } else if let post = post {
      return post.author?.avatarUrl
    }
    return nil
  }

  private var replyTargetDisplayName: String {
    if let notification = notification {
      return notification.author.displayName ?? notification.author.handle ?? ""
    } else if let post = post {
      return post.author?.displayName ?? post.author?.handle ?? ""
    }
    return ""
  }

  private var replyTargetDid: String {
    if let notification = notification {
      return notification.author.did
    } else if let post = post {
      return post.author?.did ?? ""
    }
    return ""
  }

  private var replyTargetText: String {
    if let notification = notification, let record = notification.record, let text = record.text {
      return text
    } else if let post = post, let text = post.record?.text {
      return text
    }
    return ""
  }
}

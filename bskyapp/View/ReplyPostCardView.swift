//
//  ReplyPostCardView.swift
//  bskyapp
//
//  Created by shuya on 2025/09/17.
//

import SwiftUI
import PhotosUI

struct ReplyPostCardView: View {
    let notification: NotificationItem?
    let post: Post?
    @Binding var isShowReplyCard: Bool
    @StateObject private var viewModel: ReplyPostCardViewModel
    
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
            VStack(spacing: 16) {
                // リプライ先の投稿を表示
                VStack(alignment: .leading, spacing: 8) {
                    Text("リプライ先:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        ProfileImageView(
                            viewModel: AsyncImageViewModel(
                                url: replyTargetAvatarUrl,
                                imageSize: .timeline,
                                alt: replyTargetDisplayName
                            )
                        )
                        .frame(width: 30, height: 30)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(replyTargetDisplayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text(replyTargetText)
                                .font(.body)
                                .lineLimit(3)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // リプライ入力エリア
                VStack(spacing: 10) {
                    HStack {
                        TextEditor(text: $viewModel.text)
                            .frame(height: 120)
                            .border(viewModel.isTextValid ? Color.green : Color.red)
                            .onChange(of: viewModel.text) {
                                viewModel.checkTextCount()
                            }
                        VStack {
                            Text(viewModel.textCountString).frame(width: 50)
                        }
                    }
                    
                    // 画像選択と表示エリア（簡略版）
                    VStack(alignment: .leading) {
                        if !viewModel.selectedImages.isEmpty {
                            Text("選択された画像: \(viewModel.selectedImages.count)枚")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
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
                                    
                                    if viewModel.canAddMoreImages() {
                                        PhotosPicker(selection: $viewModel.selectedPhotoItems, maxSelectionCount: 1, matching: .images) {
                                            VStack {
                                                Image(systemName: "plus")
                                                    .font(.system(size: 20))
                                                Text("追加")
                                                    .font(.caption2)
                                            }
                                            .frame(width: 80, height: 80)
                                            .background(Color.gray.opacity(0.2))
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                        }
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                        } else {
                            PhotosPicker(selection: $viewModel.selectedPhotoItems, maxSelectionCount: 1, matching: .images) {
                                HStack {
                                    Image(systemName: "photo")
                                    Text("画像を追加")
                                }
                                .padding(8)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    
                    // アップロード進捗表示
                    if viewModel.isUploading {
                        VStack(spacing: 4) {
                            ProgressView(value: viewModel.uploadProgress)
                                .progressViewStyle(LinearProgressViewStyle())
                                .frame(height: 8)
                            
                            HStack {
                                Image(systemName: "arrow.up.to.line")
                                    .foregroundColor(.blue)
                                Text("画像をアップロード中... \(Int(viewModel.uploadProgress * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                Spacer()
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("リプライ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        isShowReplyCard = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("送信") {
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
                    }
                    .disabled(!viewModel.isTextValid || viewModel.isUploading)
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
            return notification.author.displayName ?? notification.author.handle
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

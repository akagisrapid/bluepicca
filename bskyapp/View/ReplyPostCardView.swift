//
//  ReplyPostCardView.swift
//  bskyapp
//
//  Created by shuya on 2025/09/17.
//

import SwiftUI
import PhotosUI

struct ReplyPostCardView: View {
    let notification: NotificationItem
    @Binding var isShowReplyCard: Bool
    @StateObject private var viewModel: ReplyPostCardViewModel
    
    init(notification: NotificationItem, isShowReplyCard: Binding<Bool>) {
        self.notification = notification
        self._isShowReplyCard = isShowReplyCard
        self._viewModel = StateObject(wrappedValue: ReplyPostCardViewModel(notification: notification))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // リプライ先の投稿を表示
                VStack(alignment: .leading, spacing: 8) {
                    Text("リプライ先:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        ProfileImageView(
                            viewModel: AsyncImageViewModel(
                                url: URL(string: notification.author.avatar ?? ""),
                                imageSize: .timeline,
                                alt: notification.author.displayName ?? notification.author.handle
                            ),
                            actor: notification.author.did
                        )
                        .frame(width: 30, height: 30)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(notification.author.displayName ?? notification.author.handle)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            if let record = notification.record, let text = record.text {
                                Text(text)
                                    .font(.body)
                                    .lineLimit(3)
                            }
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
}

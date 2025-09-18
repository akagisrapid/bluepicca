//
//  ReplyItemView.swift
//  bskyapp
//
//  Created by shuya on 2025/09/17.
//

import SwiftUI

struct ReplyItemView: View {
    let threadViewPost: ThreadViewPost
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                // プロフィール画像
                ProfileImageView(
                    viewModel: AsyncImageViewModel(
                        url: threadViewPost.post.author?.avatarUrl,
                        imageSize: .timeline,
                        alt: threadViewPost.post.author?.displayName ?? threadViewPost.post.author?.handle ?? ""
                    ),
                    actor: threadViewPost.post.author?.did ?? ""
                )
                .frame(width: 32, height: 32)
                
                VStack(alignment: .leading, spacing: 4) {
                    // ユーザー情報
                    HStack {
                        Text(threadViewPost.post.author?.displayName ?? threadViewPost.post.author?.handle ?? "")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("@\(threadViewPost.post.author?.handle ?? "")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if let indexedAt = threadViewPost.post.indexedAt,
                           let date = indexedAt.parseToDateRemovingMilliseconds {
                            Text(date.formatted(.dateTime.hour().minute()))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // リプライ内容
                    if let text = threadViewPost.post.record?.text {
                        Text(text)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    // 画像がある場合
                    if let images = threadViewPost.post.embed?.images, !images.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(images, id: \.thumb) { image in
                                    AsyncImageView(
                                        viewModel: AsyncImageViewModel(
                                            url: image.thumbUrl,
                                            imageSize: .thumbnail,
                                            alt: image.alt,
                                            fullSizeUrl: image.fullsizeUrl
                                        )
                                    )
                                    .frame(width: 100, height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    
                    // アクションボタン
                    HStack(spacing: 16) {
                        // いいねボタン
                        HStack(spacing: 4) {
                            Image(systemName: threadViewPost.post.viewer?.like != nil ? "star.fill" : "star")
                                .foregroundColor(threadViewPost.post.viewer?.like != nil ? .yellow : .gray)
                                .font(.caption)
                            Text("\(threadViewPost.post.likeCount ?? 0)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        // リポストボタン
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.rectanglepath")
                                .foregroundColor(threadViewPost.post.viewer?.repost != nil ? .red : .gray)
                                .font(.caption)
                            Text("\(threadViewPost.post.repostCount ?? 0)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                    }
                    .padding(.top, 4)
                }
            }
            
            // ネストしたリプライがある場合
            if let nestedReplies = threadViewPost.replies, !nestedReplies.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(nestedReplies.prefix(3)) { nestedReply in
                        HStack {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 2)
                                .padding(.leading, 20)
                            
                            ReplyItemView(threadViewPost: nestedReply)
                        }
                    }
                    
                    if nestedReplies.count > 3 {
                        HStack {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 2)
                                .padding(.leading, 20)
                            
                            Text("他 \(nestedReplies.count - 3) 件のリプライ")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 8)
                            
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .background(Color.clear)
    }
}

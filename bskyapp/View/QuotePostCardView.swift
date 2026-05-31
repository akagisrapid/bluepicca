import PhotosUI
import SwiftUI

struct QuotePostCardView: View {
  let post: Post
  @Binding var isShowQuoteCard: Bool
  @StateObject private var viewModel: QuotePostCardViewModel
  @FocusState private var isTextEditorFocused: Bool

  init(post: Post, isShowQuoteCard: Binding<Bool>) {
    self.post = post
    self._isShowQuoteCard = isShowQuoteCard
    self._viewModel = StateObject(wrappedValue: QuotePostCardViewModel(quotedPost: post))
  }

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        textEditorArea
        selectedImagesRow
        uploadProgressRow
        quotedPostPreview
          .padding(.horizontal)
          .padding(.vertical, 8)
        Spacer()
        bottomToolbar
      }
      .navigationTitle("引用ポスト")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button(action: { isShowQuoteCard = false }) {
            SwiftUI.Label("閉じる", systemImage: "xmark").labelStyle(.iconOnly)
          }
        }
      }
      .alert(isPresented: $viewModel.isPostCompleted) {
        Alert(title: Text("引用ポストを送信しました"), message: nil)
      }
      .alert(isPresented: $viewModel.isPostFailed) {
        Alert(title: Text("送信エラー"), message: Text(viewModel.errorMessage))
      }
      .onChange(of: viewModel.selectedPhotoItems) { _, newItems in
        if let latestItem = newItems.last {
          viewModel.loadImage(from: latestItem)
        }
      }
    }
  }

  // MARK: - Subviews

  @ViewBuilder
  private var textEditorArea: some View {
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
      .overlay(alignment: .topTrailing) {
        Text(viewModel.textCountString)
          .font(.caption)
          .foregroundColor(viewModel.isTextValid ? .secondary : .red)
          .padding(8)
      }
      .padding(.horizontal)
      .padding(.top, 8)
  }

  @ViewBuilder
  private var selectedImagesRow: some View {
    if !viewModel.selectedImages.isEmpty {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 10) {
          ForEach(Array(viewModel.selectedImages.enumerated()), id: \.element.id) { index, item in
            Image(uiImage: item.image)
              .resizable()
              .scaledToFill()
              .frame(width: 80, height: 80)
              .clipShape(RoundedRectangle(cornerRadius: 8))
              .overlay(alignment: .topTrailing) {
                Button(action: { viewModel.removeImage(at: index) }) {
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
  }

  @ViewBuilder
  private var uploadProgressRow: some View {
    if viewModel.isUploading {
      HStack {
        ProgressView().scaleEffect(0.8)
        Text("アップロード中... \(Int(viewModel.uploadProgress * 100))%")
          .font(.caption)
          .foregroundColor(.blue)
        Spacer()
      }
      .padding(.horizontal)
      .padding(.vertical, 4)
    }
  }

  @ViewBuilder
  private var quotedPostPreview: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 6) {
        AsyncImage(url: post.author?.avatarUrl) { image in
          image.resizable()
        } placeholder: {
          Circle().fill(Color(.systemGray5))
        }
        .frame(width: 16, height: 16)
        .clipShape(Circle())

        Text(post.author?.displayName ?? post.author?.handle ?? "")
          .font(.caption)
          .fontWeight(.semibold)
          .foregroundColor(.primary)
          .lineLimit(1)

        Text("@\(post.author?.handle ?? "")")
          .font(.caption2)
          .foregroundColor(.secondary)
          .lineLimit(1)
      }

      if let text = post.record?.text, !text.isEmpty {
        Text(text)
          .font(.caption)
          .foregroundColor(.primary)
          .lineLimit(4)
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(.systemGray6))
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(Color(.systemGray4), lineWidth: 0.5)
    )
  }

  @ViewBuilder
  private var bottomToolbar: some View {
    HStack {
      PhotosPicker(
        selection: $viewModel.selectedPhotoItems, maxSelectionCount: 1, matching: .images
      ) {
        SwiftUI.Label("画像を追加", systemImage: "photo.badge.plus")
          .labelStyle(.iconOnly)
          .font(.title2)
          .foregroundColor(viewModel.canAddMoreImages() ? .blue : .gray)
      }
      .disabled(!viewModel.canAddMoreImages())

      Spacer()

      Button(action: {
        Task {
          do {
            try await viewModel.postQuote()
            await MainActor.run {
              isShowQuoteCard = false
            }
          } catch {
            dlog("引用ポスト送信エラー: \(error)")
          }
        }
      }) {
        SwiftUI.Label("送信", systemImage: "paperplane.fill")
          .labelStyle(.iconOnly)
          .font(.title2)
          .foregroundColor(viewModel.isTextValid && !viewModel.isUploading ? .blue : .gray)
      }
      .disabled(!viewModel.isTextValid || viewModel.isUploading)
    }
    .padding(.horizontal)
    .padding(.vertical, 12)
    .padding(.bottom, 8)
  }
}

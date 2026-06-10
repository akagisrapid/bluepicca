import PhotosUI
import SwiftUI

struct PostCardView: View {
  @StateObject var viewModel: PostCardViewModel
  @Binding var isShowPostCard: Bool
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @FocusState private var isTextEditorFocused: Bool
  @State private var isShowDrafts = false
  @State private var isDraftSaved = false
  @State private var showReplyAudiencePicker = false

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        textEditorArea
        selectedImagesRow
        uploadProgressRow
        Spacer()
        bottomToolbar
      }
      .navigationTitle("新しいポスト")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button(action: { saveDraft() }) {
            SwiftUI.Label("下書きに保存", systemImage: "doc.badge.plus").labelStyle(.iconOnly)
          }
          .disabled(viewModel.text.isEmpty)
        }
        ToolbarItem(placement: .navigationBarTrailing) {
          Button(action: { isShowPostCard.toggle() }) {
            SwiftUI.Label("閉じる", systemImage: "xmark").labelStyle(.iconOnly)
          }
        }
      }
      .sheet(isPresented: $isShowDrafts) {
        DraftsView { draft in
          viewModel.text = draft.text
          viewModel.checkTextCount()
        }
      }
      .sheet(isPresented: $showReplyAudiencePicker) {
        ReplyRulePickerSheet(
          selectedRules: $viewModel.selectedThreadgateRules,
          replyDisabled: $viewModel.replyDisabled,
          quotingDisabled: $viewModel.quotingDisabled
        )
      }
      .alert("下書きを保存しました", isPresented: $isDraftSaved) {
        Button("OK") {}
      }
      .alert(isPresented: $viewModel.isPostCompleted) {
        Alert(title: Text("送信完了"), message: nil)
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
            imageCell(item: item, at: index)
          }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
      }
    }
  }

  @ViewBuilder
  private func imageCell(item: IdentifiableImage, at index: Int) -> some View {
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

  @ViewBuilder
  private var uploadProgressRow: some View {
    if viewModel.isUploading {
      let percent = Int(viewModel.uploadProgress * 100)
      HStack {
        ProgressView().scaleEffect(0.8)
        Text("アップロード中... \(percent)%")
          .font(.caption)
          .foregroundColor(.blue)
        Spacer()
      }
      .padding(.horizontal)
      .padding(.vertical, 4)
    }
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

      Button(action: { isShowDrafts = true }) {
        SwiftUI.Label("下書き一覧", systemImage: "tray.and.arrow.down")
          .labelStyle(.iconOnly)
          .font(.title2)
          .foregroundColor(.blue)
      }
      .padding(.leading, 16)

      replyRuleButton

      Spacer()

      postButton
    }
    .padding(.horizontal)
    .padding(.vertical, 12)
    .padding(.bottom, 8)
  }

  @ViewBuilder
  private var replyRuleButton: some View {
    let isRestricted =
      viewModel.replyDisabled || !viewModel.selectedThreadgateRules.isEmpty
      || viewModel.quotingDisabled
    Button(action: { showReplyAudiencePicker = true }) {
      HStack(spacing: 4) {
        Image(systemName: isRestricted ? "lock.fill" : "globe")
          .font(.subheadline)
        Text(isRestricted ? "制限中" : "全員")
          .font(.caption)
      }
      .foregroundColor(isRestricted ? .blue : .secondary)
    }
    .padding(.leading, 12)
  }

  @ViewBuilder
  private var postButton: some View {
    let canPost = viewModel.isTextValid && !viewModel.isUploading
    Button(action: {
      Task {
        do {
          try await viewModel.postText()
          await MainActor.run {
            viewModel.isPostCompleted = true
            viewModel.text = ""
            viewModel.selectedImages = []
            viewModel.selectedPhotoItems = []
            withAnimation { isShowPostCard.toggle() }
          }
        } catch {
          await MainActor.run { viewModel.isPostFailed = true }
        }
      }
    }) {
      SwiftUI.Label("投稿", systemImage: "paperplane.fill")
        .labelStyle(.iconOnly)
        .font(.title2)
        .foregroundColor(canPost ? .blue : .gray)
    }
    .disabled(!canPost)
  }

  private func saveDraft() {
    guard !viewModel.text.isEmpty else { return }
    let draft = PostDraft(text: viewModel.text)
    modelContext.insert(draft)
    isDraftSaved = true
  }
}

// MARK: - リプライ・引用制限選択シート

private struct ReplyRulePickerSheet: View {
  @Binding var selectedRules: Set<ThreadgateRule>
  @Binding var replyDisabled: Bool
  @Binding var quotingDisabled: Bool
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      List {
        // MARK: リプライ制限
        Section {
          Button(action: { replyDisabled.toggle() }) {
            HStack {
              Image(systemName: "nosign")
                .frame(width: 24)
                .foregroundColor(replyDisabled ? .red : .primary)
              Text("返信不可")
                .foregroundColor(.primary)
              Spacer()
              if replyDisabled {
                Image(systemName: "checkmark")
                  .foregroundColor(.red)
              }
            }
          }
          ForEach(ThreadgateRule.allCases, id: \.self) { rule in
            Button(action: {
              guard !replyDisabled else { return }
              toggle(rule)
            }) {
              HStack {
                Image(systemName: rule.icon)
                  .frame(width: 24)
                  .foregroundColor(replyDisabled ? .secondary : .primary)
                Text(rule.label)
                  .foregroundColor(replyDisabled ? .secondary : .primary)
                Spacer()
                if selectedRules.contains(rule) {
                  Image(systemName: "checkmark")
                    .foregroundColor(replyDisabled ? .secondary : .blue)
                }
              }
            }
            .disabled(replyDisabled)
          }
        } header: {
          Text("リプライ")
        } footer: {
          Group {
            if replyDisabled {
              Text("返信不可がオンの場合、誰もリプライできません")
            } else if selectedRules.isEmpty {
              Text("チェックなし：全員がリプライできます")
            } else {
              Text("チェックした条件のいずれかに当てはまるユーザーがリプライできます")
            }
          }
        }

        // MARK: 引用制限
        Section {
          Button(action: { quotingDisabled.toggle() }) {
            HStack {
              Image(systemName: "quote.opening")
                .frame(width: 24)
                .foregroundColor(.primary)
              Text("引用を禁止する")
                .foregroundColor(.primary)
              Spacer()
              if quotingDisabled {
                Image(systemName: "checkmark")
                  .foregroundColor(.blue)
              }
            }
          }
        } header: {
          Text("引用")
        } footer: {
          Text(quotingDisabled ? "他のユーザーはこの投稿を引用できません" : "全員がこの投稿を引用できます")
        }
      }
      .navigationTitle("投稿の制限設定")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("完了") { dismiss() }
        }
      }
    }
  }

  private func toggle(_ rule: ThreadgateRule) {
    if selectedRules.contains(rule) {
      selectedRules.remove(rule)
    } else {
      selectedRules.insert(rule)
    }
  }
}

import SwiftUI
import PhotosUI
import Combine

struct PostCardView: View {
    @StateObject var viewModel: PostCardViewModel
    @Binding var isShowPostCard: Bool
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isTextEditorFocused: Bool
    @State private var keyboardHeight: CGFloat = 0
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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

                // 下部ツールバー: 画像追加（左）と投稿ボタン（右）
                HStack {
                    PhotosPicker(selection: $viewModel.selectedPhotoItems, maxSelectionCount: 1, matching: .images) {
                        Image(systemName: "photo.badge.plus")
                            .font(.title2)
                            .foregroundColor(viewModel.canAddMoreImages() ? .blue : .gray)
                    }
                    .disabled(!viewModel.canAddMoreImages())

                    Spacer()

                    Button(action: {
                        Task {
                            do {
                                try await viewModel.postText()
                                await MainActor.run {
                                    viewModel.isPostCompleted = true
                                    viewModel.text = ""
                                    viewModel.selectedImages = []
                                    viewModel.selectedPhotoItems = []
                                    withAnimation {
                                        isShowPostCard.toggle()
                                    }
                                }
                            } catch {
                                await MainActor.run {
                                    viewModel.isPostFailed = true
                                }
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
            .navigationTitle("新しいポスト")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        isShowPostCard.toggle()
                    }) {
                        Image(systemName: "xmark")
                    }
                }
            }
            .alert(isPresented: $viewModel.isPostCompleted) {
                Alert(title: Text("送信完了"), message: nil)
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
}

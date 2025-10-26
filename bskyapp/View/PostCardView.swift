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
        ZStack {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 10) {
                        GeometryReader { geometry in
                            let availableHeight = geometry.size.height
                            let textEditorHeight = max(200, availableHeight * 0.85)
                            
                            ZStack(alignment: .bottomTrailing) {
                                TextEditor(text: $viewModel.text)
                                    .frame(
                                        width: geometry.size.width * 0.95,
                                        height: textEditorHeight
                                    )
                                    .border(viewModel.isTextValid ? Color.green : Color.red)
                                    .focused($isTextEditorFocused)
                                    .onChange(of: viewModel.text) {
                                        viewModel.checkTextCount()
                                    }
                                
                                Text(viewModel.textCountString)
                                    .font(.caption)
                                    .foregroundColor(viewModel.isTextValid ? .secondary : .red)
                                    .padding(8)
                                    .background(Color(UIColor.systemBackground).opacity(0.8))
                                    .cornerRadius(4)
                                    .offset(x: -10, y: -10)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        }
                        .frame(height: max(300, UIScreen.main.bounds.height * 0.6 - keyboardHeight - 100))
                        
                        // 画像選択と表示エリア
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
                                                    .frame(width: 100, height: 100)
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
                                                        .font(.system(size: 30))
                                                    Text("追加")
                                                        .font(.caption)
                                                }
                                                .frame(width: 100, height: 100)
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
                    .padding()
                }
                .navigationTitle("新しいポスト")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            Task {
                                do {
                                    try await viewModel.postText()
                                    // Update UI on the main thread
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
                                    // Update UI on the main thread
                                    await MainActor.run {
                                        viewModel.isPostFailed = true
                                    }
                                }
                            }
                        }) {
                            Image(systemName: "paperplane.fill")
                                .font(.title2)
                        }
                        .disabled(!viewModel.isTextValid || viewModel.isUploading)
                    }
                }
                .alert(isPresented: $viewModel.isPostCompleted) {
                    Alert(title: Text("送信完了"), message: nil)
                }
                .alert(isPresented: $viewModel.isPostFailed) {
                    Alert(title: Text("送信エラー"), message: Text(viewModel.errorMessage))
                }
                .onChange(of: viewModel.selectedPhotoItems) { newItems in
                    print("selectedPhotoItemsが変更されました: \(newItems.count)個")
                    
                    // 最新の選択アイテムのみを処理
                    if let latestItem = newItems.last {
                        print("最新のPhotoPickerItemを処理: \(latestItem.itemIdentifier ?? "unknown")")
                        viewModel.loadImage(from: latestItem)
                    }
                }
                .onReceive(Publishers.keyboardHeight) { height in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        keyboardHeight = height
                    }
                }
                .onChange(of: isTextEditorFocused) { focused in
                    if focused {
                        // TextEditorがフォーカスされた時の処理
                        withAnimation(.easeInOut(duration: 0.3)) {
                            // 必要に応じて追加の調整
                        }
                    }
                }
                
                // 右下の戻るボタン
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            isShowPostCard.toggle()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundColor(.white)
                                .background(Color.black.opacity(0.7))
                                .clipShape(Circle())
                                .shadow(radius: 3)
                        }
                        .padding(.trailing, 16)
                        .padding(.bottom, 16)
                    }
                }
            }
        }
    }
}

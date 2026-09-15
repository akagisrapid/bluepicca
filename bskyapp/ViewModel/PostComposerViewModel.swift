import Foundation
import PhotosUI
import SwiftUI

struct IdentifiableImage: Identifiable {
  let id = UUID()
  let image: UIImage
}

/// 新規・返信・引用の投稿コンポーザーが共有する状態とロジックの基底クラス。
///
/// テキスト・画像選択・アップロード進捗などの共通状態と、文字数チェック／画像の追加・削除／
/// 画像アップロードといった共通処理をまとめる。各コンポーザーは本クラスを継承し、
/// 固有の投稿処理（postText / postReply / postQuote）や初期化のみを実装する。
class PostComposerViewModel: ObservableObject {
  @Published var text: String = ""
  @Published var isPostCompleted: Bool = false
  @Published var isPostFailed: Bool = false
  @Published var isTextValid: Bool = false
  @Published var errorMessage: String = ""
  @Published var selectedImages: [IdentifiableImage] = []
  @Published var selectedPhotoItems: [PhotosPickerItem] = []
  @Published var isUploading: Bool = false
  @Published var uploadProgress: Double = 0.0

  let maxTextCount: Int = 300
  let maxImageCount: Int = 4

  var textCountString: String {
    "\(text.count) / \(maxTextCount)"
  }

  func canAddMoreImages() -> Bool {
    selectedImages.count < maxImageCount
  }

  /// テキストと画像の有無から投稿可能かを判定し `isTextValid` を更新する。
  /// デフォルトは「テキストか画像のいずれかがあり、かつ上限文字数以内」。
  /// 空テキストを許容する場合（引用など）はサブクラスで上書きする。
  func checkTextCount() {
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      let hasImages = !self.selectedImages.isEmpty
      self.isTextValid = (hasImages || 0 < self.text.count) && self.text.count <= self.maxTextCount
    }
  }

  func removeImage(at index: Int) {
    guard index < selectedImages.count else { return }
    selectedImages.remove(at: index)
    if index < selectedPhotoItems.count {
      selectedPhotoItems.remove(at: index)
    }
    checkTextCount()
  }

  func loadImage(from item: PhotosPickerItem) {
    Task { [weak self] in
      guard let self else { return }
      do {
        let data = try await item.loadTransferable(type: Data.self)
        guard let imageData = data, let image = UIImage(data: imageData) else { return }
        await MainActor.run {
          if self.appendImageIfPossible(image) {
            self.checkTextCount()
          }
        }
      } catch {
        dlog("画像の読み込みエラー: \(error.localizedDescription)")
      }
    }
  }

  /// 上限内であれば画像を追加して `true` を返す。上限超過時は `errorMessage` を設定し `false`。
  /// MainActor 上から呼び出すこと。
  @MainActor
  func appendImageIfPossible(_ image: UIImage) -> Bool {
    guard selectedImages.count < maxImageCount else {
      errorMessage = String(localized: "最大\(maxImageCount)枚まで選択できます")
      return false
    }
    selectedImages.append(IdentifiableImage(image: image))
    objectWillChange.send()
    return true
  }

  /// 選択済み画像があればアップロードし、結果（空なら nil）を返す共通処理。
  func uploadSelectedImagesIfNeeded() async throws -> [UploadedImage]? {
    guard !selectedImages.isEmpty else { return nil }
    await MainActor.run {
      isUploading = true
      uploadProgress = 0.0
    }
    let imagesToUpload = selectedImages.map { ImageToUpload(image: $0.image, alt: "画像の説明") }
    let uploaded = try await PostCreationService.shared.uploadImages(imagesToUpload) {
      [weak self] progress in
      Task { @MainActor in self?.uploadProgress = progress }
    }
    await MainActor.run {
      isUploading = false
      uploadProgress = 1.0
    }
    return uploaded.isEmpty ? nil : uploaded
  }
}

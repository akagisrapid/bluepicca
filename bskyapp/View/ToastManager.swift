import SwiftUI
import UIKit

@MainActor
class ToastManager: ObservableObject {
  static let shared = ToastManager()

  struct ToastMessage: Identifiable {
    let id = UUID()
    let icon: String
    let text: String
  }

  @Published var message: ToastMessage?
  private var hideTask: Task<Void, Never>?

  func show(icon: String, text: String, durationMilliseconds: Int = 800) {
    hideTask?.cancel()
    withAnimation(.easeOut(duration: 0.2)) {
      message = ToastMessage(icon: icon, text: text)
    }
    hideTask = Task {
      try? await Task.sleep(for: .milliseconds(durationMilliseconds))
      guard !Task.isCancelled else { return }
      withAnimation(.easeIn(duration: 0.25)) {
        message = nil
      }
    }
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
  }
}

struct ToastOverlay: View {
  @ObservedObject var toastManager: ToastManager

  var body: some View {
    if let toast = toastManager.message {
      HStack(spacing: 8) {
        Image(systemName: toast.icon)
          .font(.subheadline)
        Text(toast.text)
          .font(.subheadline.weight(.medium))
      }
      .padding(.horizontal, 18)
      .padding(.vertical, 10)
      .background(.regularMaterial)
      .clipShape(Capsule())
      .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
      .padding(.bottom, 72)
      .transition(.move(edge: .bottom).combined(with: .opacity))
    }
  }
}

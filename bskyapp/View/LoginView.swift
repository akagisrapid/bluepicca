import Combine
import SwiftUI

struct LoginView: View {
  @StateObject private var viewModel = LoginViewModel()
  @Binding var isLoggedIn: Bool
  @State private var isPasswordVisible: Bool = false

  var body: some View {
    NavigationStack {
      VStack(spacing: 20) {
        // Logo or App Title
        Text("Bluepicca")
          .font(.largeTitle)
          .fontWeight(.bold)
          .padding(.top, 50)

        // Description
        Text("アプリパスワードでログイン")
          .font(.headline)
          .foregroundColor(.secondary)

        // Form
        VStack(alignment: .leading, spacing: 8) {
          Text("ユーザー名")
            .font(.subheadline)
            .foregroundColor(.secondary)

          TextField("例: username.bsky.social", text: $viewModel.identifier)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .autocapitalization(.none)
            .disableAutocorrection(true)
            .keyboardType(.emailAddress)

          Text("アプリパスワード")
            .font(.subheadline)
            .foregroundColor(.secondary)
            .padding(.top, 10)

          HStack {
            if isPasswordVisible {
              // パスワードを表示モードで表示
              TextField("アプリパスワードを入力", text: $viewModel.password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .disableAutocorrection(true)
            } else {
              // パスワードを非表示モードで表示
              SecureField("アプリパスワードを入力", text: $viewModel.password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .disableAutocorrection(true)
            }

            // 表示/非表示切り替えボタン
            Button(action: {
              isPasswordVisible.toggle()
            }) {
              SwiftUI.Label(
                isPasswordVisible ? "パスワードを隠す" : "パスワードを表示",
                systemImage: isPasswordVisible ? "eye.slash.fill" : "eye.fill"
              )
              .labelStyle(.iconOnly)
              .foregroundColor(.gray)
            }
            .padding(.trailing, 8)
          }
        }
        .padding(.horizontal, 30)
        .padding(.top, 20)

        // Error Message
        if !viewModel.errorMessage.isEmpty {
          Text(viewModel.errorMessage)
            .foregroundColor(.red)
            .font(.subheadline)
            .padding(.horizontal, 30)
            .padding(.top, 10)
        }

        // Login Button
        Button(action: {
          Task {
            await viewModel.login()
            isLoggedIn = viewModel.isLoggedIn
          }
        }) {
          if viewModel.isLoggingIn {
            ProgressView()
              .progressViewStyle(CircularProgressViewStyle())
              .tint(.white)
              .frame(maxWidth: .infinity)
              .padding()
              .background(Color.blue)
              .cornerRadius(10)
          } else {
            Text("ログイン")
              .fontWeight(.semibold)
              .foregroundColor(.white)
              .frame(maxWidth: .infinity)
              .padding()
              .background(Color.blue)
              .cornerRadius(10)
          }
        }
        .disabled(viewModel.isLoggingIn)
        .padding(.horizontal, 30)
        .padding(.top, 20)

        // App Password Info
        VStack(alignment: .leading, spacing: 8) {
          Text("アプリパスワードとは？")
            .font(.headline)
            .padding(.top, 30)

          Text("アプリパスワードはBlueskyの設定画面で作成できます。")
            .font(.subheadline)
            .foregroundColor(.secondary)

          Text("1. Blueskyアプリの設定画面を開く")
            .font(.caption)
            .foregroundColor(.secondary)

          Text("2. App Passwords を選択")
            .font(.caption)
            .foregroundColor(.secondary)

          Text("3. Add App Password ボタンを押す")
            .font(.caption)
            .foregroundColor(.secondary)

          Text("4. 名前を入力して Create App Password を押す")
            .font(.caption)
            .foregroundColor(.secondary)

          Text("5. 表示されたパスワードをコピーして保存する")
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.bottom, 5)

          Text("※ パスワードは一度しか表示されないので注意してください")
            .font(.caption)
            .foregroundColor(.red)
        }
        .padding(.horizontal, 30)

        Spacer()
      }
      .navigationTitle("ログイン")
      .navigationBarTitleDisplayMode(.inline)
    }
  }
}

#Preview {
  LoginView(isLoggedIn: .constant(false))
}

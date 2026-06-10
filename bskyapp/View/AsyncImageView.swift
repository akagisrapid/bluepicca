import SwiftUI

struct AsyncImageView: View {
  let viewModel: AsyncImageViewModel
  @State var isFullsizeView = false

  var body: some View {
    AsyncImage(url: viewModel.url) { image in
      image.image?
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(maxWidth: viewModel.imageSize.maxWidth, maxHeight: viewModel.imageSize.maxHeight)
    }
    .gesture(
      TapGesture().onEnded {
        isFullsizeView = true
      }
    )
    .sheet(isPresented: $isFullsizeView) {
      VStack {
        AsyncImage(url: viewModel.fullSizeUrl ?? viewModel.url) { image in
          image.image?
            .resizable()
            .aspectRatio(contentMode: .fit)
            .edgesIgnoringSafeArea(.horizontal)  // 全画面表示するためにsafe areaを無視する
        }
        if !viewModel.alt.isEmpty {
          Text("alt: \(viewModel.alt)")
        }
      }
      .overlay(alignment: .topTrailing) {
        Button(action: {
          isFullsizeView.toggle()
        }) {
          Image(systemName: "xmark.circle.fill")
            .font(.largeTitle)
            .foregroundColor(.white)
            .background(Color.black.opacity(0.7))
            .clipShape(Circle())
            .shadow(radius: 5)
        }
        .padding(.trailing, 20)
        .padding(.top, 20)
        .scaleEffect(1.2)
      }
    }
  }
}

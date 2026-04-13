import SwiftUI

struct AsyncImageView: View {
  let viewModel: AsyncImageViewModel
  @State var isFullsizeView = false

  var body: some View {
    ZStack {
      // サムネ色
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
        //                .gesture(DragGesture().onEnded { gesture in
        //                    if gesture.translation.height > 100 {
        //                        isFullsizeView.toggle()
        //                    }
        //                })

        HStack {
          Spacer()
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
          .padding(.bottom, 20)
          .scaleEffect(1.2)
        }
        .padding()
      }
    }
  }
}

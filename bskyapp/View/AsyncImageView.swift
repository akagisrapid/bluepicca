import SwiftUI

struct AsyncImageView: View {
    @StateObject var viewModel: AsyncImageViewModel
    @State var isFullsizeView = false
    var body: some View {
        ZStack{
            // サムネ色
            AsyncImage(url: viewModel.url){ image in
                image.image?.resizable().frame(maxWidth: viewModel.imageSize.maxWidth, maxHeight: viewModel.imageSize.maxHeight)
            }
            .gesture(
                TapGesture().onEnded{
                    isFullsizeView = true
                }
            )
            .fullScreenCover(isPresented: $isFullsizeView){
                VStack{
                    AsyncImage(url: viewModel.fullSizeUrl ?? viewModel.url) { image in
                        image.image?
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .background(Color.black.opacity(0.4))
                            .edgesIgnoringSafeArea(.all) // 全画面表示するためにsafe areaを無視する
                            .onTapGesture {
                                // 画像をタップしたら拡大表示を終了する
                                isFullsizeView.toggle()
                            }
                    }
                    if !viewModel.alt.isEmpty{
                        Text("alt: \(viewModel.alt)")
                    }
                }
            }
        }
        
    }
}

import SwiftUI

struct AsyncImageView: View {
    @StateObject var viewModel: AsyncImageViewModel
    @StateObject var profileViewModel: ProfileViewModel = ProfileViewModel()
    @State var isFullsizeView = false
    @State var isProfileView = false
    var body: some View {
        ZStack{
            // サムネ色
            AsyncImage(url: viewModel.url){ image in
                image.image?
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: viewModel.imageSize.maxWidth, maxHeight: viewModel.imageSize.maxHeight)
            }
            .gesture(
                TapGesture().onEnded{
                    switch viewModel.tapToOpen {
                    case .profile:
                        isProfileView = true
                    case .fullSize:
                        isFullsizeView = true
                    case .none:
                        isProfileView = false
                        isFullsizeView = false
                    }
                }
            )
            .sheet(isPresented: $isFullsizeView){
                VStack{
                    AsyncImage(url: viewModel.fullSizeUrl ?? viewModel.url) { image in
                        image.image?
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .edgesIgnoringSafeArea(.horizontal) // 全画面表示するためにsafe areaを無視する
                    }
                    if !viewModel.alt.isEmpty{
                        Text("alt: \(viewModel.alt)")
                    }
                }
//                .gesture(DragGesture().onEnded { gesture in
//                    if gesture.translation.height > 100 {
//                        isFullsizeView.toggle()
//                    }
//                })
                
                HStack{
                    Button("Save", systemImage: "square.and.arrow.down.fill"){
                        // 画像を保存する処理
                    }
                    Spacer()
                    Button("Close", systemImage: "xmark.circle.fill"){
                        isFullsizeView.toggle()
                    }
                }.padding()
            }
        }
        .sheet(isPresented: $isProfileView){
            ProfileView(viewModel: profileViewModel)
        }
        
    }
}

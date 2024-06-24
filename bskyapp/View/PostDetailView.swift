import SwiftUI

struct PostDetailView: View {
    @StateObject var viewModel: PostDetailViewModel
    var body: some View {
        VStack{
            HStack{
                AsyncImage(url: viewModel.avatarUrl){ avatar in
                    avatar.image?.resizable().frame(width: 50, height: 50)
                }
                Text(viewModel.displayName).font(.headline)
                Spacer()
            }
            Text(viewModel.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            VStack{
                ForEach(viewModel.embeddedImages, id: \.thumb){
                    embed in
                    AsyncImage(url: embed.thumbUrl){ image in
                        image.image?.resizable().frame(maxWidth:300, maxHeight: 300)
                    }
                }
            }
            
            Text(viewModel.indexedAt)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding()
        }
    }
}

import SwiftUI

struct ProfileView: View {
    @StateObject var viewModel = ProfileViewModel(actor: "", profile: .init(did: "", handle: "", labels: []))
    @StateObject var asyncImageViewModel: AsyncImageViewModel = .init(url: nil, imageSize: .avatar, alt: "")
    
    
    var body: some View {
        if viewModel.isFetching {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .padding()
        } else {
            VStack(alignment: .leading){
                HStack{
                    AsyncImageView(viewModel: asyncImageViewModel)
                    VStack(alignment: .leading){
                        Text(viewModel.profile.handle)
                            .font(.headline).padding()
                        
                        Text("\(viewModel.profile.postsCount ?? 0) posts").padding()
                    
                    }
                }
                HStack{
                    Image(systemName: "person.fill")
                    Text("Name")
                        .padding()
                    Text(viewModel.profile.displayName ?? "none")
                }
                HStack{
                    Image(systemName: "person.2.fill")
                    Text("Followers")
                        .padding()
                    Text("\(viewModel.profile.followersCount ?? 0)")
                }
                HStack{
                    Image(systemName: "person.2.fill")
                    Text("Follows")
                        .padding()
                    Text("\(viewModel.profile.followsCount ?? 0)")
                }
                HStack{
                    Image(systemName: "ellipsis.message.fill")
                    Text("Description").padding()
                }
                Text(viewModel.profile.description ?? "none")
                
            }.padding()
        }
    }
}

#Preview {
    ProfileView()
}

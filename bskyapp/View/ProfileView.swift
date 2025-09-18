import SwiftUI

struct ProfileView: View {
    @StateObject var viewModel: ProfileViewModel
    @StateObject var asyncImageViewModel: AsyncImageViewModel
    @State private var showingFollowsList = false
    @State private var showingFollowersList = false
    
    init(viewModel: ProfileViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
        self._asyncImageViewModel = StateObject(wrappedValue: AsyncImageViewModel(url: nil, imageSize: .avatar, alt: ""))
    }
    
    init() {
        self._viewModel = StateObject(wrappedValue: ProfileViewModel(actor: "", profile: .init(did: "", handle: "", labels: [])))
        self._asyncImageViewModel = StateObject(wrappedValue: AsyncImageViewModel(url: nil, imageSize: .avatar, alt: ""))
    }
    
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
                
                Button(action: {
                    Task {
                        await viewModel.toggleFollow()
                    }
                }) {
                    Text(viewModel.isFollowing ? "フォロー解除" : "フォロー")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(viewModel.isFollowing ? Color.red : Color.blue)
                        .cornerRadius(10)
                }
                .disabled(viewModel.isProcessingFollow)
                .padding(.vertical, 5)

                HStack{
                    Image(systemName: "person.fill")
                    Text("Name")
                        .padding()
                    Text(viewModel.profile.displayName ?? "none")
                }
                Button(action: {
                    showingFollowersList = true
                }) {
                    HStack{
                        Image(systemName: "person.2.fill")
                        Text("Followers")
                            .padding()
                        Text("\(viewModel.profile.followersCount ?? 0)")
                        Spacer()
                    }
                    .foregroundColor(.primary)
                }
                .sheet(isPresented: $showingFollowersList) {
                    FollowListView(actor: viewModel.profile.handle, listType: .followers)
                }
                
                Button(action: {
                    showingFollowsList = true
                }) {
                    HStack{
                        Image(systemName: "person.2.fill")
                        Text("Follows")
                            .padding()
                        Text("\(viewModel.profile.followsCount ?? 0)")
                        Spacer()
                    }
                    .foregroundColor(.primary)
                }
                .sheet(isPresented: $showingFollowsList) {
                    FollowListView(actor: viewModel.profile.handle, listType: .follows)
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

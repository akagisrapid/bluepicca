import SwiftUI

struct FollowListView: View {
    @StateObject var viewModel: FollowListViewModel
    let title: String
    
    init(actor: String, listType: FollowListType) {
        self._viewModel = StateObject(wrappedValue: FollowListViewModel(actor: actor, listType: listType))
        self.title = listType == .follows ? "フォロー中" : "フォロワー"
    }
    
    var body: some View {
        NavigationView {
            List {
                if viewModel.listType == .follows {
                    ForEach(viewModel.followItems, id: \.did) { item in
                        NavigationLink(destination: ProfileView(viewModel: ProfileViewModel(actor: item.handle, profile: .init(did: "", handle: "", labels: [])))) {
                            FollowItemRow(
                                handle: item.handle,
                                displayName: item.displayName,
                                avatar: item.avatar
                            )
                        }
                        .onAppear {
                            if item.did == viewModel.followItems.last?.did {
                                Task {
                                    await viewModel.loadMore()
                                }
                            }
                        }
                    }
                } else {
                    ForEach(viewModel.followerItems, id: \.did) { item in
                        NavigationLink(destination: ProfileView(viewModel: ProfileViewModel(actor: item.handle, profile: .init(did: "", handle: "", labels: [])))) {
                            FollowItemRow(
                                handle: item.handle,
                                displayName: item.displayName,
                                avatar: item.avatar
                            )
                        }
                        .onAppear {
                            if item.did == viewModel.followerItems.last?.did {
                                Task {
                                    await viewModel.loadMore()
                                }
                            }
                        }
                    }
                }
                
                if viewModel.isFetching {
                    HStack {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                        Spacer()
                    }
                    .padding()
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct FollowItemRow: View {
    let handle: String
    let displayName: String?
    let avatar: String?
    
    @StateObject private var asyncImageViewModel: AsyncImageViewModel
    
    init(handle: String, displayName: String?, avatar: String?) {
        self.handle = handle
        self.displayName = displayName
        self.avatar = avatar
        self._asyncImageViewModel = StateObject(wrappedValue: AsyncImageViewModel(url: avatar.flatMap(URL.init(string:)), imageSize: .avatar, alt: ""))
    }
    
    var body: some View {
        HStack {
            AsyncImageView(viewModel: asyncImageViewModel)
                .frame(width: 50, height: 50)
            
            VStack(alignment: .leading, spacing: 4) {
                if let displayName = displayName, !displayName.isEmpty {
                    Text(displayName)
                        .font(.headline)
                        .lineLimit(1)
                }
                Text("@\(handle)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    FollowListView(actor: "test.bsky.social", listType: .follows)
}

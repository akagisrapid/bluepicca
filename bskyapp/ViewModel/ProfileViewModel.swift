import Foundation
class ProfileViewModel: ObservableObject {
    @Published var actor: String
    @Published var profile: GetProfileApiResponse = .init(did: "", handle: "", labels: [])
    @Published var isFetching: Bool = false
    init(actor: String, profile: GetProfileApiResponse) {
        self.actor = actor
        self.profile = profile
        Task {
            await fetchProfile()
        }
    }
    @MainActor
    func fetchProfile() async{
        do{
            self.isFetching = true
            self.profile = try await GetProfileApi().getProfile(param: .init(actor: actor))
            self.isFetching = false
        }
        catch{
            print(error)
        }
    }
}

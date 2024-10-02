import SwiftUI

struct ProfileView: View {
    @StateObject var viewModel = ProfileViewModel()
    var body: some View {
        Text("profile")
    }
}

#Preview {
    ProfileView()
}

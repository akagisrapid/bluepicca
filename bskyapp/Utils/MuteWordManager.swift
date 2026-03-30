import Foundation

class MuteWordManager: ObservableObject {
    static let shared = MuteWordManager()
    private let key = "muteWords"

    @Published var muteWords: [String]

    private init() {
        muteWords = UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    func add(_ word: String) {
        let trimmed = word.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !muteWords.contains(trimmed) else { return }
        muteWords.append(trimmed)
        save()
    }

    func remove(at offsets: IndexSet) {
        muteWords.remove(atOffsets: offsets)
        save()
    }

    func matches(_ text: String) -> Bool {
        muteWords.contains { text.localizedCaseInsensitiveContains($0) }
    }

    private func save() {
        UserDefaults.standard.set(muteWords, forKey: key)
    }
}

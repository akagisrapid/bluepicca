import Foundation

class RTFilterManager: ObservableObject {
  static let shared = RTFilterManager()
  private let key = "rtFilteredDIDs"

  @Published var filteredDIDs: Set<String>

  private init() {
    let array = UserDefaults.standard.stringArray(forKey: key) ?? []
    filteredDIDs = Set(array)
  }

  func add(did: String, displayName: String, handle: String, avatarUrl: URL?) {
    filteredDIDs.insert(did)
    save()
    var entries = loadEntries()
    if !entries.contains(where: { $0.did == did }) {
      entries.append(
        RTFilterEntry(
          did: did, displayName: displayName, handle: handle,
          avatarUrlString: avatarUrl?.absoluteString))
      saveEntries(entries)
    }
  }

  func remove(did: String) {
    filteredDIDs.remove(did)
    save()
    var entries = loadEntries()
    entries.removeAll { $0.did == did }
    saveEntries(entries)
  }

  func isFiltered(_ did: String) -> Bool {
    filteredDIDs.contains(did)
  }

  func entries() -> [RTFilterEntry] {
    loadEntries()
  }

  private func save() {
    UserDefaults.standard.set(Array(filteredDIDs), forKey: key)
  }

  private func loadEntries() -> [RTFilterEntry] {
    guard let data = UserDefaults.standard.data(forKey: key + "Entries"),
      let entries = try? JSONDecoder().decode([RTFilterEntry].self, from: data)
    else { return [] }
    return entries
  }

  private func saveEntries(_ entries: [RTFilterEntry]) {
    if let data = try? JSONEncoder().encode(entries) {
      UserDefaults.standard.set(data, forKey: key + "Entries")
    }
  }
}

struct RTFilterEntry: Codable, Identifiable {
  let did: String
  let displayName: String
  let handle: String
  let avatarUrlString: String?

  var id: String { did }
  var avatarUrl: URL? { avatarUrlString.flatMap { URL(string: $0) } }
}

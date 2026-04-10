import Foundation

final class JournalStore: ObservableObject {
    @Published private(set) var entries: [JournalEntry] = [] {
        didSet { save() }
    }
    @Published private(set) var customTypeNames: [String] = [] {
        didSet { saveCustomTypes() }
    }

    var entriesSortedByDateDescending: [JournalEntry] {
        entries.sorted { $0.date > $1.date }
    }

    var availableTypes: [EntryType] {
        let configuredCustom = customTypeNames.map(EntryType.custom)
        let customFromEntries = entries.compactMap(\.type.customTypeName).map(EntryType.custom)
        return EntryType.merged(EntryType.presetTypes + configuredCustom, extra: customFromEntries)
    }

    private let saveKey = "scene_journal_entries"
    private let customTypesKey = "scene_journal_custom_types"

    init() {
        load()
    }

    func add(_ entry: JournalEntry) {
        entries.append(entry)
    }

    func update(_ entry: JournalEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[index] = entry
    }

    func delete(id: UUID) {
        entries.removeAll { $0.id == id }
    }

    @discardableResult
    func addCustomType(named rawName: String) -> EntryType? {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let normalized = trimmed.lowercased()
        if normalized == "general" { return .general }
        if normalized == "concert" { return .concert }
        if normalized == "broadway" { return .broadway }

        if let existing = customTypeNames.first(where: { $0.lowercased() == normalized }) {
            return .custom(existing)
        }

        customTypeNames.append(trimmed)
        return .custom(trimmed)
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: saveKey)
    }

    private func saveCustomTypes() {
        UserDefaults.standard.set(customTypeNames, forKey: customTypesKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: saveKey),
              let decoded = try? JSONDecoder().decode([JournalEntry].self, from: data) else {
            entries = SampleData.entries
            loadCustomTypes()
            syncCustomTypesFromEntries()
            return
        }
        entries = decoded
        loadCustomTypes()
        syncCustomTypesFromEntries()
    }

    private func loadCustomTypes() {
        customTypeNames = UserDefaults.standard.stringArray(forKey: customTypesKey) ?? []
    }

    private func syncCustomTypesFromEntries() {
        for name in entries.compactMap(\.type.customTypeName) {
            if customTypeNames.contains(where: { $0.lowercased() == name.lowercased() }) {
                continue
            }
            customTypeNames.append(name)
        }
    }
}

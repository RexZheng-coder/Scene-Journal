import SwiftUI

struct JournalEntry: Identifiable, Codable {
    let id: UUID
    var type: EntryType
    var title: String
    var venue: String
    var people: String
    var detailA: String
    var detailB: String
    var notes: String
    var date: Date
    var photos: [EntryPhoto]
    var tags: [String]
    var customFields: [EntryField]

    init(
        id: UUID = UUID(),
        type: EntryType,
        title: String,
        venue: String,
        people: String,
        detailA: String,
        detailB: String,
        notes: String,
        date: Date,
        photos: [EntryPhoto],
        tags: [String] = [],
        customFields: [EntryField] = []
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.venue = venue
        self.people = people
        self.detailA = detailA
        self.detailB = detailB
        self.notes = notes
        self.date = date
        self.photos = photos
        self.tags = tags
        self.customFields = customFields
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case type
        case title
        case venue
        case people
        case detailA
        case detailB
        case notes
        case date
        case photos
        case tags
        case customFields
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(EntryType.self, forKey: .type)
        title = try container.decode(String.self, forKey: .title)
        venue = try container.decode(String.self, forKey: .venue)
        people = try container.decode(String.self, forKey: .people)
        detailA = try container.decodeIfPresent(String.self, forKey: .detailA) ?? ""
        detailB = try container.decodeIfPresent(String.self, forKey: .detailB) ?? ""
        notes = try container.decode(String.self, forKey: .notes)
        date = try container.decode(Date.self, forKey: .date)
        photos = try container.decode([EntryPhoto].self, forKey: .photos)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        customFields = try container.decodeIfPresent([EntryField].self, forKey: .customFields) ?? []
    }
}

struct EntryPhoto: Identifiable, Codable {
    let id: UUID
    let data: Data?
    let remoteURL: String?

    init(id: UUID = UUID(), data: Data) {
        self.id = id
        self.data = data
        self.remoteURL = nil
    }

    init(id: UUID = UUID(), remoteURL: String) {
        self.id = id
        self.data = nil
        self.remoteURL = remoteURL
    }
}

struct EntryField: Identifiable, Codable {
    let id: UUID
    var key: String
    var value: String

    init(id: UUID = UUID(), key: String, value: String) {
        self.id = id
        self.key = key
        self.value = value
    }
}

struct EntryType: Codable, Identifiable, Hashable {
    private enum Kind: String {
        case general
        case concert
        case broadway
        case custom
    }

    private let kind: Kind
    private let customName: String

    private init(kind: Kind, customName: String = "") {
        self.kind = kind
        self.customName = customName
    }

    static let general = EntryType(kind: .general)
    static let concert = EntryType(kind: .concert)
    static let broadway = EntryType(kind: .broadway)

    static var presetTypes: [EntryType] {
        [.general, .concert, .broadway]
    }

    static func custom(_ rawName: String) -> EntryType {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        return EntryType(kind: .custom, customName: trimmed.isEmpty ? "Custom" : trimmed)
    }

    static func merged(_ base: [EntryType], extra: [EntryType] = []) -> [EntryType] {
        var seen = Set<String>()
        var ordered: [EntryType] = []

        for type in base + extra {
            if seen.insert(type.id).inserted {
                ordered.append(type)
            }
        }
        return ordered
    }

    static func fromUserInput(_ raw: String) -> EntryType {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()

        switch lower {
        case "general": return .general
        case "concert": return .concert
        case "broadway": return .broadway
        default: return .custom(trimmed)
        }
    }

    var id: String {
        switch kind {
        case .general, .concert, .broadway:
            return kind.rawValue
        case .custom:
            return "custom:\(normalizedCustomName)"
        }
    }

    var displayName: String {
        switch kind {
        case .general: return "General"
        case .concert: return "Concert"
        case .broadway: return "Broadway"
        case .custom: return customName
        }
    }

    var isCustom: Bool {
        kind == .custom
    }

    var customTypeName: String? {
        isCustom ? customName : nil
    }

    private var normalizedCustomName: String {
        customName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var titleLabel: String {
        switch kind {
        case .general, .custom: return "Entry title"
        case .concert: return "Tour / event name"
        case .broadway: return "Show title"
        }
    }

    var peopleLabel: String {
        switch kind {
        case .general, .custom: return "People (optional)"
        case .concert: return "Artist / band"
        case .broadway: return "Cast"
        }
    }

    var detailALabel: String {
        switch kind {
        case .general, .custom: return "Highlight (optional)"
        case .concert: return "Favorite track"
        case .broadway: return "Favorite scene"
        }
    }

    var detailBLabel: String {
        switch kind {
        case .general, .custom: return "Mood (optional)"
        case .concert: return "Setlist note"
        case .broadway: return "Seat / section"
        }
    }

    var templateHint: String {
        switch kind {
        case .general:
            return "Use this as a flexible format for any memory type."
        case .concert:
            return "Concert template helps you remember songs and setlist moments."
        case .broadway:
            return "Broadway template helps you capture scene and seat details."
        case .custom:
            return "Custom category keeps a flexible format for your own scene type."
        }
    }

    var badgeColor: Color {
        switch kind {
        case .general: return .teal
        case .concert: return .pink
        case .broadway: return .blue
        case .custom:
            let palette: [Color] = [.orange, .green, .mint, .cyan, .indigo, .red, .brown]
            let index = abs(id.hashValue) % palette.count
            return palette[index]
        }
    }

    func templateFields(detailA: String, detailB: String) -> [EntryField] {
        var fields: [EntryField] = []

        if !detailA.isEmpty {
            fields.append(EntryField(key: detailALabel, value: detailA))
        }
        if !detailB.isEmpty {
            fields.append(EntryField(key: detailBLabel, value: detailB))
        }

        return fields
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = EntryType.decodeStorageValue(raw)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(storageValue)
    }

    private var storageValue: String {
        switch kind {
        case .general, .concert, .broadway:
            return kind.rawValue
        case .custom:
            return "custom:\(customName)"
        }
    }

    private static func decodeStorageValue(_ raw: String) -> EntryType {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()

        switch lower {
        case "general":
            return .general
        case "concert":
            return .concert
        case "broadway":
            return .broadway
        default:
            if lower.hasPrefix("custom:") {
                let name = String(trimmed.dropFirst("custom:".count))
                return .custom(name)
            }
            return .custom(trimmed)
        }
    }
}

enum EntryFilter: Hashable, Identifiable {
    case all
    case type(EntryType)

    var id: String {
        switch self {
        case .all: return "all"
        case let .type(type): return "type:\(type.id)"
        }
    }

    var title: String {
        switch self {
        case .all: return "All"
        case let .type(type): return type.displayName
        }
    }

    var tint: Color {
        switch self {
        case .all: return .indigo
        case let .type(type): return type.badgeColor
        }
    }
}

extension JournalEntry {
    var storySummary: String {
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedNotes.isEmpty {
            return String(trimmedNotes.prefix(110))
        }

        let parts = [detailA, detailB, people]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if !parts.isEmpty {
            return parts.joined(separator: " • ")
        }
        return "A memorable live moment."
    }
}

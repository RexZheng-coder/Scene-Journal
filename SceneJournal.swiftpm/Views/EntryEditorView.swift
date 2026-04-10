import SwiftUI
import PhotosUI

enum EditorMode {
    case create
    case edit(JournalEntry)

    var title: String {
        switch self {
        case .create: return "New Entry"
        case .edit: return "Edit Entry"
        }
    }
}

private struct EditableField: Identifiable {
    let id: UUID
    var key: String
    var value: String

    init(id: UUID = UUID(), key: String = "", value: String = "") {
        self.id = id
        self.key = key
        self.value = value
    }
}

struct EntryEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let mode: EditorMode
    let onSave: (JournalEntry) -> Void
    let availableTypes: [EntryType]
    let onAddCustomType: (String) -> EntryType?

    private let editingID: UUID?

    @State private var type: EntryType
    @State private var title: String
    @State private var venue: String
    @State private var people: String
    @State private var detailA: String
    @State private var detailB: String
    @State private var notes: String
    @State private var date: Date
    @State private var tagsText: String

    @State private var selectedItems: [PhotosPickerItem]
    @State private var selectedPhotoData: [Data]
    @State private var customFields: [EditableField]
    @State private var generatedHighlights: SmartHighlights?
    @State private var isGeneratingHighlights = false
    @State private var isShowingPlacePicker = false
    @State private var editableTypes: [EntryType]
    @State private var isShowingAddCategoryAlert = false
    @State private var newCategoryName = ""

    init(
        mode: EditorMode,
        onSave: @escaping (JournalEntry) -> Void,
        availableTypes: [EntryType] = EntryType.presetTypes,
        onAddCustomType: @escaping (String) -> EntryType? = { _ in nil }
    ) {
        self.mode = mode
        self.onSave = onSave
        self.availableTypes = EntryType.merged(EntryType.presetTypes, extra: availableTypes)
        self.onAddCustomType = onAddCustomType

        switch mode {
        case .create:
            editingID = nil
            _type = State(initialValue: .general)
            _title = State(initialValue: "")
            _venue = State(initialValue: "")
            _people = State(initialValue: "")
            _detailA = State(initialValue: "")
            _detailB = State(initialValue: "")
            _notes = State(initialValue: "")
            _date = State(initialValue: Date())
            _tagsText = State(initialValue: "")
            _selectedItems = State(initialValue: [])
            _selectedPhotoData = State(initialValue: [])
            _customFields = State(initialValue: [])
            _editableTypes = State(initialValue: EntryType.merged(EntryType.presetTypes, extra: availableTypes))

        case let .edit(entry):
            editingID = entry.id
            _type = State(initialValue: entry.type)
            _title = State(initialValue: entry.title)
            _venue = State(initialValue: entry.venue)
            _people = State(initialValue: entry.people)
            _detailA = State(initialValue: entry.detailA)
            _detailB = State(initialValue: entry.detailB)
            _notes = State(initialValue: entry.notes)
            _date = State(initialValue: entry.date)
            _tagsText = State(initialValue: entry.tags.joined(separator: ", "))
            _selectedItems = State(initialValue: [])
            _selectedPhotoData = State(initialValue: entry.photos.compactMap(\.data))
            _customFields = State(initialValue: entry.customFields.map { EditableField(id: $0.id, key: $0.key, value: $0.value) })
            _editableTypes = State(initialValue: EntryType.merged(EntryType.presetTypes, extra: availableTypes + [entry.type]))
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Type") {
                    Picker("Category", selection: $type) {
                        ForEach(editableTypes, id: \.id) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.menu)

                    Button {
                        isShowingAddCategoryAlert = true
                    } label: {
                        Label("Add Category", systemImage: "plus.circle")
                    }
                    .accessibilityHint("Create and use a custom category")
                }

                Section("Core") {
                    TextField(type.titleLabel, text: $title)
                        .accessibilityLabel(type.titleLabel)
                    TextField(type.peopleLabel, text: $people)
                        .accessibilityLabel(type.peopleLabel)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }

                Section("Place") {
                    VenuePinPreviewCard(
                        place: venue,
                        height: 180,
                        loadingText: "Locating this place...",
                        placeholderText: "Tap Find on Maps to choose a place.",
                        unresolvedText: "Unable to locate this place. Try a more specific address."
                    )

                    Button {
                        isShowingPlacePicker = true
                    } label: {
                        Label("Find on Maps", systemImage: "map.circle.fill")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .accessibilityHint("Search and select a place using Apple Maps")
                }

                Section("Smart Template") {
                    TextField(type.detailALabel, text: $detailA)
                    TextField(type.detailBLabel, text: $detailB)
                    Text(type.templateHint)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Custom Fields") {
                    if customFields.isEmpty {
                        Text("Add your own key/value details for any kind of memory.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    ForEach($customFields) { $field in
                        VStack(spacing: 8) {
                            TextField("Field name", text: $field.key)
                                .accessibilityLabel("Custom field name")
                            TextField("Field value", text: $field.value)
                                .accessibilityLabel("Custom field value")
                        }
                    }
                    .onDelete { indexSet in
                        customFields.remove(atOffsets: indexSet)
                    }

                    Button {
                        customFields.append(EditableField())
                    } label: {
                        Label("Add Field", systemImage: "plus")
                    }
                    .accessibilityHint("Add a new custom key and value field")
                }

                Section("Notes") {
                    TextField("Write quick thoughts, atmosphere, and highlights.", text: $notes, axis: .vertical)
                        .lineLimit(4...10)
                }

                Section("Smart Highlights") {
                    Button {
                        Task { await generateHighlights() }
                    } label: {
                        if isGeneratingHighlights {
                            ProgressView()
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Label("Generate Highlights", systemImage: "sparkles")
                        }
                    }
                    .disabled(isGeneratingHighlights || !canGenerateHighlights)
                    .accessibilityLabel("Generate Smart Highlights")
                    .accessibilityHint("Create an AI summary and three important keywords")

                    if let generatedHighlights {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(generatedHighlights.summary)
                                .font(.subheadline)
                            Text("Keywords: \(generatedHighlights.keywords.joined(separator: ", "))")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Text("Source: \(generatedHighlights.source.displayName)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Tags") {
                    TextField("Comma-separated tags", text: $tagsText)
                }

                Section("Photos") {
                    PhotosPicker(
                        selection: $selectedItems,
                        maxSelectionCount: 10,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Label("Add Photos", systemImage: "photo.on.rectangle")
                    }
                    .accessibilityHint("Choose up to ten photos from your library")

                    if !selectedPhotoData.isEmpty {
                        PhotoStripView(
                            photos: selectedPhotoData.map { EntryPhoto(data: $0) },
                            width: 88,
                            height: 88
                        )
                        .accessibilityLabel("Selected photos")
                        .accessibilityValue("\(selectedPhotoData.count) photos selected")
                    }
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .accessibilityHint("Close editor without saving")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave(makeEntry())
                        dismiss()
                    }
                    .disabled(!canSave)
                    .accessibilityHint(canSave ? "Save this entry" : "Enter a title to enable saving")
                }
            }
            .onChange(of: selectedItems) { newItems in
                Task {
                    selectedPhotoData = await loadImages(from: newItems)
                }
            }
            .sheet(isPresented: $isShowingPlacePicker) {
                PlacePickerSheet(initialQuery: venue) { selectedPlace in
                    venue = selectedPlace
                }
            }
            .alert("Add Category", isPresented: $isShowingAddCategoryAlert) {
                TextField("Category name", text: $newCategoryName)
                Button("Add") {
                    if let newType = onAddCustomType(newCategoryName) {
                        editableTypes = EntryType.merged(editableTypes, extra: [newType])
                        type = newType
                    }
                    newCategoryName = ""
                }
                Button("Cancel", role: .cancel) {
                    newCategoryName = ""
                }
            } message: {
                Text("Create a custom category for your entries.")
            }
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canGenerateHighlights: Bool {
        !highlightInput.combinedText.isEmpty
    }

    private func makeEntry() -> JournalEntry {
        let tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let fields = customFields
            .map { EntryField(id: $0.id, key: $0.key.trimmingCharacters(in: .whitespacesAndNewlines), value: $0.value.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { !$0.key.isEmpty && !$0.value.isEmpty }

        return JournalEntry(
            id: editingID ?? UUID(),
            type: type,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            venue: venue.trimmingCharacters(in: .whitespacesAndNewlines),
            people: people.trimmingCharacters(in: .whitespacesAndNewlines),
            detailA: detailA.trimmingCharacters(in: .whitespacesAndNewlines),
            detailB: detailB.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            date: date,
            photos: selectedPhotoData.map { EntryPhoto(data: $0) },
            tags: tags,
            customFields: fields
        )
    }

    private var highlightInput: SmartHighlightInput {
        SmartHighlightInput(
            type: type,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            venue: venue.trimmingCharacters(in: .whitespacesAndNewlines),
            people: people.trimmingCharacters(in: .whitespacesAndNewlines),
            detailA: detailA.trimmingCharacters(in: .whitespacesAndNewlines),
            detailB: detailB.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            existingTags: parsedTagList(from: tagsText)
        )
    }

    private func parsedTagList(from raw: String) -> [String] {
        raw.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func generateHighlights() async {
        isGeneratingHighlights = true
        defer { isGeneratingHighlights = false }

        let generated = await SmartHighlightsService.shared.generate(from: highlightInput)
        generatedHighlights = generated

        let merged = Set(parsedTagList(from: tagsText)).union(generated.keywords)
        tagsText = merged.sorted().joined(separator: ", ")

        if notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            notes = generated.summary
        }
    }

    private func loadImages(from items: [PhotosPickerItem]) async -> [Data] {
        var dataArray: [Data] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                dataArray.append(data)
            }
        }
        return dataArray
    }
}

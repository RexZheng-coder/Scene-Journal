import SwiftUI

struct ContentView: View {
    @StateObject private var store = JournalStore()
    @State private var isPresentingCreateSheet = false
    @State private var editingEntry: JournalEntry?
    @State private var activeFilter: EntryFilter = .all
    @State private var isShowingAddCategoryAlert = false
    @State private var newCategoryName = ""

    @State private var searchText = ""
    @State private var isPresentingAdvancedFilters = false
    @State private var onlyWithPhotos = false
    @State private var onlyWithTags = false
    @State private var onlyWithNotes = false
    @State private var useStartDate = false
    @State private var useEndDate = false
    @State private var startDate = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
    @State private var endDate = Date()

    private var visibleEntries: [JournalEntry] {
        store.entriesSortedByDateDescending.filter { entry in
            matchesType(entry)
                && matchesSearch(entry)
                && matchesAdvancedFilters(entry)
        }
    }

    private var groupedEntries: [EntryType: [JournalEntry]] {
        Dictionary(grouping: visibleEntries, by: { $0.type })
    }

    private var availableFilters: [EntryFilter] {
        [.all] + store.availableTypes.map(EntryFilter.type)
    }

    private var orderedSectionTypes: [EntryType] {
        let configured = store.availableTypes
        let extras = groupedEntries.keys
            .filter { type in !configured.contains(where: { $0.id == type.id }) }
            .sorted { $0.displayName < $1.displayName }
        return configured + extras
    }

    private var hasActiveAdvancedFilters: Bool {
        onlyWithPhotos || onlyWithTags || onlyWithNotes || useStartDate || useEndDate
    }

    private var hasActiveQuery: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || hasActiveAdvancedFilters
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color.cyan.opacity(0.15), Color.indigo.opacity(0.16), Color.teal.opacity(0.13)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                List {
                    HeaderPanel(total: store.entries.count)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)

                    FilterChips(
                        activeFilter: $activeFilter,
                        filters: availableFilters,
                        onAddCategory: {
                            isShowingAddCategoryAlert = true
                        }
                    )
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)

                    SearchFieldRow(searchText: $searchText)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)

                    if hasActiveQuery {
                        filterSummaryRow
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }

                    if visibleEntries.isEmpty {
                        EmptyStateView()
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    } else {
                        if activeFilter == .all {
                            ForEach(orderedSectionTypes, id: \.id) { type in
                                if let entries = groupedEntries[type], !entries.isEmpty {
                                    Section(type.displayName) {
                                        ForEach(entries) { entry in
                                            entryRow(for: entry)
                                        }
                                    }
                                }
                            }
                        } else {
                            Section(activeFilter.title) {
                                ForEach(visibleEntries) { entry in
                                    entryRow(for: entry)
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .animation(.snappy(duration: 0.25, extraBounce: 0), value: visibleEntries.map(\.id))
            }
            .navigationTitle("Scene Journal")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isPresentingAdvancedFilters = true
                    } label: {
                        Image(systemName: hasActiveAdvancedFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("Advanced Filters")
                    .accessibilityHint("Filter by photos, tags, notes, and date range")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        MapPinsView(
                            entries: visibleEntries,
                            onEditEntry: { entry in editingEntry = entry },
                            onDeleteEntry: { id in store.delete(id: id) }
                        )
                    } label: {
                        Image(systemName: "map.circle")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("Map Pins")
                    .accessibilityHint("View entries on a map")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresentingCreateSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("Add Entry")
                    .accessibilityHint("Create a new journal entry")
                }
            }
            .sheet(isPresented: $isPresentingCreateSheet) {
                EntryEditorView(
                    mode: .create,
                    onSave: { entry in
                        store.add(entry)
                    },
                    availableTypes: store.availableTypes,
                    onAddCustomType: { name in
                        store.addCustomType(named: name)
                    }
                )
            }
            .sheet(item: $editingEntry) { entry in
                EntryEditorView(
                    mode: .edit(entry),
                    onSave: { updated in
                        store.update(updated)
                    },
                    availableTypes: store.availableTypes,
                    onAddCustomType: { name in
                        store.addCustomType(named: name)
                    }
                )
            }
            .sheet(isPresented: $isPresentingAdvancedFilters) {
                AdvancedFilterSheet(
                    onlyWithPhotos: $onlyWithPhotos,
                    onlyWithTags: $onlyWithTags,
                    onlyWithNotes: $onlyWithNotes,
                    useStartDate: $useStartDate,
                    useEndDate: $useEndDate,
                    startDate: $startDate,
                    endDate: $endDate,
                    onReset: resetAdvancedFilters
                )
                .presentationDetents([.fraction(0.46), .large])
                .presentationDragIndicator(.visible)
            }
            .alert("Add Category", isPresented: $isShowingAddCategoryAlert) {
                TextField("Category name", text: $newCategoryName)
                Button("Add") {
                    if let newType = store.addCustomType(named: newCategoryName) {
                        activeFilter = .type(newType)
                    }
                    newCategoryName = ""
                }
                Button("Cancel", role: .cancel) {
                    newCategoryName = ""
                }
            } message: {
                Text("Create a custom category to use in filters and editor.")
            }
        }
    }

    private var filterSummaryRow: some View {
        HStack(spacing: 10) {
            Label("\(visibleEntries.count) results", systemImage: "magnifyingglass")
                .font(.subheadline.weight(.semibold))

            Spacer()

            Button("Clear") {
                withAnimation(.snappy(duration: 0.22, extraBounce: 0)) {
                    clearAllQueryFilters()
                }
            }
            .font(.subheadline)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private func entryRow(for entry: JournalEntry) -> some View {
        NavigationLink {
            EntryDetailView(
                entry: entry,
                onEdit: { editingEntry = entry },
                onDelete: { store.delete(id: entry.id) }
            )
        } label: {
            EntryRowView(entry: entry)
        }
        .accessibilityHint("Open entry details")
        .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
        .listRowBackground(Color.clear)
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                editingEntry = entry
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                store.delete(id: entry.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func matchesType(_ entry: JournalEntry) -> Bool {
        switch activeFilter {
        case .all:
            return true
        case let .type(type):
            return entry.type == type
        }
    }

    private func matchesSearch(_ entry: JournalEntry) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        return entry.matches(query: query)
    }

    private func matchesAdvancedFilters(_ entry: JournalEntry) -> Bool {
        if onlyWithPhotos && entry.photos.isEmpty {
            return false
        }
        if onlyWithTags && entry.tags.isEmpty {
            return false
        }
        if onlyWithNotes && entry.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }

        if useStartDate {
            let start = Calendar.current.startOfDay(for: startDate)
            let entryDay = Calendar.current.startOfDay(for: entry.date)
            if entryDay < start {
                return false
            }
        }

        if useEndDate {
            let end = Calendar.current.startOfDay(for: endDate)
            let entryDay = Calendar.current.startOfDay(for: entry.date)
            if entryDay > end {
                return false
            }
        }

        return true
    }

    private func clearAllQueryFilters() {
        searchText = ""
        resetAdvancedFilters()
    }

    private func resetAdvancedFilters() {
        onlyWithPhotos = false
        onlyWithTags = false
        onlyWithNotes = false
        useStartDate = false
        useEndDate = false
        startDate = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
        endDate = Date()
    }
}

private struct SearchFieldRow: View {
    @Binding var searchText: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            TextField("Search title, notes, tags, venue", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityLabel("Search entries")
                .accessibilityHint("Search by title, notes, tags, venue, and people")

            if !searchText.isEmpty {
                Button {
                    withAnimation(.snappy(duration: 0.2, extraBounce: 0)) {
                        searchText = ""
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear Search")
                .accessibilityHint("Clear current search text")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .contain)
    }
}

private struct AdvancedFilterSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var onlyWithPhotos: Bool
    @Binding var onlyWithTags: Bool
    @Binding var onlyWithNotes: Bool
    @Binding var useStartDate: Bool
    @Binding var useEndDate: Bool
    @Binding var startDate: Date
    @Binding var endDate: Date

    let onReset: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Content") {
                    Toggle("Only entries with photos", isOn: $onlyWithPhotos)
                    Toggle("Only entries with tags", isOn: $onlyWithTags)
                    Toggle("Only entries with notes", isOn: $onlyWithNotes)
                }

                Section("Date Range") {
                    Toggle("Use start date", isOn: $useStartDate)
                    if useStartDate {
                        DatePicker("Start", selection: $startDate, displayedComponents: .date)
                    }

                    Toggle("Use end date", isOn: $useEndDate)
                    if useEndDate {
                        DatePicker("End", selection: $endDate, displayedComponents: .date)
                    }
                }

                Section {
                    Button("Reset Filters", role: .destructive) {
                        onReset()
                    }
                }
            }
            .navigationTitle("Advanced Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private extension JournalEntry {
    func matches(query: String) -> Bool {
        let normalizedQuery = query.lowercased()
        let searchableChunks: [String] = [
            title,
            venue,
            people,
            detailA,
            detailB,
            notes,
            tags.joined(separator: " "),
            customFields.map { "\($0.key) \($0.value)" }.joined(separator: " ")
        ]

        return searchableChunks
            .joined(separator: " ")
            .lowercased()
            .contains(normalizedQuery)
    }
}

#Preview {
    ContentView()
}

import SwiftUI

struct EntryDetailView: View {
    let entry: JournalEntry
    let onEdit: () -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteAlert = false
    @State private var highlights: SmartHighlights?
    @State private var isGeneratingHighlights = false
    @State private var isExporting = false
    @State private var shareItems: [Any] = []
    @State private var isShowingShareSheet = false
    @State private var exportErrorMessage: String?

    private var renderedFields: [EntryField] {
        entry.type.templateFields(detailA: entry.detailA, detailB: entry.detailB) + entry.customFields
    }

    var body: some View {
        ScrollView {
            detailContent
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(backgroundGradient)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { topBarActions }
        .alert("Delete this entry?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete()
                dismiss()
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .sheet(isPresented: $isShowingShareSheet) {
            ActivityShareSheet(items: shareItems)
        }
        .alert("Export failed", isPresented: exportErrorPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportErrorMessage ?? "Unknown error.")
        }
        .task(id: entry.id) {
            await generateHighlights()
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color.blue.opacity(0.1), Color.mint.opacity(0.08)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var exportErrorPresented: Binding<Bool> {
        Binding(
            get: { exportErrorMessage != nil },
            set: { _ in exportErrorMessage = nil }
        )
    }

    @ToolbarContentBuilder
    private var topBarActions: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                Task { await exportEntry() }
            } label: {
                if isExporting {
                    ProgressView()
                } else {
                    Image(systemName: "square.and.arrow.up")
                }
            }
            .disabled(isExporting)
            .accessibilityLabel("Export Entry")
            .accessibilityHint("Create a single PDF containing photo and entry details")

            Button("Edit") { onEdit() }
            Button(role: .destructive) {
                showingDeleteAlert = true
            } label: {
                Image(systemName: "trash")
            }
            .accessibilityLabel("Delete Entry")
            .accessibilityHint("Permanently delete this entry")
        }
    }

    private var trimmedNotes: String {
        entry.notes.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedPlace: String {
        entry.venue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var detailContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            headerSection

            Text(entry.title)
                .font(.title2.weight(.bold))
                .accessibilityAddTraits(.isHeader)

            LabeledContent("Place", value: trimmedPlace.isEmpty ? "Not set" : trimmedPlace)

            if !entry.people.isEmpty {
                LabeledContent(entry.type.peopleLabel, value: entry.people)
            }

            placeSection
            detailsSection
            notesSection
            smartHighlightsSection
            tagsSection
            photosSection
        }
    }

    private var headerSection: some View {
        HStack {
            Text(entry.type.displayName)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(entry.type.badgeColor.opacity(0.2), in: Capsule())
            Spacer()
            Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var placeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Place")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            VenuePinPreviewCard(
                place: trimmedPlace,
                height: 190,
                loadingText: "Locating this place...",
                placeholderText: "No place added for this entry.",
                unresolvedText: "Unable to locate this place. Try a more specific address."
            )
        }
    }

    @ViewBuilder
    private var detailsSection: some View {
        if !renderedFields.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Details")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                ForEach(renderedFields) { field in
                    LabeledContent(field.key, value: field.value)
                }
            }
        }
    }

    @ViewBuilder
    private var notesSection: some View {
        if !trimmedNotes.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Notes")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Text(entry.notes)
                    .font(.body)
            }
        }
    }

    private var smartHighlightsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Smart Highlights")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button {
                    Task { await generateHighlights() }
                } label: {
                    if isGeneratingHighlights {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Refresh Smart Highlights")
                .accessibilityHint("Generate an updated summary and keywords")
            }

            if let highlights {
                Text(highlights.summary)
                    .font(.subheadline)
                if !highlights.keywords.isEmpty {
                    FlowTags(tags: highlights.keywords)
                }
                Text("Source: \(highlights.source.displayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if isGeneratingHighlights {
                ProgressView("Generating highlights...")
                    .font(.footnote)
            } else {
                Text("Tap refresh to generate an AI summary and keywords.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var tagsSection: some View {
        if !entry.tags.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Tags")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                FlowTags(tags: entry.tags)
            }
        }
    }

    @ViewBuilder
    private var photosSection: some View {
        if !entry.photos.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Photos")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                PhotoStripView(photos: entry.photos, width: 220, height: 150)
            }
        }
    }

    private func generateHighlights() async {
        isGeneratingHighlights = true
        defer { isGeneratingHighlights = false }

        highlights = await SmartHighlightsService.shared.generate(
            from: SmartHighlightInput(
                type: entry.type,
                title: entry.title,
                venue: entry.venue,
                people: entry.people,
                detailA: entry.detailA,
                detailB: entry.detailB,
                notes: entry.notes,
                existingTags: entry.tags
            )
        )
    }

    @MainActor
    private func exportEntry() async {
        isExporting = true
        defer { isExporting = false }

        do {
            let exportedPDF = try EntryExportService.export(entry: entry)
            shareItems = [exportedPDF]
            isShowingShareSheet = true
        } catch {
            exportErrorMessage = "Unable to export this entry. Please try again."
        }
    }
}

private struct FlowTags: View {
    let tags: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                        .accessibilityLabel("Tag \(tag)")
                }
            }
        }
    }
}
